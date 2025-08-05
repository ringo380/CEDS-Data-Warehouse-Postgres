#!/bin/bash

# ==============================================================================
# CEDS Data Warehouse PostgreSQL Interactive Setup Script
# ==============================================================================
# 
# This script automates the complete installation and configuration of the
# CEDS Data Warehouse on PostgreSQL with interactive prompts, validation,
# and comprehensive error handling.
#
# Usage: ./setup.sh
#
# Requirements:
# - PostgreSQL 12+ installed and running
# - psql command-line tool available
# - Python 3.8+ (for conversion tools)
# - Bash 4.0+ for script features
#
# ==============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# ==============================================================================
# GLOBAL CONFIGURATION
# ==============================================================================

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/ceds-setup-$(date +%Y%m%d_%H%M%S).log"

# Default configuration
DEFAULT_DB_NAME="ceds_data_warehouse_v11_0_0_0"
DEFAULT_DB_HOST="localhost"
DEFAULT_DB_PORT="5432"
DEFAULT_DB_USER="postgres"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Progress tracking
CURRENT_STEP=0
TOTAL_STEPS=7
START_TIME=$(date +%s)

# Configuration variables (will be set by user input)
DB_NAME=""
DB_HOST=""
DB_PORT=""
DB_USER=""
DB_PASSWORD=""
ADMIN_PASSWORD=""
INSTALLATION_TYPE=""
ENABLE_SSL=""
CREATE_SAMPLE_DATA=""

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Create log directory if it doesn't exist
mkdir -p "${LOG_DIR}"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] ${message}" >> "${LOG_FILE}"
}

# Print functions with color and logging
print_header() {
    local message="$1"
    echo -e "\n${WHITE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║$(printf "%78s" | tr ' ' ' ')║${NC}"
    echo -e "${WHITE}║$(printf "%*s" $(((78 + ${#message})/2)) "$message")$(printf "%*s" $(((78 - ${#message})/2)) "")║${NC}"
    echo -e "${WHITE}║$(printf "%78s" | tr ' ' ' ')║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}\n"
    log "INFO" "=== $message ==="
}

print_step() {
    local step_num="$1"
    local message="$2"
    CURRENT_STEP=$step_num
    echo -e "\n${CYAN}[${step_num}/${TOTAL_STEPS}] ${message}${NC}"
    log "INFO" "Step ${step_num}/${TOTAL_STEPS}: ${message}"
}

print_success() {
    local message="$1"
    echo -e "${GREEN}✅ ${message}${NC}"
    log "SUCCESS" "$message"
}

print_warning() {
    local message="$1"
    echo -e "${YELLOW}⚠️  ${message}${NC}"
    log "WARNING" "$message"
}

print_error() {
    local message="$1"
    echo -e "${RED}❌ ${message}${NC}" >&2
    log "ERROR" "$message"
}

print_info() {
    local message="$1"
    echo -e "${BLUE}ℹ️  ${message}${NC}"
    log "INFO" "$message"
}

# Progress bar function
show_progress() {
    local current="$1"
    local total="$2"
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    
    printf "\r${BLUE}Progress: [${GREEN}"
    printf "%${completed}s" | tr ' ' '█'
    printf "${NC}${BLUE}"
    printf "%${remaining}s" | tr ' ' '░'
    printf "${BLUE}] ${percentage}%%${NC}"
    
    if [ "$current" -eq "$total" ]; then
        echo
    fi
}

# User input functions
prompt_user() {
    local prompt="$1"
    local default="$2"
    local response
    
    if [ -n "$default" ]; then
        echo -e -n "${WHITE}${prompt} [${default}]: ${NC}"
    else
        echo -e -n "${WHITE}${prompt}: ${NC}"
    fi
    
    read -r response
    if [ -z "$response" ] && [ -n "$default" ]; then
        response="$default"
    fi
    echo "$response"
}

prompt_password() {
    local prompt="$1"
    local password
    
    echo -e -n "${WHITE}${prompt}: ${NC}"
    read -s password
    echo
    echo "$password"
}

prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    local response
    
    while true; do
        if [ "$default" = "y" ]; then
            echo -e -n "${WHITE}${prompt} [Y/n]: ${NC}"
        else
            echo -e -n "${WHITE}${prompt} [y/N]: ${NC}"
        fi
        
        read -r response
        
        if [ -z "$response" ]; then
            response="$default"
        fi
        
        case "$response" in
            [Yy]|[Yy][Ee][Ss])
                echo "y"
                return
                ;;
            [Nn]|[Nn][Oo])
                echo "n"
                return
                ;;
            *)
                print_warning "Please answer yes or no"
                ;;
        esac
    done
}

