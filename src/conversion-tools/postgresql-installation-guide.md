# CEDS Data Warehouse PostgreSQL Installation and Setup Guide

## Overview

This comprehensive guide provides step-by-step instructions for installing and setting up PostgreSQL for the CEDS Data Warehouse, including all necessary components, configurations, and validations.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [PostgreSQL Installation](#postgresql-installation)  
3. [Initial Configuration](#initial-configuration)
4. [CEDS Database Setup](#ceds-database-setup)
5. [Security Configuration](#security-configuration)
6. [Performance Optimization](#performance-optimization)
7. [Monitoring Setup](#monitoring-setup)
8. [Backup and Recovery](#backup-and-recovery)
9. [Validation and Testing](#validation-and-testing)
10. [Maintenance Procedures](#maintenance-procedures)
11. [Troubleshooting](#troubleshooting)

## System Requirements

### Minimum Requirements
- **Operating System**: Linux (Ubuntu 20.04+, CentOS 8+, RHEL 8+), Windows 10+, macOS 10.15+
- **CPU**: 4 cores (8+ recommended for production)
- **Memory**: 8GB RAM (16GB+ recommended for production)  
- **Storage**: 100GB free space (500GB+ recommended for production data)
- **Network**: Reliable network connectivity for client connections

### Recommended Production Specifications
- **CPU**: 8+ cores with good single-thread performance
- **Memory**: 32GB+ RAM for large datasets
- **Storage**: SSD storage with 1TB+ capacity
- **Network**: Gigabit ethernet
- **OS**: Linux (preferred for production deployments)

### Software Dependencies
- PostgreSQL 12+ (PostgreSQL 14+ recommended)
- Python 3.8+ (for conversion tools)
- Git (for accessing conversion scripts)
- Text editor or IDE
- SQL client tool (pgAdmin, DBeaver, or psql)

## PostgreSQL Installation

### Ubuntu/Debian Installation

#### Option 1: Official PostgreSQL APT Repository (Recommended)
```bash
# Install prerequisites
sudo apt update
sudo apt install -y wget ca-certificates

# Add PostgreSQL official APT repository
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" | sudo tee /etc/apt/sources.list.d/pgdg.list

# Update package list
sudo apt update

# Install PostgreSQL 14 (or latest)
sudo apt install -y postgresql-14 postgresql-client-14 postgresql-contrib-14

# Install additional tools
sudo apt install -y postgresql-14-pgstattuple postgresql-14-pg-stat-kcache
```

#### Option 2: Ubuntu Default Repository
```bash
# Install from default repository (may be older version)
sudo apt update
sudo apt install -y postgresql postgresql-contrib

# Check installed version
sudo -u postgres psql -c "SELECT version();"
```

### CentOS/RHEL Installation

```bash
# Install PostgreSQL repository
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Install PostgreSQL
sudo dnf install -y postgresql14-server postgresql14-contrib

# Initialize database
sudo /usr/pgsql-14/bin/postgresql-14-setup initdb

# Enable and start PostgreSQL service
sudo systemctl enable postgresql-14
sudo systemctl start postgresql-14
```

### Windows Installation

1. **Download PostgreSQL Installer**:
   - Visit https://www.postgresql.org/download/windows/
   - Download the latest version (14+) for your architecture
   - Run the installer as Administrator

2. **Installation Options**:
   - Install location: `C:\Program Files\PostgreSQL\14`
   - Data directory: `C:\Program Files\PostgreSQL\14\data`
   - Password: Set a strong password for the postgres user
   - Port: 5432 (default)
   - Locale: Default locale
   - Components: Install all components including pgAdmin and Stack Builder

3. **Post-Installation**:
   - Add PostgreSQL bin directory to PATH
   - Verify installation: `psql --version`

### macOS Installation

#### Option 1: Homebrew (Recommended)
```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install PostgreSQL
brew install postgresql@14

# Start PostgreSQL service
brew services start postgresql@14

# Create postgres user (if needed)
createuser -s postgres
```

#### Option 2: PostgreSQL.app
1. Download from https://postgresapp.com/
2. Drag to Applications folder
3. Launch and click "Initialize"
4. Add to PATH: `export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"`

## Initial Configuration

### 1. Basic Service Configuration

#### Linux Systems
```bash
# Start and enable PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Check service status
sudo systemctl status postgresql

# Switch to postgres user
sudo -i -u postgres

# Connect to PostgreSQL
psql
```

#### Windows Systems
```cmd
# Services should start automatically after installation
# If needed, start manually:
net start postgresql-x64-14

# Connect using pgAdmin or command line
psql -U postgres -h localhost
```

### 2. Initial Security Setup

```sql
-- Connect as postgres superuser
psql -U postgres

-- Set password for postgres user (if not set during installation)
ALTER USER postgres PASSWORD 'your_secure_password_here';

-- Create administrative user for CEDS
CREATE USER ceds_admin WITH CREATEDB CREATEROLE LOGIN PASSWORD 'admin_password_here';

-- Exit psql
\q
```

### 3. Configure PostgreSQL Settings

#### Edit postgresql.conf
```bash
# Find configuration file location
sudo -u postgres psql -c "SHOW config_file;"

# Edit postgresql.conf (adjust path as needed)
sudo nano /etc/postgresql/14/main/postgresql.conf
```

#### Essential Settings (add to postgresql.conf):
```ini
# Connection settings
listen_addresses = 'localhost'          # Change to '*' for remote connections
port = 5432
max_connections = 200

# Memory settings (adjust based on available RAM)
shared_buffers = 256MB                   # 25% of RAM for dedicated server
effective_cache_size = 1GB               # 75% of available RAM
work_mem = 32MB
maintenance_work_mem = 256MB

# Write-ahead logging
wal_level = replica
wal_buffers = 16MB
checkpoint_completion_target = 0.8

# Query planner
random_page_cost = 1.1                   # 1.1 for SSD, 4.0 for HDD
effective_io_concurrency = 200           # For SSD storage

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = 'log'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_min_duration_statement = 5000        # Log queries > 5 seconds
log_checkpoints = on
log_connections = on
log_disconnections = on

# Autovacuum
autovacuum = on
autovacuum_naptime = 5min
autovacuum_vacuum_scale_factor = 0.1
autovacuum_analyze_scale_factor = 0.05

# Statistics
track_activities = on
track_counts = on
track_functions = all
track_io_timing = on
```

#### Configure Client Authentication (pg_hba.conf)
```bash
# Edit pg_hba.conf
sudo nano /etc/postgresql/14/main/pg_hba.conf
```

#### Recommended pg_hba.conf entries:
```ini
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# Local connections
local   all             postgres                                peer
local   all             ceds_admin                              md5
local   all             all                                     md5

# IPv4 local connections
host    all             postgres        127.0.0.1/32           md5
host    all             ceds_admin      127.0.0.1/32           md5
host    ceds_data_warehouse_v11_0_0_0   all   127.0.0.1/32     md5

# IPv6 local connections  
host    all             all             ::1/128                 md5

# Remote connections (uncomment and configure as needed)
# host    ceds_data_warehouse_v11_0_0_0   all   0.0.0.0/0       md5
```

### 4. Restart PostgreSQL
```bash
# Linux
sudo systemctl restart postgresql

# Windows
net stop postgresql-x64-14
net start postgresql-x64-14

# macOS (Homebrew)
brew services restart postgresql@14
```

## CEDS Database Setup

### 1. Clone the Conversion Tools Repository
```bash
# Clone the repository with conversion tools
git clone <repository-url> ceds-postgresql-conversion
cd ceds-postgresql-conversion/src/conversion-tools
```

### 2. Create CEDS Database
```bash
# Connect as postgres or ceds_admin
psql -U ceds_admin -h localhost

# Create the database
CREATE DATABASE ceds_data_warehouse_v11_0_0_0 
WITH 
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TEMPLATE = template0
    CONNECTION LIMIT = 100;

# Connect to the new database
\c ceds_data_warehouse_v11_0_0_0

# Exit psql
\q
```

### 3. Run Database Setup Scripts

#### Step 1: Apply Database Configuration
```bash
# Apply PostgreSQL-specific database settings
psql -U ceds_admin -d ceds_data_warehouse_v11_0_0_0 -f postgresql-database-configuration.sql
```

#### Step 2: Set Up Schemas and Security
```bash
# Create schemas and security roles
psql -U ceds_admin -d ceds_data_warehouse_v11_0_0_0 -f postgresql-schemas-and-security.sql
```

#### Step 3: Create Database Structure
```bash
# Create tables, functions, and views
psql -U ceds_admin -d ceds_data_warehouse_v11_0_0_0 -f ../ddl/CEDS-Data-Warehouse-V11.0.0.0-PostgreSQL.sql
```

#### Step 4: Load Dimension Data
```bash
# Load dimension reference data (demographics, program types, grade levels)
psql -U ceds_admin -d ceds_data_warehouse_v11_0_0_0 -f postgresql-dimension-data-loader.sql

# Populate essential dimension tables (races, ages, dates 2000-2050)
# This script creates the foundational lookup data needed for fact table loading
psql -U ceds_admin -d ceds_data_warehouse_v11_0_0_0 -f junk-table-population-postgresql.sql
```

**What Step 4 Accomplishes:**
- **Dimension Loader**: Creates demographic combinations (19,440+ records), program types, grade levels
- **Junk Table Population**: Adds race categories, age ranges (0-130), and 50 years of date records
- **Essential Foundation**: These lookup tables are required before loading any fact table data

### 4. Validate Installation
```bash
# Run configuration validation
psql -U ceds_admin -d ceds_data_warehouse_v11_0_0_0 -f validate-postgresql-config.sql
```

## Security Configuration

### 1. Create Application Users
```sql
-- Connect as ceds_admin
\c ceds_data_warehouse_v11_0_0_0

-- Create service users
CREATE USER ceds_etl_service WITH PASSWORD 'secure_etl_password';
CREATE USER ceds_app_service WITH PASSWORD 'secure_app_password';
CREATE USER ceds_read_only WITH PASSWORD 'secure_readonly_password';

-- Assign roles
GRANT ceds_etl_process TO ceds_etl_service;
GRANT ceds_application TO ceds_app_service;
GRANT ceds_data_reader TO ceds_read_only;

-- Set connection limits
ALTER USER ceds_etl_service CONNECTION LIMIT 5;
ALTER USER ceds_app_service CONNECTION LIMIT 20;
ALTER USER ceds_read_only CONNECTION LIMIT 10;
```

### 2. SSL/TLS Configuration (Production)

#### Generate SSL Certificates
```bash
# Create SSL directory
sudo mkdir -p /etc/postgresql/14/main/ssl
sudo chown postgres:postgres /etc/postgresql/14/main/ssl

# Generate self-signed certificate (for testing)
sudo -u postgres openssl req -new -x509 -days 365 -nodes -text \
    -out /etc/postgresql/14/main/ssl/server.crt \
    -keyout /etc/postgresql/14/main/ssl/server.key \
    -subj "/CN=ceds-postgres-server"

# Set appropriate permissions
sudo chmod 600 /etc/postgresql/14/main/ssl/server.key
sudo chmod 644 /etc/postgresql/14/main/ssl/server.crt
```

#### Enable SSL in postgresql.conf
```ini
# SSL settings
ssl = on
ssl_cert_file = 'ssl/server.crt'
ssl_key_file = 'ssl/server.key'
ssl_ciphers = 'HIGH:MEDIUM:+3DES:!aNULL'
ssl_prefer_server_ciphers = on
```

#### Update pg_hba.conf for SSL
```ini
# Require SSL for remote connections
hostssl ceds_data_warehouse_v11_0_0_0  all  0.0.0.0/0  md5
```

### 3. Firewall Configuration

#### Ubuntu/Debian (ufw)
```bash
# Allow PostgreSQL port
sudo ufw allow 5432/tcp

# Allow only from specific networks (more secure)
sudo ufw allow from 192.168.1.0/24 to any port 5432
```

#### CentOS/RHEL (firewalld)
```bash
# Open PostgreSQL port
sudo firewall-cmd --permanent --add-port=5432/tcp
sudo firewall-cmd --reload
```

## Performance Optimization

### 1. System-Level Optimizations

#### Linux Kernel Parameters
```bash
# Edit /etc/sysctl.conf
sudo nano /etc/sysctl.conf

# Add these parameters:
# Shared memory settings
kernel.shmmax = 4294967296        # 4GB
kernel.shmall = 1048576          # 4GB / PAGE_SIZE

# Network settings
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216

# Apply changes
sudo sysctl -p
```

#### Disk I/O Optimization
```bash
# Check current scheduler
cat /sys/block/sda/queue/scheduler

# Set deadline scheduler for better database performance (SSD)
echo deadline | sudo tee /sys/block/sda/queue/scheduler

# Make permanent by adding to /etc/rc.local:
echo 'echo deadline > /sys/block/sda/queue/scheduler' | sudo tee -a /etc/rc.local
```

### 2. PostgreSQL Performance Tuning

#### Create Performance Tuning Script
```sql
-- Create performance monitoring function
CREATE OR REPLACE FUNCTION app.performance_report()
RETURNS TABLE(
    metric TEXT,
    value TEXT,
    recommendation TEXT
) AS $$
BEGIN
    -- Database size
    RETURN QUERY
    SELECT 
        'Database Size'::TEXT,
        pg_size_pretty(pg_database_size(current_database()))::TEXT,
        'Monitor growth over time'::TEXT;
    
    -- Buffer cache hit ratio
    RETURN QUERY
    SELECT 
        'Buffer Cache Hit Ratio'::TEXT,
        ROUND(
            (sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read))) * 100, 2
        )::TEXT || '%',
        CASE 
            WHEN (sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read))) > 0.95 
            THEN 'Good performance'
            ELSE 'Consider increasing shared_buffers'
        END
    FROM pg_statio_user_tables;
    
    -- Connection count
    RETURN QUERY
    SELECT 
        'Active Connections'::TEXT,
        COUNT(*)::TEXT,
        'Monitor for connection leaks'::TEXT
    FROM pg_stat_activity 
    WHERE state = 'active';
END;
$$ LANGUAGE plpgsql;
```

### 3. Index Creation Strategy

#### Create Initial Indexes Script
```sql
-- Create essential indexes for CEDS tables
-- Run after data loading for better performance

-- Fact table indexes
CREATE INDEX CONCURRENTLY idx_fact_k12_student_enrollments_school_year 
ON rds.fact_k12_student_enrollments (school_year_id);

CREATE INDEX CONCURRENTLY idx_fact_k12_student_enrollments_school 
ON rds.fact_k12_student_enrollments (dim_k12_school_id);

CREATE INDEX CONCURRENTLY idx_fact_k12_student_enrollments_student 
ON rds.fact_k12_student_enrollments (dim_k12_student_id);

-- Dimension table indexes
CREATE INDEX CONCURRENTLY idx_dim_k12_schools_state_code 
ON rds.dim_k12_schools (state_code);

CREATE INDEX CONCURRENTLY idx_dim_k12_schools_name 
ON rds.dim_k12_schools (school_name);

-- Staging table indexes (for ETL performance)
CREATE INDEX CONCURRENTLY idx_staging_k12_enrollment_school_year 
ON staging.k12_enrollment (school_year);

CREATE INDEX CONCURRENTLY idx_staging_k12_enrollment_student_id 
ON staging.k12_enrollment (student_identifier_state);

-- Update statistics after index creation
ANALYZE;
```

## Monitoring Setup

### 1. Install Monitoring Extensions
```sql
-- Connect as superuser
\c ceds_data_warehouse_v11_0_0_0

-- Install monitoring extensions
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
CREATE EXTENSION IF NOT EXISTS pgstattuple;

-- Configure pg_stat_statements
ALTER SYSTEM SET pg_stat_statements.max = 10000;
ALTER SYSTEM SET pg_stat_statements.track = 'all';
SELECT pg_reload_conf();
```

### 2. Create Monitoring Views
```sql
-- Top slow queries view
CREATE VIEW app.slow_queries AS
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows,
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) AS hit_percent
FROM pg_stat_statements 
ORDER BY mean_time DESC;

-- Database activity view
CREATE VIEW app.database_activity AS
SELECT 
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    blks_read,
    blks_hit,
    tup_returned,
    tup_fetched,
    tup_inserted,
    tup_updated,
    tup_deleted
FROM pg_stat_database;
```

### 3. Set Up Log Analysis

#### Configure Log Rotation
```bash
# Create logrotate configuration
sudo nano /etc/logrotate.d/postgresql

# Add content:
/var/log/postgresql/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 640 postgres postgres
    postrotate
        systemctl reload postgresql
    endscript
}
```

## Backup and Recovery

### 1. Configure Automated Backups

#### Create Backup Script
```bash
#!/bin/bash
# /usr/local/bin/ceds-backup.sh

# Configuration
DB_NAME="ceds_data_warehouse_v11_0_0_0"
BACKUP_DIR="/var/backups/postgresql"
BACKUP_USER="postgres"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create full backup
pg_dump -U "$BACKUP_USER" -d "$DB_NAME" -f "$BACKUP_DIR/ceds_full_backup_$DATE.sql"

# Compress backup
gzip "$BACKUP_DIR/ceds_full_backup_$DATE.sql"

# Create schema-only backup
pg_dump -U "$BACKUP_USER" -d "$DB_NAME" -s -f "$BACKUP_DIR/ceds_schema_backup_$DATE.sql"
gzip "$BACKUP_DIR/ceds_schema_backup_$DATE.sql"

# Remove old backups
find "$BACKUP_DIR" -name "ceds_*_backup_*.sql.gz" -mtime +$RETENTION_DAYS -delete

# Log backup completion
echo "$(date): CEDS backup completed" >> /var/log/ceds-backup.log
```

#### Make Script Executable and Schedule
```bash
# Make executable
sudo chmod +x /usr/local/bin/ceds-backup.sh

# Add to crontab for daily backups at 2 AM
sudo crontab -e

# Add line:
0 2 * * * /usr/local/bin/ceds-backup.sh
```

### 2. Point-in-Time Recovery Setup

#### Configure WAL Archiving
```ini
# Add to postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/14/archives/%f'
max_wal_senders = 3
wal_keep_segments = 32
```

#### Create Archive Directory
```bash
sudo mkdir -p /var/lib/postgresql/14/archives
sudo chown postgres:postgres /var/lib/postgresql/14/archives
sudo chmod 700 /var/lib/postgresql/14/archives
```

## Validation and Testing

### 1. Run Complete Validation
```bash
# Run comprehensive validation
psql -U ceds_admin -d ceds_data_warehouse_v11_0_0_0 -f validate-postgresql-config.sql > validation_report.txt

# Review results
cat validation_report.txt
```

### 2. Performance Baseline Testing
```sql
-- Connect to database
\c ceds_data_warehouse_v11_0_0_0

-- Test query performance on sample data
EXPLAIN ANALYZE 
SELECT 
    ds.school_name,
    dy.school_year,
    COUNT(*) as enrollment_count
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_k12_schools ds ON fe.dim_k12_school_id = ds.dim_k12_school_id
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
GROUP BY ds.school_name, dy.school_year
ORDER BY enrollment_count DESC
LIMIT 10;

-- Check performance report
SELECT * FROM app.performance_report();
```

### 3. Connection Testing
```bash
# Test different user connections
psql -U ceds_read_only -d ceds_data_warehouse_v11_0_0_0 -c "SELECT COUNT(*) FROM rds.dim_k12_schools;"
psql -U ceds_app_service -d ceds_data_warehouse_v11_0_0_0 -c "SELECT COUNT(*) FROM staging.source_system_reference_data;"
```

## Maintenance Procedures

### 1. Regular Maintenance Script
```bash
#!/bin/bash
# /usr/local/bin/ceds-maintenance.sh

DB_NAME="ceds_data_warehouse_v11_0_0_0"

echo "Starting CEDS maintenance: $(date)"

# Update statistics
psql -U postgres -d "$DB_NAME" -c "ANALYZE;"

# Vacuum tables (full vacuum monthly, regular vacuum weekly)
if [ $(date +%d) -eq 01 ]; then
    echo "Running VACUUM FULL (monthly)"
    psql -U postgres -d "$DB_NAME" -c "VACUUM FULL;"
else
    echo "Running regular VACUUM"
    psql -U postgres -d "$DB_NAME" -c "VACUUM;"
fi

# Check for bloated tables
psql -U postgres -d "$DB_NAME" -c "
SELECT 
    schemaname,
    tablename,
    n_dead_tup,
    n_live_tup,
    ROUND(n_dead_tup::numeric / (n_live_tup + n_dead_tup) * 100, 2) as dead_tuple_percent
FROM pg_stat_user_tables 
WHERE n_live_tup > 0
AND n_dead_tup::numeric / (n_live_tup + n_dead_tup) > 0.1
ORDER BY dead_tuple_percent DESC;
"

echo "CEDS maintenance completed: $(date)"
```

### 2. Schedule Maintenance
```bash
# Add to weekly cron (Sunday 3 AM)
sudo crontab -e

# Add line:
0 3 * * 0 /usr/local/bin/ceds-maintenance.sh
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Script Execution Issues

**Problem**: "relation does not exist" errors during dimension data loading
```
ERROR: relation "rds.dim_ae_demographics" does not exist
```

**Solution**: 
```bash
# Ensure you run scripts in the correct order:
# 1. First create the database structure
psql -d ceds_data_warehouse_v11_0_0_0 -f ../ddl/CEDS-Data-Warehouse-V11.0.0.0-PostgreSQL.sql

# 2. Then load dimension data
psql -d ceds_data_warehouse_v11_0_0_0 -f postgresql-dimension-data-loader.sql

# 3. Finally populate junk tables
psql -d ceds_data_warehouse_v11_0_0_0 -f junk-table-population-postgresql.sql
```

**Problem**: SQL Server syntax errors in PostgreSQL
```
ERROR: syntax error at or near "PRINT"
ERROR: column "current_date" is reserved
```

**Solution**: Ensure you're using the PostgreSQL-converted scripts, not original SQL Server versions. All scripts in `src/conversion-tools/` are PostgreSQL-compatible.

#### 2. Connection Issues
```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Check listening ports
sudo netstat -tlnp | grep 5432

# Test local connection
psql -U postgres -h localhost -c "SELECT version();"

# Check logs
sudo tail -f /var/log/postgresql/postgresql-*.log
```

#### 2. Performance Issues
```sql
-- Check slow queries
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Check table bloat
SELECT 
    schemaname,
    tablename,
    n_dead_tup,
    n_live_tup
FROM pg_stat_user_tables 
WHERE n_dead_tup > 1000
ORDER BY n_dead_tup DESC;

-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan = 0;
```

#### 3. Disk Space Issues
```bash
# Check database sizes
psql -U postgres -c "
SELECT 
    datname,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database 
ORDER BY pg_database_size(datname) DESC;
"

# Clean up WAL files (if archiving is working)
sudo -u postgres pg_archivecleanup /var/lib/postgresql/14/pg_wal /var/lib/postgresql/14/archives/
```

## Conclusion

This installation guide provides a complete setup process for the CEDS Data Warehouse on PostgreSQL. Key success factors:

### ✅ **Installation Checklist**
- [ ] PostgreSQL 12+ installed and configured
- [ ] Database created with appropriate settings
- [ ] Schemas and security roles configured
- [ ] CEDS database structure deployed
- [ ] Dimension data loaded
- [ ] Performance optimizations applied
- [ ] Monitoring and logging configured
- [ ] Backup procedures established
- [ ] Validation tests passed

### ✅ **Production Readiness**
- Security hardened with SSL and proper authentication
- Performance optimized for data warehouse workloads
- Monitoring and alerting configured
- Backup and recovery procedures tested
- Maintenance automation in place

### 📞 **Support Resources**
- PostgreSQL Documentation: https://www.postgresql.org/docs/
- CEDS Website: https://ceds.ed.gov/
- Community Forums: https://www.postgresql.org/list/
- Issue Tracking: Use repository issue tracker for conversion-specific problems

The CEDS Data Warehouse is now ready for production use on PostgreSQL with enterprise-grade reliability, performance, and security.