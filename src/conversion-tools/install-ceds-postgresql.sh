#!/bin/bash

# CEDS Data Warehouse PostgreSQL Installation Script
# This script automates the installation and setup of PostgreSQL for CEDS Data Warehouse

set -e  # Exit on any error

# Configuration variables
POSTGRES_VERSION="14"
DB_NAME="ceds_data_warehouse_v11_0_0_0"
ADMIN_USER="ceds_admin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        warn "This script should not be run as root. Please run as a regular user with sudo privileges."
        exit 1
    fi
}

# Detect operating system
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        error "Cannot detect operating system"
    fi
    
    log "Detected OS: $OS $VERSION"
}

# Install PostgreSQL on Ubuntu/Debian
install_postgresql_ubuntu() {
    log "Installing PostgreSQL on Ubuntu/Debian..."
    
    # Install prerequisites
    sudo apt update
    sudo apt install -y wget ca-certificates
    
    # Add PostgreSQL official repository
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list
    
    # Update and install PostgreSQL
    sudo apt update
    sudo apt install -y postgresql-${POSTGRES_VERSION} postgresql-client-${POSTGRES_VERSION} postgresql-contrib-${POSTGRES_VERSION}
    
    # Install additional extensions
    sudo apt install -y postgresql-${POSTGRES_VERSION}-pgstattuple
    
    # Start and enable service
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    
    log "PostgreSQL installation completed"
}

# Install PostgreSQL on CentOS/RHEL
install_postgresql_centos() {
    log "Installing PostgreSQL on CentOS/RHEL..."
    
    # Install PostgreSQL repository
    sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    
    # Install PostgreSQL
    sudo dnf install -y postgresql${POSTGRES_VERSION}-server postgresql${POSTGRES_VERSION}-contrib
    
    # Initialize database
    sudo /usr/pgsql-${POSTGRES_VERSION}/bin/postgresql-${POSTGRES_VERSION}-setup initdb
    
    # Enable and start service
    sudo systemctl enable postgresql-${POSTGRES_VERSION}
    sudo systemctl start postgresql-${POSTGRES_VERSION}
    
    log "PostgreSQL installation completed"
}

# Configure PostgreSQL
configure_postgresql() {
    log "Configuring PostgreSQL..."
    
    # Get PostgreSQL configuration directory
    local config_dir
    if [[ "$OS" == "ubuntu" ]] || [[ "$OS" == "debian" ]]; then
        config_dir="/etc/postgresql/${POSTGRES_VERSION}/main"
    else
        config_dir="/var/lib/pgsql/${POSTGRES_VERSION}/data"
    fi
    
    # Backup original configuration
    sudo cp "${config_dir}/postgresql.conf" "${config_dir}/postgresql.conf.backup"
    sudo cp "${config_dir}/pg_hba.conf" "${config_dir}/pg_hba.conf.backup"
    
    # Apply basic configuration optimizations
    sudo tee -a "${config_dir}/postgresql.conf" > /dev/null << EOF

# CEDS Data Warehouse Optimizations
listen_addresses = 'localhost'
max_connections = 200
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 32MB
maintenance_work_mem = 256MB
wal_buffers = 16MB
checkpoint_completion_target = 0.8
random_page_cost = 1.1
effective_io_concurrency = 200
log_min_duration_statement = 5000
log_checkpoints = on
autovacuum = on
track_activities = on
track_counts = on
track_functions = all
EOF
    
    # Configure authentication for local connections
    sudo sed -i "s/#local   all             all                                     peer/local   all             all                                     md5/" "${config_dir}/pg_hba.conf"
    sudo sed -i "s/local   all             all                                     peer/local   all             all                                     md5/" "${config_dir}/pg_hba.conf"
    
    # Restart PostgreSQL to apply changes
    sudo systemctl restart postgresql
    
    log "PostgreSQL configuration completed"
}

# Set up initial database security
setup_database_security() {
    log "Setting up database security..."
    
    # Prompt for postgres password
    echo -n "Enter password for postgres superuser: "
    read -s postgres_password
    echo
    
    echo -n "Enter password for $ADMIN_USER: "
    read -s admin_password
    echo
    
    # Set postgres password and create admin user
    sudo -u postgres psql << EOF
ALTER USER postgres PASSWORD '$postgres_password';
CREATE USER $ADMIN_USER WITH CREATEDB CREATEROLE LOGIN PASSWORD '$admin_password';
\q
EOF
    
    log "Database security setup completed"
}

# Create CEDS database
create_ceds_database() {
    log "Creating CEDS database..."
    
    # Create database
    sudo -u postgres createdb -O $ADMIN_USER $DB_NAME
    
    # Set database encoding and collation
    sudo -u postgres psql -d $DB_NAME << EOF
ALTER DATABASE $DB_NAME SET timezone = 'UTC';
ALTER DATABASE $DB_NAME SET standard_conforming_strings = on;
ALTER DATABASE $DB_NAME SET default_transaction_isolation = 'read committed';
\q
EOF
    
    log "CEDS database created successfully"
}