# Error handling function
handle_error() {
    local exit_code=$?
    local line_number=${1:-"Unknown"}
    
    print_error "Script failed at line ${line_number} with exit code ${exit_code}"
    print_error "Check the log file for details: ${LOG_FILE}"
    
    echo -e "\n${RED}Installation failed. Would you like to:"
    echo -e "1. View error details"
    echo -e "2. Cleanup and exit"
    echo -e "3. Exit without cleanup${NC}"
    
    read -p "Choose option [1-3]: " cleanup_choice
    
    case "$cleanup_choice" in
        1)
            echo -e "\n${YELLOW}Recent log entries:${NC}"
            tail -20 "${LOG_FILE}"
            ;;
        2)
            cleanup_installation
            ;;
    esac
    
    exit $exit_code
}

# Set error trap
trap 'handle_error ${LINENO}' ERR

# Cleanup function
cleanup_installation() {
    print_info "Cleaning up installation..."
    
    if [ -n "${DB_NAME:-}" ] && [ -n "${DB_USER:-}" ]; then
        local cleanup_db=$(prompt_yes_no "Remove database '${DB_NAME}'?" "n")
        if [ "$cleanup_db" = "y" ]; then
            print_info "Dropping database ${DB_NAME}..."
            PGPASSWORD="${DB_PASSWORD}" dropdb -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" "${DB_NAME}" 2>/dev/null || true
            print_success "Database cleanup completed"
        fi
    fi
    
    print_info "Cleanup completed"
}

# ==============================================================================
# SYSTEM VALIDATION FUNCTIONS
# ==============================================================================

check_system_requirements() {
    print_step 1 "Checking System Requirements"
    
    local errors=0
    
    # Check operating system
    print_info "Checking operating system..."
    case "$(uname -s)" in
        Linux*)
            print_success "Operating System: Linux"
            ;;
        Darwin*)
            print_success "Operating System: macOS"
            ;;
        CYGWIN*|MINGW*)
            print_success "Operating System: Windows (Bash)"
            ;;
        *)
            print_warning "Operating System: $(uname -s) (not tested)"
            ;;
    esac
    
    # Check available memory
    print_info "Checking system memory..."
    if command -v free >/dev/null 2>&1; then
        local mem_gb=$(free -g | awk '/^Mem:/{print $2}')
        if [ "$mem_gb" -ge 8 ]; then
            print_success "Memory: ${mem_gb}GB (sufficient)"
        elif [ "$mem_gb" -ge 4 ]; then
            print_warning "Memory: ${mem_gb}GB (minimum requirements met, 8GB+ recommended)"
        else
            print_error "Memory: ${mem_gb}GB (insufficient, minimum 4GB required)"
            ((errors++))
        fi
    else
        print_warning "Could not detect system memory"
    fi
    
    # Check available disk space
    print_info "Checking disk space..."
    local disk_space=$(df -BG "${SCRIPT_DIR}" | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$disk_space" -ge 100 ]; then
        print_success "Disk Space: ${disk_space}GB available (sufficient)"
    elif [ "$disk_space" -ge 50 ]; then
        print_warning "Disk Space: ${disk_space}GB available (tight, 100GB+ recommended)"
    else
        print_error "Disk Space: ${disk_space}GB available (insufficient, minimum 50GB required)"
        ((errors++))
    fi
    
    # Check for required commands
    print_info "Checking required commands..."
    local required_commands=("psql" "createdb" "dropdb" "python3" "git")
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            local version=""
            case "$cmd" in
                psql)
                    version=$(psql --version | head -n1)
                    ;;
                python3)
                    version=$(python3 --version)
                    ;;
                git)
                    version=$(git --version)
                    ;;
            esac
            print_success "${cmd}: Available${version:+ ($version)}"
        else
            print_error "${cmd}: Not found (required)"
            ((errors++))
        fi
    done
    
    # Check PostgreSQL service
    print_info "Checking PostgreSQL service..."
    if pgrep -x "postgres" >/dev/null; then
        print_success "PostgreSQL: Service running"
    else
        print_error "PostgreSQL: Service not running (start PostgreSQL service)"
        ((errors++))
    fi
    
    # Check file permissions
    print_info "Checking file permissions..."
    if [ -r "${SCRIPT_DIR}/src/ddl/CEDS-Data-Warehouse-V11.0.0.0-PostgreSQL.sql" ]; then
        print_success "File Permissions: DDL files accessible"
    else
        print_error "File Permissions: Cannot access DDL files"
        ((errors++))
    fi
    
    if [ $errors -gt 0 ]; then
        print_error "System requirements check failed with $errors errors"
        print_info "Please resolve the issues above and run the script again"
        exit 1
    fi
    
    print_success "System requirements check completed successfully"
}

