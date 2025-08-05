# SQL Server to PostgreSQL Database Settings Migration Guide

## Overview

This guide provides a comprehensive mapping of SQL Server database settings to their PostgreSQL equivalents for the CEDS Data Warehouse migration. It covers configuration differences, recommendations, and implementation details.

## SQL Server vs PostgreSQL Configuration Philosophy

### SQL Server Approach
- Database-level settings control behavior
- Many compatibility modes and legacy options
- Settings applied via `ALTER DATABASE` statements
- Centralized configuration model

### PostgreSQL Approach  
- Cluster and database-level configuration
- ANSI SQL compliant by default
- Settings via `postgresql.conf` and `ALTER DATABASE`
- More granular control with role-based settings

## Comprehensive Settings Mapping

### Core Database Settings

| SQL Server Setting | SQL Server Value | PostgreSQL Equivalent | PostgreSQL Value | Notes |
|-------------------|------------------|----------------------|------------------|-------|
| `COMPATIBILITY_LEVEL` | 150 | Built-in versioning | N/A | PostgreSQL handles version compatibility automatically |
| `ANSI_NULL_DEFAULT` | OFF | Built-in behavior | Always ANSI | PostgreSQL always follows ANSI standards |
| `ANSI_NULLS` | OFF | Built-in behavior | Always ANSI | PostgreSQL always ANSI compliant |
| `ANSI_PADDING` | OFF | Built-in behavior | Always ANSI | PostgreSQL handles padding per ANSI |
| `ANSI_WARNINGS` | OFF | `check_function_bodies` | on/off | Controls validation warnings |
| `ARITHABORT` | OFF | Built-in behavior | N/A | PostgreSQL handles arithmetic errors differently |

### Connection and Session Settings

| SQL Server Setting | SQL Server Value | PostgreSQL Equivalent | PostgreSQL Value | Notes |
|-------------------|------------------|----------------------|------------------|-------|
| `AUTO_CLOSE` | OFF | N/A | N/A | PostgreSQL doesn't auto-close databases |
| `CURSOR_CLOSE_ON_COMMIT` | OFF | `cursor_close_on_commit` | off | Not commonly used in PostgreSQL |
| `CURSOR_DEFAULT` | GLOBAL | N/A | N/A | Different cursor implementation |
| `QUOTED_IDENTIFIER` | OFF | `standard_conforming_strings` | on | Controls string literal handling |

### Maintenance and Statistics

| SQL Server Setting | SQL Server Value | PostgreSQL Equivalent | PostgreSQL Value | Notes |
|-------------------|------------------|----------------------|------------------|-------|
| `AUTO_SHRINK` | OFF | `autovacuum` | on | PostgreSQL uses autovacuum for space management |
| `AUTO_UPDATE_STATISTICS` | ON | `track_counts` | on | Enables statistics collection |
| `AUTO_UPDATE_STATISTICS_ASYNC` | OFF | `autovacuum_naptime` | 60s | Background statistics updates |

### Transaction and Isolation Settings

| SQL Server Setting | SQL Server Value | PostgreSQL Equivalent | PostgreSQL Value | Notes |
|-------------------|------------------|----------------------|------------------|-------|
| `ALLOW_SNAPSHOT_ISOLATION` | OFF | `default_transaction_isolation` | 'read committed' | Transaction isolation level |
| `READ_COMMITTED_SNAPSHOT` | OFF | Built-in MVCC | Always enabled | PostgreSQL uses MVCC by default |
| `RECURSIVE_TRIGGERS` | OFF | Per-trigger setting | N/A | Set individually on triggers |

### Advanced Settings

| SQL Server Setting | SQL Server Value | PostgreSQL Equivalent | PostgreSQL Value | Notes |
|-------------------|------------------|----------------------|------------------|-------|
| `CONCAT_NULL_YIELDS_NULL` | OFF | Built-in behavior | Always ANSI | PostgreSQL follows ANSI standard |
| `NUMERIC_ROUNDABORT` | OFF | Built-in behavior | N/A | Different numeric handling |
| `DATE_CORRELATION_OPTIMIZATION` | OFF | Query planner | Automatic | PostgreSQL optimizer handles this |
| `TRUSTWORTHY` | OFF | Role-based security | N/A | Use PostgreSQL role system |
| `DISABLE_BROKER` | - | External queuing | N/A | Use external message queue systems |

