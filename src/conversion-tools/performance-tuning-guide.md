# PostgreSQL Performance Tuning Guide for CEDS Data Warehouse

## Overview

This comprehensive guide provides performance tuning strategies, optimization techniques, and monitoring procedures specifically designed for the CEDS Data Warehouse PostgreSQL implementation. The guide covers indexing strategies, query optimization, hardware tuning, and ongoing maintenance procedures.

## Table of Contents

1. [Performance Architecture](#performance-architecture)
2. [Index Strategy](#index-strategy)
3. [Query Optimization](#query-optimization)
4. [Hardware and System Tuning](#hardware-and-system-tuning)
5. [Memory Management](#memory-management)
6. [Storage Optimization](#storage-optimization)
7. [Monitoring and Alerting](#monitoring-and-alerting)
8. [Maintenance Procedures](#maintenance-procedures)
9. [Troubleshooting Performance Issues](#troubleshooting-performance-issues)
10. [Best Practices](#best-practices)

## Performance Architecture

### CEDS Data Warehouse Characteristics

The CEDS Data Warehouse exhibits typical **OLAP (Online Analytical Processing)** characteristics:

- **Read-Heavy Workload**: 90% SELECT queries, 10% DML operations
- **Large Fact Tables**: Multi-million row tables for enrollments and assessments
- **Star Schema Design**: Central fact tables with dimension lookups
- **Time-Based Queries**: Most queries filter by school year or date ranges
- **Aggregation Operations**: SUM, COUNT, AVG operations across large datasets
- **Reporting Workload**: Regular batch reports and ad-hoc analytical queries

### Performance Goals

| Metric | Target | Notes |
|--------|--------|-------|
| **Query Response Time** | < 5 seconds | For typical analytical queries |
| **Report Generation** | < 30 seconds | For standard CEDS reports |
| **Data Loading** | < 2 hours | For nightly ETL processes |
| **Concurrent Users** | 50+ | Simultaneous report users |
| **Availability** | 99.5% | During business hours |
| **Buffer Cache Hit Ratio** | > 95% | Memory efficiency target |

## Index Strategy

### Primary Index Categories

#### 1. **Dimension Table Indexes**

```sql
-- School dimension - most commonly joined
CREATE INDEX idx_dim_k12_schools_state_code ON rds.dim_k12_schools (state_code);
CREATE INDEX idx_dim_k12_schools_lea_id ON rds.dim_k12_schools (lea_identifier_state);
CREATE INDEX idx_dim_k12_schools_name_state ON rds.dim_k12_schools (school_name, state_code);

-- Student dimension - large table with frequent lookups
CREATE INDEX idx_dim_k12_students_state_id ON rds.dim_k12_students (student_identifier_state);
CREATE INDEX idx_dim_k12_students_name ON rds.dim_k12_students (last_name, first_name);

-- Time dimension - critical for all time-based queries
CREATE INDEX idx_dim_school_years_year ON rds.dim_school_years (school_year);
CREATE INDEX idx_dim_school_years_date_range ON rds.dim_school_years (session_begin_date, session_end_date);
```

#### 2. **Fact Table Indexes**

```sql
-- Foreign key indexes for joins (CRITICAL)
CREATE INDEX idx_fact_k12_enrollments_school_year ON rds.fact_k12_student_enrollments (school_year_id);
CREATE INDEX idx_fact_k12_enrollments_school ON rds.fact_k12_student_enrollments (dim_k12_school_id);
CREATE INDEX idx_fact_k12_enrollments_student ON rds.fact_k12_student_enrollments (dim_k12_student_id);

-- Composite indexes for common query patterns
CREATE INDEX idx_fact_enrollments_school_year_grade ON rds.fact_k12_student_enrollments (school_year_id, dim_grade_level_id);
CREATE INDEX idx_fact_enrollments_lea_year ON rds.fact_k12_student_enrollments (dim_lea_id, school_year_id);
```

#### 3. **Staging Table Indexes** (ETL Performance)

```sql
-- Essential for ETL matching and lookups
CREATE INDEX idx_staging_k12_enrollment_student_id ON staging.k12_enrollment (student_identifier_state);
CREATE INDEX idx_staging_k12_enrollment_school_year ON staging.k12_enrollment (school_year);
CREATE INDEX idx_staging_source_ref_lookup ON staging.source_system_reference_data (table_name, input_code);
```

### Index Design Principles

#### ✅ **DO Create Indexes For:**
- All foreign key columns (essential for joins)
- Columns frequently used in WHERE clauses
- Columns used in ORDER BY clauses
- Composite indexes for multi-column filters
- Partial indexes for selective queries

#### ❌ **AVOID Creating Indexes For:**
- Columns with low selectivity (< 5% unique values)
- Very wide columns (> 100 characters)
- Columns that change frequently
- Tables with high INSERT/UPDATE activity
- Temporary or staging tables (unless specifically needed)

### Partial Index Examples

```sql
-- Index only active schools
CREATE INDEX idx_dim_schools_active 
ON rds.dim_k12_schools (school_name, state_code) 
WHERE operational_status_code = 'Open';

-- Index only current school year enrollments
CREATE INDEX idx_fact_enrollments_current 
ON rds.fact_k12_student_enrollments (dim_k12_school_id, dim_k12_student_id) 
WHERE school_year_id = (SELECT MAX(dim_school_year_id) FROM rds.dim_school_years);

-- Index only students with special education services
CREATE INDEX idx_staging_enrollment_sped 
ON staging.k12_enrollment (student_identifier_state, school_identifier_state) 
WHERE idea_indicator = 'Yes';
```

## Query Optimization

### Common Query Patterns and Optimizations

#### 1. **Time-Based Filtering (Most Common)**

```sql
-- ❌ INEFFICIENT: Function on column prevents index usage
SELECT COUNT(*) 
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
WHERE EXTRACT(YEAR FROM dy.session_begin_date) = 2023;

-- ✅ EFFICIENT: Direct comparison allows index usage
SELECT COUNT(*) 
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
WHERE dy.school_year = 2023;
```

#### 2. **State/District Filtering**

```sql
-- ✅ OPTIMIZED: Use specific indexes and joins
SELECT 
    ds.school_name,
    COUNT(*) as enrollment_count
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_k12_schools ds ON fe.dim_k12_school_id = ds.dim_k12_school_id
WHERE ds.state_code = 'CA'
AND fe.school_year_id = (SELECT dim_school_year_id FROM rds.dim_school_years WHERE school_year = 2023)
GROUP BY ds.school_name
ORDER BY enrollment_count DESC;
```

#### 3. **Demographic Analysis**

```sql
-- ✅ OPTIMIZED: Pre-aggregate using materialized views
SELECT 
    race_code,
    ethnicity_code,
    SUM(total_student_count) as total_students
FROM performance.mv_demographics_summary
WHERE school_year = 2023
AND state_code = 'TX'
GROUP BY race_code, ethnicity_code;
```

### Query Plan Analysis

#### Using EXPLAIN ANALYZE

```sql
-- Analyze query performance
EXPLAIN (ANALYZE, BUFFERS, VERBOSE) 
SELECT 
    ds.state_code,
    COUNT(*) as school_count,
    SUM(fe.student_count) as total_enrollment
FROM rds.fact_k12_student_enrollments fe
JOIN rds.dim_k12_schools ds ON fe.dim_k12_school_id = ds.dim_k12_school_id
JOIN rds.dim_school_years dy ON fe.school_year_id = dy.dim_school_year_id
WHERE dy.school_year BETWEEN 2020 AND 2023
GROUP BY ds.state_code
ORDER BY total_enrollment DESC;
```

#### Interpreting Results

- **Seq Scan**: Full table scan - usually indicates missing index
- **Index Scan**: Good - using index effectively
- **Nested Loop**: Efficient for small result sets
- **Hash Join**: Good for larger result sets
- **Sort**: Expensive - consider adding ORDER BY index
- **Buffers Hit**: Should be > 95% for good cache performance

### Query Optimization Checklist

- [ ] **WHERE clauses** use indexed columns
- [ ] **JOIN conditions** use indexed foreign keys  
- [ ] **ORDER BY** columns have indexes
- [ ] **GROUP BY** considers composite indexes
- [ ] **Date ranges** use direct comparisons, not functions
- [ ] **LIMIT** is used for large result sets
- [ ] **Materialized views** used for complex aggregations

## Hardware and System Tuning

### Server Specifications

#### Minimum Production Requirements
- **CPU**: 8 cores, 3.0+ GHz
- **Memory**: 32GB RAM
- **Storage**: 1TB SSD with 3000+ IOPS
- **Network**: Gigabit Ethernet

#### Recommended Production Specifications
- **CPU**: 16+ cores, 3.5+ GHz (Intel Xeon or AMD EPYC)
- **Memory**: 64GB+ RAM
- **Storage**: NVMe SSD RAID 10, 10,000+ IOPS
- **Network**: 10 Gigabit Ethernet

### Operating System Tuning

#### Linux Kernel Parameters (`/etc/sysctl.conf`)

```bash
# Memory management
vm.swappiness = 1                    # Minimize swapping
vm.overcommit_memory = 2             # Don't overcommit memory
vm.overcommit_ratio = 80             # Conservative memory allocation

# Shared memory settings
kernel.shmmax = 68719476736          # 64GB max shared memory
kernel.shmall = 16777216             # Total shared memory pages
kernel.shmmni = 4096                 # Max shared memory segments

# Network optimization
net.core.rmem_default = 262144       # Default receive buffer
net.core.rmem_max = 16777216         # Max receive buffer
net.core.wmem_default = 262144       # Default send buffer
net.core.wmem_max = 16777216         # Max send buffer

# File system
fs.file-max = 65536                  # Max open files
```

#### Apply settings:
```bash
sudo sysctl -p
```

### Storage Configuration

#### Disk Layout Strategy

```bash
# Recommended disk layout for dedicated PostgreSQL server
/var/lib/postgresql/data/           # Data files - Fast SSD
/var/lib/postgresql/wal/            # WAL files - Separate fast SSD  
/var/lib/postgresql/tablespaces/    # Large tables - High capacity SSD
/var/log/postgresql/                # Log files - Standard SSD
/backup/                            # Backups - High capacity HDD
```

#### File System Optimization

```bash
# Mount options for PostgreSQL data directory
/dev/sdb1 /var/lib/postgresql/data ext4 defaults,noatime,nodiratime 0 2

# For XFS (alternative, often better for large files):
/dev/sdb1 /var/lib/postgresql/data xfs defaults,noatime,nodiratime,logbufs=8,logbsize=256k 0 2
```

## Memory Management

### PostgreSQL Memory Configuration

#### Core Memory Settings

```ini
# postgresql.conf memory settings for 64GB server

# Shared memory (25% of total RAM)
shared_buffers = 16GB

# Query planner memory estimation (75% of total RAM)
effective_cache_size = 48GB

# Per-operation memory (start conservative)
work_mem = 64MB

# Maintenance operations (10% of RAM or 2GB max)
maintenance_work_mem = 2GB

# WAL buffers (3% of shared_buffers, max 16MB)
wal_buffers = 16MB

# Connection-specific
temp_buffers = 32MB
```

#### Dynamic Memory Adjustment

```sql
-- Monitor memory usage
SELECT 
    name,
    setting,
    unit,
    category,
    short_desc
FROM pg_settings 
WHERE name IN (
    'shared_buffers', 'effective_cache_size', 'work_mem', 
    'maintenance_work_mem', 'wal_buffers'
);

-- Adjust work_mem for specific sessions
SET work_mem = '1GB';  -- For complex analytical queries
SET work_mem = '32MB'; -- Restore default after query
```

### Memory Monitoring

```sql
-- Check buffer cache effectiveness
SELECT 
    'Buffer Cache Hit Ratio' as metric,
    ROUND(
        100.0 * SUM(heap_blks_hit) / 
        NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0), 2
    ) || '%' as value
FROM pg_statio_user_tables;

-- Monitor memory usage by query
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    shared_blks_hit,
    shared_blks_read,
    CASE 
        WHEN shared_blks_hit + shared_blks_read = 0 THEN 0
        ELSE ROUND(100.0 * shared_blks_hit / (shared_blks_hit + shared_blks_read), 2)
    END as cache_hit_percent
FROM pg_stat_statements
ORDER BY total_time DESC
LIMIT 10;
```

## Storage Optimization

### WAL (Write-Ahead Logging) Configuration

```ini
# WAL settings for OLAP workload
wal_level = replica                    # Enable streaming replication
wal_compression = on                   # Compress WAL records
max_wal_size = 4GB                     # Maximum WAL size before checkpoint
min_wal_size = 1GB                     # Minimum WAL size to keep
checkpoint_completion_target = 0.8     # Spread checkpoint I/O
checkpoint_timeout = 15min             # Maximum time between checkpoints
```

### Tablespace Strategy

```sql
-- Create separate tablespaces for different data types
CREATE TABLESPACE ceds_dimensions LOCATION '/var/lib/postgresql/tablespaces/dimensions';
CREATE TABLESPACE ceds_facts LOCATION '/var/lib/postgresql/tablespaces/facts';
CREATE TABLESPACE ceds_indexes LOCATION '/var/lib/postgresql/tablespaces/indexes';
CREATE TABLESPACE ceds_staging LOCATION '/var/lib/postgresql/tablespaces/staging';

-- Move large tables to appropriate tablespaces
ALTER TABLE rds.fact_k12_student_enrollments SET TABLESPACE ceds_facts;
ALTER TABLE rds.dim_k12_students SET TABLESPACE ceds_dimensions;

-- Move indexes to dedicated tablespace
CREATE INDEX idx_fact_enrollments_school_year 
ON rds.fact_k12_student_enrollments (school_year_id) 
TABLESPACE ceds_indexes;
```

### Partitioning Strategy for Large Tables

```sql
-- Partition large fact tables by school year
CREATE TABLE rds.fact_k12_student_enrollments_partitioned (
    LIKE rds.fact_k12_student_enrollments
) PARTITION BY RANGE (school_year_id);

-- Create yearly partitions
CREATE TABLE rds.fact_k12_enrollments_2020 
PARTITION OF rds.fact_k12_student_enrollments_partitioned
FOR VALUES FROM (2020) TO (2021);

CREATE TABLE rds.fact_k12_enrollments_2021 
PARTITION OF rds.fact_k12_student_enrollments_partitioned
FOR VALUES FROM (2021) TO (2022);

CREATE TABLE rds.fact_k12_enrollments_2022 
PARTITION OF rds.fact_k12_student_enrollments_partitioned
FOR VALUES FROM (2022) TO (2023);

-- Create default partition for future data
CREATE TABLE rds.fact_k12_enrollments_default 
PARTITION OF rds.fact_k12_student_enrollments_partitioned
DEFAULT;
```

## Monitoring and Alerting

### Key Performance Metrics

#### 1. **Query Performance Monitoring**

```sql
-- Create monitoring function for slow queries
CREATE OR REPLACE FUNCTION performance.monitor_slow_queries()
RETURNS TABLE(
    query_hash TEXT,
    query_sample TEXT,
    calls BIGINT,
    total_time_hours NUMERIC,
    mean_time_seconds NUMERIC,
    cache_hit_percent NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        md5(pss.query) as query_hash,
        LEFT(regexp_replace(pss.query, '\s+', ' ', 'g'), 100) as query_sample,
        pss.calls,
        ROUND(pss.total_time / 1000.0 / 3600.0, 2) as total_time_hours,
        ROUND(pss.mean_time / 1000.0, 2) as mean_time_seconds,
        ROUND(
            100.0 * pss.shared_blks_hit / 
            NULLIF(pss.shared_blks_hit + pss.shared_blks_read, 0), 2
        ) as cache_hit_percent
    FROM pg_stat_statements pss
    WHERE pss.calls > 10
    AND pss.mean_time > 5000  -- > 5 seconds
    ORDER BY pss.total_time DESC;
END;
$$ LANGUAGE plpgsql;
```

#### 2. **System Resource Monitoring**

```sql
-- Database size and growth monitoring
CREATE OR REPLACE VIEW performance.database_size_monitoring AS
SELECT 
    datname as database_name,
    pg_size_pretty(pg_database_size(datname)) as current_size,
    pg_database_size(datname) as size_bytes,
    CASE 
        WHEN pg_database_size(datname) > 100 * 1024^3 THEN 'LARGE (>100GB)'
        WHEN pg_database_size(datname) > 10 * 1024^3 THEN 'MEDIUM (>10GB)'
        ELSE 'SMALL (<10GB)'
    END as size_category
FROM pg_database
WHERE datname NOT IN ('template0', 'template1', 'postgres')
ORDER BY pg_database_size(datname) DESC;

-- Connection monitoring  
CREATE OR REPLACE VIEW performance.connection_monitoring AS
SELECT 
    state,
    COUNT(*) as connection_count,
    MAX(now() - state_change) as longest_in_state,
    AVG(now() - state_change) as avg_time_in_state
FROM pg_stat_activity
WHERE datname = 'ceds_data_warehouse_v11_0_0_0'
GROUP BY state
ORDER BY connection_count DESC;
```

#### 3. **Automated Alerting Script**

```bash
#!/bin/bash
# PostgreSQL Performance Monitoring Script
# Save as: /usr/local/bin/ceds_performance_monitor.sh

PGHOST="localhost"
PGPORT="5432"
PGDATABASE="ceds_data_warehouse_v11_0_0_0"
PGUSER="postgres"

# Thresholds
MAX_CONNECTIONS=80
MIN_CACHE_HIT_RATIO=95
MAX_SLOW_QUERIES=10

# Check connection count
CONNECTIONS=$(psql -h $PGHOST -p $PGPORT -d $PGDATABASE -U $PGUSER -t -c "SELECT COUNT(*) FROM pg_stat_activity WHERE datname = '$PGDATABASE';")

if [ $CONNECTIONS -gt $MAX_CONNECTIONS ]; then
    echo "ALERT: High connection count: $CONNECTIONS (threshold: $MAX_CONNECTIONS)"
fi

# Check cache hit ratio
CACHE_HIT_RATIO=$(psql -h $PGHOST -p $PGPORT -d $PGDATABASE -U $PGUSER -t -c "
SELECT ROUND(100.0 * SUM(heap_blks_hit) / NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0), 2)
FROM pg_statio_user_tables;")

if (( $(echo "$CACHE_HIT_RATIO < $MIN_CACHE_HIT_RATIO" | bc -l) )); then
    echo "ALERT: Low cache hit ratio: $CACHE_HIT_RATIO% (threshold: $MIN_CACHE_HIT_RATIO%)"
fi

# Check for slow queries
SLOW_QUERIES=$(psql -h $PGHOST -p $PGPORT -d $PGDATABASE -U $PGUSER -t -c "
SELECT COUNT(*) FROM pg_stat_statements WHERE mean_time > 5000;")

if [ $SLOW_QUERIES -gt $MAX_SLOW_QUERIES ]; then
    echo "ALERT: Too many slow queries: $SLOW_QUERIES (threshold: $MAX_SLOW_QUERIES)"
fi
```

### Grafana Dashboard Metrics

Key metrics to monitor in Grafana:

1. **Query Performance**:
   - Average query response time
   - 95th percentile query time
   - Queries per second
   - Slow query count

2. **System Resources**:
   - CPU utilization
   - Memory usage
   - Disk I/O (IOPS, throughput)
   - Network I/O

3. **PostgreSQL Specific**:
   - Buffer cache hit ratio
   - Connection count
   - WAL generation rate
   - Checkpoint frequency
   - Lock waits

## Maintenance Procedures

### Daily Maintenance

```sql
-- Daily maintenance function
CREATE OR REPLACE FUNCTION performance.daily_maintenance()
RETURNS void AS $$
BEGIN
    -- Update table statistics for heavily used tables
    ANALYZE rds.fact_k12_student_enrollments;
    ANALYZE rds.dim_k12_schools;
    ANALYZE rds.dim_k12_students;
    ANALYZE staging.k12_enrollment;
    
    -- Refresh materialized views
    REFRESH MATERIALIZED VIEW CONCURRENTLY performance.mv_enrollment_summary_by_school;
    
    -- Log maintenance completion
    INSERT INTO performance.maintenance_log (maintenance_type, status, notes)
    VALUES ('DAILY', 'COMPLETED', 'Statistics updated, materialized views refreshed');
    
    RAISE NOTICE 'Daily maintenance completed at %', CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;
```

### Weekly Maintenance

```sql
-- Weekly maintenance function
CREATE OR REPLACE FUNCTION performance.weekly_maintenance()
RETURNS void AS $$
BEGIN
    -- Full vacuum on tables with high update activity
    VACUUM ANALYZE staging.k12_enrollment;
    VACUUM ANALYZE staging.source_system_reference_data;
    
    -- Update all table statistics
    ANALYZE;
    
    -- Reindex tables with high fragmentation (if needed)
    -- REINDEX TABLE rds.fact_k12_student_enrollments; -- Only if fragmented
    
    -- Log maintenance completion
    INSERT INTO performance.maintenance_log (maintenance_type, status, notes)
    VALUES ('WEEKLY', 'COMPLETED', 'Full vacuum and reindex completed');
    
    RAISE NOTICE 'Weekly maintenance completed at %', CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;
```

### Monthly Maintenance

```sql
-- Monthly maintenance function
CREATE OR REPLACE FUNCTION performance.monthly_maintenance()
RETURNS void AS $$
BEGIN
    -- Analyze index usage and suggest optimizations
    CREATE TEMP TABLE monthly_index_analysis AS
    SELECT * FROM performance.analyze_index_usage();
    
    -- Check for unused indexes
    RAISE NOTICE 'Unused indexes found:';
    PERFORM * FROM monthly_index_analysis WHERE recommendation = 'UNUSED - Consider dropping';
    
    -- Update extended statistics
    ANALYZE;
    
    -- Log maintenance completion
    INSERT INTO performance.maintenance_log (maintenance_type, status, notes)
    VALUES ('MONTHLY', 'COMPLETED', 'Index analysis and extended statistics update');
    
    RAISE NOTICE 'Monthly maintenance completed at %', CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;
```

### Cron Schedule

```bash
# Add to crontab: crontab -e

# Daily maintenance at 2 AM
0 2 * * * psql -d ceds_data_warehouse_v11_0_0_0 -c "SELECT performance.daily_maintenance();"

# Weekly maintenance on Sunday at 3 AM  
0 3 * * 0 psql -d ceds_data_warehouse_v11_0_0_0 -c "SELECT performance.weekly_maintenance();"

# Monthly maintenance on 1st of month at 4 AM
0 4 1 * * psql -d ceds_data_warehouse_v11_0_0_0 -c "SELECT performance.monthly_maintenance();"

# Performance monitoring every 15 minutes
*/15 * * * * /usr/local/bin/ceds_performance_monitor.sh
```

## Troubleshooting Performance Issues

### Common Performance Problems

#### 1. **Slow Query Diagnosis**

```sql
-- Find current long-running queries
SELECT 
    pid,
    now() - pg_stat_activity.query_start AS duration,
    query,
    state,
    wait_event_type,
    wait_event
FROM pg_stat_activity 
WHERE state = 'active'
AND now() - pg_stat_activity.query_start > interval '30 seconds'
ORDER BY duration DESC;

-- Kill problematic query (if necessary)
-- SELECT pg_terminate_backend(pid);
```

#### 2. **High Memory Usage**

```sql
-- Check memory usage by connection
SELECT 
    pid,
    usename,
    application_name,
    state,
    query,
    CASE 
        WHEN state = 'active' THEN 'ACTIVE'
        WHEN state = 'idle in transaction' THEN 'IDLE_IN_TRANSACTION'
        ELSE state
    END as connection_state
FROM pg_stat_activity
WHERE datname = 'ceds_data_warehouse_v11_0_0_0'
ORDER BY state;
```

#### 3. **Lock Contention**

```sql
-- Find blocking and blocked queries
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid

JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.GRANTED;
```

#### 4. **Table Bloat Analysis**

```sql
-- Check table bloat
SELECT 
    schemaname,
    tablename,
    n_dead_tup,
    n_live_tup,
    ROUND(100.0 * n_dead_tup / GREATEST(n_live_tup + n_dead_tup, 1), 2) as dead_tuple_percent,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as table_size,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname IN ('rds', 'staging', 'ceds')
AND n_dead_tup > 1000
ORDER BY dead_tuple_percent DESC, n_dead_tup DESC;
```

### Performance Recovery Procedures

#### Emergency Response Steps

1. **Immediate Actions**:
   - Identify and terminate problematic queries
   - Check system resources (CPU, memory, disk)
   - Review recent configuration changes

2. **Short-term Fixes**:
   - Increase work_mem for specific sessions
   - Add missing indexes for critical queries
   - Run VACUUM on bloated tables

3. **Long-term Solutions**:
   - Analyze query patterns and optimize
   - Review and adjust PostgreSQL configuration
   - Consider hardware upgrades if needed

## Best Practices

### Performance Best Practices Checklist

#### ✅ **Query Design**
- [ ] Use appropriate indexes for all WHERE clauses
- [ ] Avoid functions on columns in WHERE clauses
- [ ] Use LIMIT for large result sets
- [ ] Consider materialized views for complex aggregations
- [ ] Use EXISTS instead of IN for subqueries
- [ ] Analyze query plans with EXPLAIN ANALYZE

#### ✅ **Index Management**
- [ ] Index all foreign key columns
- [ ] Create composite indexes for multi-column filters
- [ ] Use partial indexes for selective queries
- [ ] Monitor index usage and remove unused indexes
- [ ] Rebuild fragmented indexes periodically
- [ ] Consider index-only scans for covering indexes

#### ✅ **System Configuration**
- [ ] Set shared_buffers to 25% of RAM
- [ ] Configure effective_cache_size to 75% of available RAM
- [ ] Adjust work_mem based on query complexity
- [ ] Optimize WAL settings for workload
- [ ] Use appropriate checkpoint settings
- [ ] Monitor and tune autovacuum

#### ✅ **Maintenance**
- [ ] Run ANALYZE regularly on active tables
- [ ] Monitor table bloat and run VACUUM when needed
- [ ] Update PostgreSQL to latest stable version
- [ ] Monitor disk space and plan for growth
- [ ] Back up performance statistics
- [ ] Document all configuration changes

#### ✅ **Monitoring**
- [ ] Set up automated performance monitoring
- [ ] Track key metrics (cache hit ratio, query times)
- [ ] Monitor system resources continuously
- [ ] Set up alerting for performance issues
- [ ] Review slow query logs regularly
- [ ] Benchmark performance after changes

### Common Pitfalls to Avoid

- **Over-indexing**: Too many indexes slow down INSERT/UPDATE operations
- **Under-vacuuming**: Dead tuples cause table bloat and slow queries
- **Incorrect statistics**: Outdated statistics lead to poor query plans
- **Memory starvation**: Insufficient work_mem causes disk-based operations
- **Lock contention**: Long-running transactions block other operations
- **Configuration drift**: Undocumented changes lead to performance issues

## Conclusion

This performance tuning guide provides a comprehensive framework for optimizing PostgreSQL performance for the CEDS Data Warehouse. Key success factors include:

### 🚀 **Performance Optimization Summary**

✅ **Indexing Strategy**: Comprehensive indexes for all major query patterns  
✅ **Memory Tuning**: Optimized memory allocation for OLAP workloads  
✅ **Storage Optimization**: Proper WAL configuration and tablespace usage  
✅ **Query Optimization**: Efficient query patterns and materialized views  
✅ **Monitoring**: Automated performance monitoring and alerting  
✅ **Maintenance**: Regular maintenance procedures and health checks  

The combination of proper indexing, memory configuration, and ongoing monitoring ensures optimal performance for analytical workloads while maintaining system stability and reliability.