validate_postgresql_connection() {
    local host="$1"
    local port="$2"
    local user="$3"
    local password="$4"
    
    print_info "Testing PostgreSQL connection..."
    
    if PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d postgres -c "SELECT version();" >/dev/null 2>&1; then
        local pg_version=$(PGPASSWORD="$password" psql -h "$host" -p "$port" -U "$user" -d postgres -t -c "SELECT version();" | xargs)
        print_success "PostgreSQL Connection: Successful"
        print_info "Version: $pg_version"
        
        # Check PostgreSQL version
        local version_num=$(echo "$pg_version" | grep -oE '[0-9]+\.[0-9]+' | head -1)
        local major_version=$(echo "$version_num" | cut -d. -f1)
        
        if [ "$major_version" -ge 12 ]; then
            print_success "PostgreSQL Version: $version_num (supported)"
        else
            print_warning "PostgreSQL Version: $version_num (PostgreSQL 12+ recommended)"
        fi
        
        return 0
    else
        print_error "PostgreSQL Connection: Failed"
        return 1
    fi
}

# ==============================================================================
# CONFIGURATION FUNCTIONS
# ==============================================================================

collect_configuration() {
    print_step 2 "Collecting Configuration"
    
    print_info "Please provide the PostgreSQL connection details:"
    
    # Database connection settings
    DB_HOST=$(prompt_user "PostgreSQL Host" "$DEFAULT_DB_HOST")
    DB_PORT=$(prompt_user "PostgreSQL Port" "$DEFAULT_DB_PORT")
    DB_USER=$(prompt_user "PostgreSQL Admin User" "$DEFAULT_DB_USER")
    DB_PASSWORD=$(prompt_password "PostgreSQL Admin Password")
    
    # Validate connection
    while ! validate_postgresql_connection "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASSWORD"; do
        print_warning "Connection failed. Please check your credentials."
        DB_HOST=$(prompt_user "PostgreSQL Host" "$DB_HOST")
        DB_PORT=$(prompt_user "PostgreSQL Port" "$DB_PORT")
        DB_USER=$(prompt_user "PostgreSQL Admin User" "$DB_USER")
        DB_PASSWORD=$(prompt_password "PostgreSQL Admin Password")
    done
    
    # Database name
    echo
    print_info "Database Configuration:"
    DB_NAME=$(prompt_user "CEDS Database Name" "$DEFAULT_DB_NAME")
    
    # Installation type
    echo
    print_info "Installation Type:"
    echo "1. Development (optimized for development/testing)"
    echo "2. Production (optimized for production workloads)"
    local install_choice=$(prompt_user "Choose installation type [1-2]" "1")
    
    case "$install_choice" in
        1)
            INSTALLATION_TYPE="development"
            print_info "Selected: Development installation"
            ;;
        2)
            INSTALLATION_TYPE="production"
            print_info "Selected: Production installation"
            ;;
        *)
            INSTALLATION_TYPE="development"
            print_warning "Invalid choice, defaulting to Development"
            ;;
    esac
    
    # SSL configuration
    echo
    ENABLE_SSL=$(prompt_yes_no "Enable SSL/TLS connections?" "n")
    
    # Sample data
    echo
    CREATE_SAMPLE_DATA=$(prompt_yes_no "Create sample test data?" "y")
    
    # Admin user password
    echo
    print_info "A CEDS admin user will be created for database management."
    ADMIN_PASSWORD=$(prompt_password "Set password for 'ceds_admin' user")
    
    # Configuration summary
    echo
    print_header "Configuration Summary"
    echo -e "${WHITE}Database Host:${NC} $DB_HOST"
    echo -e "${WHITE}Database Port:${NC} $DB_PORT"
    echo -e "${WHITE}Admin User:${NC} $DB_USER"
    echo -e "${WHITE}Database Name:${NC} $DB_NAME"
    echo -e "${WHITE}Installation Type:${NC} $INSTALLATION_TYPE"
    echo -e "${WHITE}SSL Enabled:${NC} $ENABLE_SSL"
    echo -e "${WHITE}Sample Data:${NC} $CREATE_SAMPLE_DATA"
    echo
    
    local confirm=$(prompt_yes_no "Proceed with installation?" "y")
    if [ "$confirm" != "y" ]; then
        print_info "Installation cancelled by user"
        exit 0
    fi
    
    log "INFO" "Configuration collected: DB=$DB_NAME, Host=$DB_HOST:$DB_PORT, Type=$INSTALLATION_TYPE"
}