## PostgreSQL-Specific Enhancements

### Settings Not Available in SQL Server

| PostgreSQL Setting | Recommended Value | Purpose |
|-------------------|------------------|---------|
| `shared_buffers` | 25% of RAM | Memory allocation for buffer cache |
| `effective_cache_size` | 75% of RAM | Query planner memory estimate |
| `work_mem` | 32MB | Memory per query operation |
| `maintenance_work_mem` | 256MB | Memory for maintenance operations |
| `random_page_cost` | 1.1 (SSD) / 4.0 (HDD) | Storage type optimization |
| `checkpoint_completion_target` | 0.8 | Checkpoint timing optimization |
| `wal_buffers` | 16MB | Write-ahead logging buffer |
| `max_parallel_workers_per_gather` | 4 | Parallel query workers |

## Implementation Strategy

### Phase 1: Basic Configuration
```sql
-- Essential settings for CEDS Data Warehouse
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET standard_conforming_strings = on;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET default_transaction_isolation = 'read committed';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET timezone = 'UTC';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET track_counts = on;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET autovacuum = on;
```

### Phase 2: Performance Optimization
```sql
-- Memory and performance settings (adjust based on hardware)
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET shared_buffers = '256MB';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET effective_cache_size = '1GB';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET work_mem = '32MB';
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET maintenance_work_mem = '256MB';
```

### Phase 3: Data Warehouse Optimizations
```sql
-- OLAP-specific settings
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET random_page_cost = 1.1;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET seq_page_cost = 1.0;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET max_parallel_workers_per_gather = 4;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET autovacuum_analyze_scale_factor = 0.05;
```

## Configuration Differences and Considerations

### 1. **ANSI Compliance**
- **SQL Server**: Optional ANSI compliance with various OFF settings
- **PostgreSQL**: Always ANSI compliant by design
- **Impact**: More predictable behavior, better standards compliance

### 2. **Transaction Model**
- **SQL Server**: Row versioning optional (snapshot isolation)
- **PostgreSQL**: MVCC (Multi-Version Concurrency Control) built-in
- **Impact**: Better concurrency, no blocking readers

### 3. **Statistics Management**
- **SQL Server**: Automatic statistics with configurable options
- **PostgreSQL**: Autovacuum handles statistics automatically
- **Impact**: Less manual tuning required

### 4. **Memory Management**
- **SQL Server**: Buffer pool managed automatically
- **PostgreSQL**: Explicit shared_buffers configuration required
- **Impact**: More control but requires tuning

### 5. **Maintenance Operations**
- **SQL Server**: AUTO_SHRINK and maintenance plans
- **PostgreSQL**: Autovacuum and explicit VACUUM/ANALYZE
- **Impact**: More predictable maintenance behavior

## Performance Tuning Guidelines

### Memory Configuration

#### For Dedicated PostgreSQL Server
```sql
-- 8GB RAM server example
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET shared_buffers = '2GB';    -- 25% of RAM
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET effective_cache_size = '6GB'; -- 75% of RAM
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET work_mem = '64MB';           -- Adjust based on concurrent queries
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET maintenance_work_mem = '512MB'; -- For VACUUM, CREATE INDEX
```

#### For Shared Server
```sql
-- Shared server with 8GB RAM example  
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET shared_buffers = '1GB';    -- 12.5% of RAM
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET effective_cache_size = '4GB'; -- 50% of RAM
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET work_mem = '32MB';           -- Lower for shared usage
```

### Storage Optimization

#### SSD Storage
```sql
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET random_page_cost = 1.1;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET seq_page_cost = 1.0;
```

#### Traditional HDD Storage
```sql
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET random_page_cost = 4.0;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET seq_page_cost = 1.0;
```

### Data Warehouse Workload Optimization

#### Bulk Loading Optimization
```sql
-- Temporarily optimize for ETL operations
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET synchronous_commit = off;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET checkpoint_completion_target = 0.9;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET wal_buffers = '64MB';
```

#### Query Performance Optimization
```sql
-- Parallel query settings for analytical workloads
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET max_parallel_workers_per_gather = 4;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET max_parallel_workers = 8;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET parallel_tuple_cost = 0.1;
```

## Monitoring and Validation

### Configuration Validation Queries