# Apply CEDS-specific configurations
apply_ceds_configurations() {
    log "Applying CEDS-specific configurations..."
    
    # Check if configuration files exist
    local config_files=(
        "postgresql-database-configuration.sql"
        "postgresql-schemas-and-security.sql"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            log "Applying $file..."
            PGPASSWORD="$admin_password" psql -h localhost -U $ADMIN_USER -d $DB_NAME -f "$SCRIPT_DIR/$file"
        else
            warn "Configuration file $file not found, skipping..."
        fi
    done
}

# Install database structure
install_database_structure() {
    log "Installing database structure..."
    
    local ddl_file="$SCRIPT_DIR/../ddl/CEDS-Data-Warehouse-V11.0.0.0-PostgreSQL.sql"
    
    if [[ -f "$ddl_file" ]]; then
        log "Installing CEDS database structure..."
        PGPASSWORD="$admin_password" psql -h localhost -U $ADMIN_USER -d $DB_NAME -f "$ddl_file"
    else
        warn "DDL file not found at $ddl_file"
        warn "Please run the DDL script manually after installation"
    fi
}

# Load dimension data
load_dimension_data() {
    log "Loading dimension data..."
    
    local dimension_loader="$SCRIPT_DIR/postgresql-dimension-data-loader.sql"
    
    if [[ -f "$dimension_loader" ]]; then
        log "Loading dimension data..."
        PGPASSWORD="$admin_password" psql -h localhost -U $ADMIN_USER -d $DB_NAME -f "$dimension_loader"
    else
        warn "Dimension data loader not found at $dimension_loader"
        warn "Please load dimension data manually"
    fi
}

# Validate installation
validate_installation() {
    log "Validating installation..."
    
    local validation_script="$SCRIPT_DIR/validate-postgresql-config.sql"
    
    if [[ -f "$validation_script" ]]; then
        log "Running validation checks..."
        PGPASSWORD="$admin_password" psql -h localhost -U $ADMIN_USER -d $DB_NAME -f "$validation_script" > validation_report.txt
        log "Validation report saved to validation_report.txt"
    else
        warn "Validation script not found"
    fi
    
    # Basic connectivity test
    log "Testing database connectivity..."
    PGPASSWORD="$admin_password" psql -h localhost -U $ADMIN_USER -d $DB_NAME -c "SELECT 'CEDS PostgreSQL installation successful!' as status;"
}

# Create maintenance scripts
create_maintenance_scripts() {
    log "Creating maintenance scripts..."
    
    # Create backup script
    sudo tee /usr/local/bin/ceds-backup.sh > /dev/null << 'EOF'
#!/bin/bash
DB_NAME="ceds_data_warehouse_v11_0_0_0"
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"
pg_dump -U postgres -d "$DB_NAME" | gzip > "$BACKUP_DIR/ceds_backup_$DATE.sql.gz"
find "$BACKUP_DIR" -name "ceds_backup_*.sql.gz" -mtime +30 -delete
EOF
    
    sudo chmod +x /usr/local/bin/ceds-backup.sh
    sudo mkdir -p /var/backups/postgresql
    sudo chown postgres:postgres /var/backups/postgresql
    
    log "Backup script created at /usr/local/bin/ceds-backup.sh"
}

# Display completion message
display_completion() {
    log "=============================================="
    log "CEDS PostgreSQL Installation Complete!"
    log "=============================================="
    echo
    log "Database Details:"
    echo "  Database Name: $DB_NAME"
    echo "  Admin User: $ADMIN_USER"
    echo "  Connection: psql -h localhost -U $ADMIN_USER -d $DB_NAME"
    echo
    log "Next Steps:"
    echo "  1. Review validation_report.txt for any issues"
    echo "  2. Configure firewall if needed (port 5432)"
    echo "  3. Set up SSL/TLS for production use"
    echo "  4. Configure automated backups"
    echo "  5. Load your data using ETL processes"
    echo
    log "Useful Commands:"
    echo "  - Connect to database: psql -h localhost -U $ADMIN_USER -d $DB_NAME"
    echo "  - Check service status: sudo systemctl status postgresql"
    echo "  - View logs: sudo journalctl -u postgresql -f"
    echo "  - Run backup: sudo /usr/local/bin/ceds-backup.sh"
    echo
    log "Installation completed successfully!"
}

# Main installation function
main() {
    log "Starting CEDS PostgreSQL Installation..."
    log "========================================"
    
    check_root
    detect_os
    
    # Install PostgreSQL based on OS
    case "$OS" in
        ubuntu|debian)
            install_postgresql_ubuntu
            ;;
        centos|rhel|fedora)
            install_postgresql_centos
            ;;
        *)
            error "Unsupported operating system: $OS"
            ;;
    esac
    
    configure_postgresql
    setup_database_security
    create_ceds_database
    apply_ceds_configurations
    install_database_structure
    load_dimension_data
    create_maintenance_scripts
    validate_installation
    display_completion
}

# Help function
show_help() {
    echo "CEDS PostgreSQL Installation Script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --version  Set PostgreSQL version (default: 14)"
    echo "  -d, --dbname   Set database name (default: ceds_data_warehouse_v11_0_0_0)"
    echo "  -u, --user     Set admin username (default: ceds_admin)"
    echo
    echo "Example:"
    echo "  $0 --version 13 --dbname my_ceds_db --user my_admin"
    echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            POSTGRES_VERSION="$2"
            shift 2
            ;;
        -d|--dbname)
            DB_NAME="$2"
            shift 2
            ;;
        -u|--user)
            ADMIN_USER="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Run main installation
main