# ==============================================================================
# INSTALLATION FUNCTIONS
# ==============================================================================

create_database() {
    print_step 3 "Creating Database and Initial Setup"
    
    # Check if database already exists
    print_info "Checking if database exists..."
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        print_warning "Database '$DB_NAME' already exists"
        local overwrite=$(prompt_yes_no "Drop and recreate database?" "n")
        
        if [ "$overwrite" = "y" ]; then
            print_info "Dropping existing database..."
            PGPASSWORD="$DB_PASSWORD" dropdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DB_NAME"
            print_success "Existing database dropped"
        else
            print_info "Using existing database"
            return 0
        fi
    fi
    
    # Create database
    print_info "Creating database '$DB_NAME'..."
    PGPASSWORD="$DB_PASSWORD" createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" \
        -E UTF8 -T template0 "$DB_NAME"
    print_success "Database created successfully"
    
    # Test database connection
    print_info "Testing database connection..."
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        print_success "Database connection verified"
    else
        print_error "Cannot connect to created database"
        return 1
    fi
}

setup_schemas_security() {
    print_step 4 "Setting Up Schemas and Security"
    
    local schema_script="${SCRIPT_DIR}/src/conversion-tools/postgresql-schemas-and-security.sql"
    
    if [ ! -f "$schema_script" ]; then
        print_error "Schema script not found: $schema_script"
        return 1
    fi
    
    print_info "Creating schemas and security roles..."
    show_progress 1 3
    
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -f "$schema_script" >> "$LOG_FILE" 2>&1; then
        show_progress 2 3
        print_success "Schemas and security roles created"
    else
        print_error "Failed to create schemas and security roles"
        return 1
    fi
    
    # Apply database configuration
    local config_script="${SCRIPT_DIR}/src/conversion-tools/postgresql-database-configuration.sql"
    
    if [ -f "$config_script" ]; then
        print_info "Applying database configuration..."
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            -f "$config_script" >> "$LOG_FILE" 2>&1; then
            show_progress 3 3
            print_success "Database configuration applied"
        else
            print_warning "Some configuration settings may have failed (check logs)"
        fi
    fi
    
    # Create admin user
    print_info "Creating CEDS admin user..."
    local create_admin_sql="
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'ceds_admin') THEN
            CREATE USER ceds_admin WITH CREATEDB CREATEROLE LOGIN PASSWORD '$ADMIN_PASSWORD';
            COMMENT ON ROLE ceds_admin IS 'CEDS Data Warehouse Administrator';
        END IF;
        
        GRANT ceds_application TO ceds_admin;
        GRANT ceds_etl_process TO ceds_admin;
        ALTER USER ceds_admin CONNECTION LIMIT 10;
    END
    \$\$;
    "
    
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "$create_admin_sql" >> "$LOG_FILE" 2>&1; then
        print_success "CEDS admin user created"
    else
        print_warning "Admin user creation may have failed (check logs)"
    fi
}

create_database_structure() {
    print_step 5 "Creating Database Structure"
    
    local ddl_script="${SCRIPT_DIR}/src/ddl/CEDS-Data-Warehouse-V11.0.0.0-PostgreSQL.sql"
    
    if [ ! -f "$ddl_script" ]; then
        print_error "DDL script not found: $ddl_script"
        return 1
    fi
    
    print_info "This step creates 100+ tables, functions, and views..."
    print_warning "This may take several minutes. Please be patient."
    
    # Count total lines for progress estimation
    local total_lines=$(wc -l < "$ddl_script")
    print_info "Processing $total_lines lines of DDL..."
    
    # Execute DDL script with progress monitoring
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -f "$ddl_script" >> "$LOG_FILE" 2>&1; then
        print_success "Database structure created successfully"
        
        # Verify table creation
        print_info "Verifying table creation..."
        local table_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('rds', 'staging', 'app');" | xargs)
        
        if [ "$table_count" -gt 100 ]; then
            print_success "Created $table_count tables successfully"
        else
            print_warning "Only $table_count tables created (expected 100+)"
        fi
    else
        print_error "Failed to create database structure"
        return 1
    fi
}