#### Check Current Settings
```sql
-- View database-specific settings
SELECT 
    setdatabase,
    (SELECT datname FROM pg_database WHERE oid = setdatabase) as database_name,
    setconfig 
FROM pg_db_role_setting 
WHERE setdatabase = (SELECT oid FROM pg_database WHERE datname = 'ceds_data_warehouse_v11_0_0_0');

-- View current active settings
SELECT name, setting, unit, context, short_desc 
FROM pg_settings 
WHERE name IN (
    'shared_buffers', 'effective_cache_size', 'work_mem',
    'maintenance_work_mem', 'random_page_cost', 'seq_page_cost',
    'autovacuum', 'track_counts', 'default_transaction_isolation'
)
ORDER BY name;
```

#### Performance Monitoring
```sql
-- Check buffer cache hit ratio (should be > 95% for good performance)
SELECT 
    schemaname,
    tablename,
    heap_blks_read,
    heap_blks_hit,
    CASE 
        WHEN heap_blks_read + heap_blks_hit = 0 THEN 0
        ELSE round(heap_blks_hit::numeric / (heap_blks_read + heap_blks_hit) * 100, 2)
    END as cache_hit_ratio
FROM pg_statio_user_tables
WHERE schemaname IN ('rds', 'staging', 'ceds')
ORDER BY cache_hit_ratio;
```

### Autovacuum Monitoring
```sql
-- Check autovacuum activity
SELECT 
    schemaname,
    tablename,
    n_tup_ins,
    n_tup_upd, 
    n_tup_del,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname IN ('rds', 'staging', 'ceds')
ORDER BY last_autovacuum DESC NULLS LAST;
```

## Troubleshooting Common Issues

### Issue 1: Poor Query Performance
**Symptoms**: Slow analytical queries, high I/O wait
**Solution**: 
```sql
-- Increase work_mem for complex queries
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET work_mem = '128MB';

-- Enable parallel queries
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET max_parallel_workers_per_gather = 4;

-- Check and adjust random_page_cost for storage type
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET random_page_cost = 1.1; -- For SSD
```

### Issue 2: Memory-Related Errors
**Symptoms**: "out of memory" errors during operations
**Solution**:
```sql
-- Reduce work_mem to prevent memory exhaustion
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET work_mem = '16MB';

-- Increase shared_buffers if system has available RAM
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET shared_buffers = '512MB';
```

### Issue 3: Long-Running Maintenance
**Symptoms**: VACUUM/ANALYZE taking too long
**Solution**:
```sql
-- Increase maintenance_work_mem
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET maintenance_work_mem = '1GB';

-- Adjust autovacuum settings for data warehouse workload
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET autovacuum_vacuum_scale_factor = 0.1;
ALTER DATABASE ceds_data_warehouse_v11_0_0_0 SET autovacuum_analyze_scale_factor = 0.05;
```

## Best Practices Summary

### ✅ **Configuration Best Practices**
1. **Start Conservative**: Begin with recommended defaults and adjust based on workload
2. **Monitor Performance**: Use pg_stat_statements and system monitoring
3. **Test Changes**: Validate configuration changes in non-production environment
4. **Document Settings**: Maintain documentation of custom configurations
5. **Regular Review**: Periodically review and optimize based on usage patterns

### ✅ **Memory Allocation Guidelines**
- **shared_buffers**: 25% of RAM for dedicated server, 15% for shared
- **effective_cache_size**: 75% of available system memory
- **work_mem**: Start with 32MB, adjust based on query complexity and concurrency
- **maintenance_work_mem**: 10% of RAM or 1GB, whichever is smaller

### ✅ **Data Warehouse Specific**
- Optimize for sequential scans and parallel processing
- Configure autovacuum for bulk loading patterns  
- Use appropriate cost parameters for storage type
- Enable query statistics collection for monitoring

### ✅ **Migration Checklist**
- [ ] Apply basic compatibility settings
- [ ] Configure memory parameters based on available RAM
- [ ] Set appropriate cost parameters for storage type
- [ ] Configure autovacuum for data warehouse workload
- [ ] Enable monitoring and statistics collection
- [ ] Test performance with representative workload
- [ ] Document final configuration

This guide provides a complete framework for migrating SQL Server database settings to PostgreSQL while optimizing for the CEDS Data Warehouse workload characteristics.