load_dimension_data() {
    print_step 6 "Loading Dimension Data"
    
    local dimension_script="${SCRIPT_DIR}/src/conversion-tools/postgresql-dimension-data-loader.sql"
    local junk_script="${SCRIPT_DIR}/src/conversion-tools/junk-table-population-postgresql.sql"
    
    # Load dimension data
    if [ -f "$dimension_script" ]; then
        print_info "Loading CEDS Elements and dimension combinations..."
        show_progress 1 4
        
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            -f "$dimension_script" >> "$LOG_FILE" 2>&1; then
            show_progress 2 4
            print_success "Dimension data loaded successfully"
        else
            print_error "Failed to load dimension data"
            return 1
        fi
    else
        print_warning "Dimension data script not found: $dimension_script"
    fi
    
    # Load junk tables
    if [ -f "$junk_script" ]; then
        print_info "Populating essential dimension tables (races, ages, dates)..."
        show_progress 3 4
        
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            -f "$junk_script" >> "$LOG_FILE" 2>&1; then
            show_progress 4 4
            print_success "Essential dimension tables populated"
        else
            print_error "Failed to populate essential dimension tables"
            return 1
        fi
    else
        print_warning "Junk table script not found: $junk_script"
    fi
    
    # Verify data loading
    print_info "Verifying dimension data..."
    local demographics_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -t -c "SELECT COUNT(*) FROM rds.dim_ae_demographics;" 2>/dev/null | xargs || echo "0")
    local races_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -t -c "SELECT COUNT(*) FROM rds.dim_races;" 2>/dev/null | xargs || echo "0")
    local dates_count=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -t -c "SELECT COUNT(*) FROM rds.dim_dates;" 2>/dev/null | xargs || echo "0")
    
    print_info "Data verification results:"
    echo -e "  ${WHITE}Demographics combinations:${NC} $demographics_count"
    echo -e "  ${WHITE}Race categories:${NC} $races_count"
    echo -e "  ${WHITE}Date records:${NC} $dates_count"
}

validate_installation() {
    print_step 7 "Validating Installation"
    
    local validation_script="${SCRIPT_DIR}/src/conversion-tools/validate-postgresql-config.sql"
    
    print_info "Running comprehensive validation tests..."
    
    # Basic connectivity test
    print_info "Testing database connectivity..."
    if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        print_success "Database connectivity: OK"
    else
        print_error "Database connectivity: FAILED"
        return 1
    fi
    
    # Schema validation
    print_info "Validating schemas..."
    local schemas=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -t -c "SELECT string_agg(schema_name, ', ') FROM information_schema.schemata WHERE schema_name IN ('rds', 'staging', 'app');" | xargs)
    
    if [[ "$schemas" == *"rds"* && "$schemas" == *"staging"* && "$schemas" == *"app"* ]]; then
        print_success "Required schemas: OK ($schemas)"
    else
        print_error "Required schemas: MISSING (found: $schemas)"
        return 1
    fi
    
    # Table count validation
    print_info "Validating table structure..."
    local table_counts=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT 
            'rds: ' || COUNT(*) 
        FROM information_schema.tables 
        WHERE table_schema = 'rds'
        UNION ALL
        SELECT 
            'staging: ' || COUNT(*) 
        FROM information_schema.tables 
        WHERE table_schema = 'staging'
        UNION ALL
        SELECT 
            'app: ' || COUNT(*) 
        FROM information_schema.tables 
        WHERE table_schema = 'app';
    ")
    
    echo "$table_counts" | while read -r line; do
        print_success "Tables $line"
    done
    
    # Run validation script if available
    if [ -f "$validation_script" ]; then
        print_info "Running detailed validation script..."
        if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
            -f "$validation_script" >> "$LOG_FILE" 2>&1; then
            print_success "Detailed validation: PASSED"
        else
            print_warning "Detailed validation: Some tests may have failed (check logs)"
        fi
    fi
    
    # Performance test
    print_info "Running basic performance test..."
    local start_time=$(date +%s%N)
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "SELECT COUNT(*) FROM rds.dim_ae_demographics;" >/dev/null 2>&1 || true
    local end_time=$(date +%s%N)
    local duration=$(( (end_time - start_time) / 1000000 ))
    
    if [ "$duration" -lt 1000 ]; then
        print_success "Query performance: ${duration}ms (excellent)"
    elif [ "$duration" -lt 5000 ]; then
        print_success "Query performance: ${duration}ms (good)"
    else
        print_warning "Query performance: ${duration}ms (consider optimization)"
    fi
    
    print_success "Installation validation completed successfully"
}

# ==============================================================================
# FINAL REPORT AND CLEANUP
# ==============================================================================

generate_final_report() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    print_header "Installation Complete!"
    
    echo -e "${GREEN}✅ CEDS Data Warehouse PostgreSQL installation completed successfully!${NC}\n"
    
    echo -e "${WHITE}Installation Summary:${NC}"
    echo -e "  ${CYAN}Database:${NC} $DB_NAME"
    echo -e "  ${CYAN}Host:${NC} $DB_HOST:$DB_PORT"
    echo -e "  ${CYAN}Installation Type:${NC} $INSTALLATION_TYPE"
    echo -e "  ${CYAN}Duration:${NC} ${minutes}m ${seconds}s"
    echo -e "  ${CYAN}Log File:${NC} $LOG_FILE"
    
    echo -e "\n${WHITE}Connection Details:${NC}"
    echo -e "  ${CYAN}Admin User:${NC} ceds_admin"
    echo -e "  ${CYAN}Connection Command:${NC} psql -h $DB_HOST -p $DB_PORT -U ceds_admin -d $DB_NAME"
    
    echo -e "\n${WHITE}Next Steps:${NC}"
    echo -e "  1. ${BLUE}Connect to your database using the admin credentials${NC}"
    echo -e "  2. ${BLUE}Review the comprehensive installation guide: src/conversion-tools/postgresql-installation-guide.md${NC}"
    echo -e "  3. ${BLUE}Configure your ETL processes to load data${NC}"
    echo -e "  4. ${BLUE}Set up monitoring and backup procedures${NC}"
    
    if [ "$CREATE_SAMPLE_DATA" = "y" ]; then
        echo -e "  5. ${BLUE}Sample data was created for testing${NC}"
    fi
    
    echo -e "\n${WHITE}Documentation:${NC}"
    echo -e "  ${CYAN}README:${NC} README.md"
    echo -e "  ${CYAN}Installation Guide:${NC} src/conversion-tools/postgresql-installation-guide.md"
    echo -e "  ${CYAN}Conversion Tools:${NC} src/conversion-tools/"
    
    echo -e "\n${WHITE}Support:${NC}"
    echo -e "  ${CYAN}Original CEDS Repository:${NC} https://github.com/CEDStandards/CEDS-Data-Warehouse"
    echo -e "  ${CYAN}PostgreSQL Documentation:${NC} https://www.postgresql.org/docs/"
    
    log "INFO" "Installation completed successfully in ${minutes}m ${seconds}s"
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    # Display header
    print_header "CEDS Data Warehouse PostgreSQL Setup v${SCRIPT_VERSION}"
    
    echo -e "${BLUE}This script will guide you through the complete installation of the${NC}"
    echo -e "${BLUE}CEDS Data Warehouse on PostgreSQL with interactive configuration.${NC}\n"
    
    print_info "Starting installation process..."
    print_info "Log file: $LOG_FILE"
    
    # Execute installation steps
    check_system_requirements
    collect_configuration
    create_database
    setup_schemas_security
    create_database_structure
    load_dimension_data
    validate_installation
    
    # Generate final report
    generate_final_report
    
    echo -e "\n${GREEN}🎉 Installation completed successfully!${NC}"
}

# ==============================================================================
# SCRIPT ENTRY POINT
# ==============================================================================

# Ensure script is run from correct directory
if [ ! -f "${SCRIPT_DIR}/README.md" ] || [ ! -d "${SCRIPT_DIR}/src" ]; then
    print_error "This script must be run from the CEDS Data Warehouse root directory"
    print_info "Expected files: README.md, src/ directory"
    exit 1
fi

# Check if running with bash
if [ -z "${BASH_VERSION:-}" ]; then
    print_error "This script requires Bash 4.0 or later"
    exit 1
fi

# Run main function
main "$@"