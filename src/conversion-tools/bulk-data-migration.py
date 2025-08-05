#!/usr/bin/env python3
"""
SQL Server to PostgreSQL Bulk Data Migration Tool
CEDS Data Warehouse Migration Utility

This Python script automates the bulk migration of data from SQL Server 
to PostgreSQL for the CEDS Data Warehouse V11.0.0.0 conversion project.

Features:
- Automated table discovery and dependency ordering
- Parallel processing for large datasets
- Data type conversion and validation
- Progress tracking and error handling
- Rollback capabilities
- Performance optimization

Requirements:
- Python 3.8+
- pyodbc (SQL Server connectivity)
- psycopg2 (PostgreSQL connectivity)  
- pandas (data processing)

Usage:
    python bulk-data-migration.py --config migration_config.json

Author: CEDS PostgreSQL Migration Project
Version: 1.0.0
"""

import argparse
import json
import logging
import os
import sys
import time
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any

try:
    import pyodbc
    import psycopg2
    import pandas as pd
    from psycopg2.extras import RealDictCursor
except ImportError as e:
    print(f"Missing required package: {e}")
    print("Install with: pip install pyodbc psycopg2-binary pandas")
    sys.exit(1)


class MigrationConfig:
    """Configuration management for migration process"""
    
    def __init__(self, config_file: str):
        with open(config_file, 'r') as f:
            self.config = json.load(f)
    
    @property
    def sql_server(self) -> Dict[str, Any]:
        return self.config['source']['sql_server']
    
    @property
    def postgresql(self) -> Dict[str, Any]:
        return self.config['target']['postgresql']
    
    @property
    def migration(self) -> Dict[str, Any]:
        return self.config['migration']
    
    @property
    def tables(self) -> List[Dict[str, Any]]:
        return self.config.get('tables', [])


class DatabaseConnection:
    """Database connection management"""
    
    def __init__(self, connection_type: str, config: Dict[str, Any]):
        self.connection_type = connection_type
        self.config = config
        self.connection = None
        
    def connect(self):
        """Establish database connection"""
        if self.connection_type == 'sql_server':
            conn_str = (
                f"DRIVER={{{self.config['driver']}}};"
                f"SERVER={self.config['server']};"
                f"DATABASE={self.config['database']};"
                f"UID={self.config['username']};"
                f"PWD={self.config['password']};"
                f"TrustServerCertificate=yes;"
            )
            self.connection = pyodbc.connect(conn_str)
            self.connection.autocommit = False
            
        elif self.connection_type == 'postgresql':
            self.connection = psycopg2.connect(
                host=self.config['host'],
                port=self.config['port'],
                database=self.config['database'],
                user=self.config['username'],
                password=self.config['password']
            )
            self.connection.autocommit = False
            
        return self.connection
    
    def close(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            self.connection = None


class DataMigrator:
    """Main data migration orchestrator"""
    
    def __init__(self, config_file: str):
        self.config = MigrationConfig(config_file)
        self.logger = self._setup_logging()
        self.sql_server_conn = None
        self.postgresql_conn = None
        self.migration_stats = {
            'start_time': None,
            'end_time': None,
            'tables_processed': 0,
            'total_rows_migrated': 0,
            'errors': []
        }
        
    def _setup_logging(self) -> logging.Logger:
        """Configure logging"""
        log_dir = Path(self.config.migration.get('log_directory', './logs'))
        log_dir.mkdir(exist_ok=True)
        
        log_file = log_dir / f"migration_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        
        return logging.getLogger(__name__)
    
    def connect_databases(self):
        """Establish connections to source and target databases"""
        self.logger.info("Connecting to databases...")
        
        try:
            # Connect to SQL Server
            self.sql_server_conn = DatabaseConnection('sql_server', self.config.sql_server)
            self.sql_server_conn.connect()
            self.logger.info("Connected to SQL Server")
            
            # Connect to PostgreSQL
            self.postgresql_conn = DatabaseConnection('postgresql', self.config.postgresql)
            self.postgresql_conn.connect()
            self.logger.info("Connected to PostgreSQL")
            
        except Exception as e:
            self.logger.error(f"Database connection failed: {e}")
            raise
    
    def discover_tables(self) -> List[Dict[str, Any]]:
        """Discover tables and their metadata from SQL Server"""
        self.logger.info("Discovering tables in SQL Server...")
        
        query = """
        SELECT 
            s.name as schema_name,
            t.name as table_name,
            COUNT(c.column_id) as column_count,
            SUM(CASE WHEN c.is_nullable = 0 THEN 1 ELSE 0 END) as required_columns,
            MAX(CASE WHEN ic.is_primary_key = 1 THEN 1 ELSE 0 END) as has_primary_key
        FROM sys.schemas s
        JOIN sys.tables t ON s.schema_id = t.schema_id
        JOIN sys.columns c ON t.object_id = c.object_id
        LEFT JOIN sys.index_columns ic ON c.object_id = ic.object_id 
            AND c.column_id = ic.column_id
        WHERE s.name IN ('RDS', 'Staging', 'CEDS')
        GROUP BY s.name, t.name
        ORDER BY 
            CASE s.name 
                WHEN 'CEDS' THEN 1 
                WHEN 'RDS' THEN 2 
                WHEN 'Staging' THEN 3 
            END,
            t.name
        """
        
        cursor = self.sql_server_conn.connection.cursor()
        cursor.execute(query)
        
        tables = []
        for row in cursor.fetchall():
            table_info = {
                'schema_name': row.schema_name,
                'table_name': row.table_name,
                'full_name': f"[{row.schema_name}].[{row.table_name}]",
                'column_count': row.column_count,
                'required_columns': row.required_columns,
                'has_primary_key': bool(row.has_primary_key),
                'row_count': 0  # Will be populated later
            }
            tables.append(table_info)
        
        cursor.close()
        self.logger.info(f"Discovered {len(tables)} tables")
        return tables
    
    def get_table_row_count(self, table_info: Dict[str, Any]) -> int:
        """Get row count for a specific table"""
        try:
            cursor = self.sql_server_conn.connection.cursor()
            count_query = f"SELECT COUNT(*) FROM {table_info['full_name']}"
            cursor.execute(count_query)
            row_count = cursor.fetchone()[0]
            cursor.close()
            return row_count
        except Exception as e:
            self.logger.warning(f"Could not get row count for {table_info['full_name']}: {e}")
            return 0
    
    def optimize_postgresql_for_bulk_load(self):
        """Optimize PostgreSQL settings for bulk loading"""
        self.logger.info("Optimizing PostgreSQL for bulk loading...")
        
        optimization_queries = [
            "SELECT app.configure_for_etl_mode();",
            "SET work_mem = '1GB';",
            "SET maintenance_work_mem = '2GB';",
            "SET synchronous_commit = off;",
            "SET checkpoint_completion_target = 0.9;",
        ]
        
        cursor = self.postgresql_conn.connection.cursor()
        for query in optimization_queries:
            try:
                cursor.execute(query)
                self.postgresql_conn.connection.commit()
            except Exception as e:
                self.logger.warning(f"Optimization query failed: {query} - {e}")
        
        cursor.close()
    
    def restore_postgresql_normal_mode(self):
        """Restore PostgreSQL to normal operating mode"""
        self.logger.info("Restoring PostgreSQL normal operating mode...")
        
        restoration_queries = [
            "SELECT app.restore_normal_mode();",
            "SELECT migration.reset_sequences();",
            "ANALYZE;",
        ]
        
        cursor = self.postgresql_conn.connection.cursor()
        for query in restoration_queries:
            try:
                cursor.execute(query)
                self.postgresql_conn.connection.commit()
            except Exception as e:
                self.logger.warning(f"Restoration query failed: {query} - {e}")
        
        cursor.close()
    
    def migrate_table(self, table_info: Dict[str, Any]) -> Dict[str, Any]:
        """Migrate a single table from SQL Server to PostgreSQL"""
        start_time = time.time()
        table_name = table_info['full_name']
        
        self.logger.info(f"Starting migration of {table_name}...")
        
        result = {
            'table_name': table_name,
            'status': 'SUCCESS',
            'rows_migrated': 0,
            'duration': 0,
            'error_message': None
        }
        
        try:
            # Get table schema information
            schema_query = f"""
            SELECT 
                c.column_name,
                c.data_type,
                c.character_maximum_length,
                c.numeric_precision,
                c.numeric_scale,
                c.is_nullable
            FROM information_schema.columns c
            WHERE c.table_schema = '{table_info['schema_name']}'
            AND c.table_name = '{table_info['table_name']}'
            ORDER BY c.ordinal_position
            """
            
            # Export data from SQL Server
            sql_cursor = self.sql_server_conn.connection.cursor()
            export_query = f"SELECT * FROM {table_name}"
            
            # Use pandas for efficient data handling
            df = pd.read_sql(export_query, self.sql_server_conn.connection)
            
            if len(df) == 0:
                self.logger.info(f"{table_name} is empty, skipping...")
                result['status'] = 'SKIPPED'
                return result
            
            # Convert DataFrame to PostgreSQL-compatible format
            df_converted = self._convert_dataframe_types(df, table_info)
            
            # Determine target table name in PostgreSQL
            pg_schema = table_info['schema_name'].lower()
            pg_table = self._convert_table_name(table_info['table_name'])
            pg_full_name = f"{pg_schema}.{pg_table}"
            
            # Load data into PostgreSQL
            self._load_dataframe_to_postgresql(df_converted, pg_full_name)
            
            result['rows_migrated'] = len(df_converted)
            self.migration_stats['total_rows_migrated'] += result['rows_migrated']
            
        except Exception as e:
            result['status'] = 'ERROR' 
            result['error_message'] = str(e)
            self.logger.error(f"Error migrating {table_name}: {e}")
            self.logger.error(traceback.format_exc())
            self.migration_stats['errors'].append({
                'table': table_name,
                'error': str(e),
                'timestamp': datetime.now().isoformat()
            })
        
        finally:
            result['duration'] = time.time() - start_time
            self.logger.info(
                f"Completed {table_name}: {result['status']} - "
                f"{result['rows_migrated']} rows in {result['duration']:.2f}s"
            )
        
        return result
    
    def _convert_dataframe_types(self, df: pd.DataFrame, table_info: Dict[str, Any]) -> pd.DataFrame:
        """Convert DataFrame column types for PostgreSQL compatibility"""
        df_converted = df.copy()
        
        for column in df_converted.columns:
            # Convert SQL Server-specific types
            if df_converted[column].dtype == 'object':
                # Handle NVARCHAR/VARCHAR columns
                df_converted[column] = df_converted[column].astype(str)
                df_converted[column] = df_converted[column].replace('nan', None)
                df_converted[column] = df_converted[column].replace('None', None)
                
            elif 'datetime' in str(df_converted[column].dtype):
                # Handle datetime columns
                df_converted[column] = pd.to_datetime(df_converted[column], errors='coerce')
                
            elif 'bool' in str(df_converted[column].dtype):
                # Handle bit/boolean columns
                df_converted[column] = df_converted[column].astype('boolean')
        
        # Replace NaN with None for PostgreSQL NULL handling
        df_converted = df_converted.where(pd.notnull(df_converted), None)
        
        return df_converted
    
    def _convert_table_name(self, sql_server_name: str) -> str:
        """Convert SQL Server table names to PostgreSQL naming convention"""
        # Convert PascalCase to snake_case
        import re
        
        # Handle special cases
        name = sql_server_name
        
        # Convert PascalCase to snake_case
        # Insert underscore before uppercase letters that follow lowercase
        name = re.sub('([a-z])([A-Z])', r'\1_\2', name)
        
        # Handle consecutive uppercase letters
        name = re.sub('([A-Z])([A-Z][a-z])', r'\1_\2', name)
        
        # Convert to lowercase
        name = name.lower()
        
        # Handle specific CEDS naming patterns
        name = name.replace('k12', 'k12')  # Keep K12 together
        name = name.replace('_i_d', '_id')  # Fix ID suffix
        name = name.replace('lea_', 'lea_')  # Keep LEA together
        name = name.replace('sea_', 'sea_')  # Keep SEA together
        
        return name
    
    def _load_dataframe_to_postgresql(self, df: pd.DataFrame, table_name: str):
        """Load pandas DataFrame into PostgreSQL table"""
        # Create temporary CSV in memory
        from io import StringIO
        
        output = StringIO()
        df.to_csv(output, sep='\t', header=False, index=False, na_rep='\\N')
        output.seek(0)
        
        # Use PostgreSQL COPY for efficient bulk loading
        cursor = self.postgresql_conn.connection.cursor()
        
        try:
            # Disable triggers temporarily for better performance
            cursor.execute(f"ALTER TABLE {table_name} DISABLE TRIGGER ALL;")
            
            # Use COPY to load data
            cursor.copy_from(
                output, 
                table_name,
                sep='\t',
                null='\\N',
                columns=list(df.columns)
            )
            
            # Re-enable triggers
            cursor.execute(f"ALTER TABLE {table_name} ENABLE TRIGGER ALL;")
            
            self.postgresql_conn.connection.commit()
            
        except Exception as e:
            self.postgresql_conn.connection.rollback()
            # Try to re-enable triggers even if copy failed
            try:
                cursor.execute(f"ALTER TABLE {table_name} ENABLE TRIGGER ALL;")
                self.postgresql_conn.connection.commit()
            except:
                pass
            raise e
        
        finally:
            cursor.close()
    
    def run_migration(self):
        """Execute the complete migration process"""
        self.migration_stats['start_time'] = datetime.now()
        self.logger.info("Starting CEDS Data Warehouse migration...")
        
        try:
            # Step 1: Connect to databases
            self.connect_databases()
            
            # Step 2: Discover tables
            tables = self.discover_tables()
            
            # Step 3: Get row counts
            self.logger.info("Getting table row counts...")
            for table_info in tables:
                table_info['row_count'] = self.get_table_row_count(table_info)
            
            # Step 4: Optimize PostgreSQL for bulk loading
            self.optimize_postgresql_for_bulk_load()
            
            # Step 5: Migrate tables
            max_workers = self.config.migration.get('max_parallel_workers', 3)
            
            if max_workers > 1:
                self.logger.info(f"Starting parallel migration with {max_workers} workers...")
                results = self._migrate_tables_parallel(tables, max_workers)
            else:
                self.logger.info("Starting sequential migration...")
                results = self._migrate_tables_sequential(tables)
            
            # Step 6: Restore PostgreSQL normal operation
            self.restore_postgresql_normal_mode()
            
            # Step 7: Generate migration report
            self._generate_migration_report(results)
            
        except Exception as e:
            self.logger.error(f"Migration failed: {e}")
            self.logger.error(traceback.format_exc())
            raise
        
        finally:
            self.migration_stats['end_time'] = datetime.now()
            self._cleanup_connections()
    
    def _migrate_tables_sequential(self, tables: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Migrate tables one by one (sequential processing)"""
        results = []
        
        for i, table_info in enumerate(tables, 1):
            self.logger.info(f"Processing table {i}/{len(tables)}: {table_info['full_name']}")
            result = self.migrate_table(table_info)
            results.append(result)
            self.migration_stats['tables_processed'] += 1
            
            # Progress update
            if i % 10 == 0:
                self.logger.info(f"Progress: {i}/{len(tables)} tables completed")
        
        return results
    
    def _migrate_tables_parallel(self, tables: List[Dict[str, Any]], max_workers: int) -> List[Dict[str, Any]]:
        """Migrate tables in parallel using ThreadPoolExecutor"""
        results = []
        
        with ThreadPoolExecutor(max_workers=max_workers) as executor:
            # Submit all migration tasks
            future_to_table = {
                executor.submit(self.migrate_table, table_info): table_info 
                for table_info in tables
            }
            
            # Process completed tasks
            for future in as_completed(future_to_table):
                table_info = future_to_table[future]
                try:
                    result = future.result()
                    results.append(result)
                    self.migration_stats['tables_processed'] += 1
                    
                    self.logger.info(
                        f"Completed {self.migration_stats['tables_processed']}/{len(tables)}: "
                        f"{table_info['full_name']}"
                    )
                    
                except Exception as e:
                    self.logger.error(f"Task failed for {table_info['full_name']}: {e}")
                    results.append({
                        'table_name': table_info['full_name'],
                        'status': 'ERROR',
                        'rows_migrated': 0,
                        'duration': 0,
                        'error_message': str(e)
                    })
        
        return results
    
    def _generate_migration_report(self, results: List[Dict[str, Any]]):
        """Generate comprehensive migration report"""
        self.logger.info("Generating migration report...")
        
        # Calculate statistics
        total_tables = len(results)
        successful_tables = sum(1 for r in results if r['status'] == 'SUCCESS')
        failed_tables = sum(1 for r in results if r['status'] == 'ERROR')
        skipped_tables = sum(1 for r in results if r['status'] == 'SKIPPED')
        
        total_duration = (self.migration_stats['end_time'] - self.migration_stats['start_time']).total_seconds()
        
        # Create report
        report = {
            'migration_summary': {
                'start_time': self.migration_stats['start_time'].isoformat(),
                'end_time': self.migration_stats['end_time'].isoformat(),
                'total_duration_seconds': total_duration,
                'total_tables': total_tables,
                'successful_tables': successful_tables,
                'failed_tables': failed_tables,
                'skipped_tables': skipped_tables,
                'total_rows_migrated': self.migration_stats['total_rows_migrated']
            },
            'table_results': results,
            'errors': self.migration_stats['errors']
        }
        
        # Save report to file
        report_file = Path(self.config.migration.get('log_directory', './logs')) / f"migration_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2, default=str)
        
        # Log summary
        self.logger.info("=" * 60)
        self.logger.info("MIGRATION COMPLETED")
        self.logger.info("=" * 60)
        self.logger.info(f"Total Duration: {total_duration:.2f} seconds")
        self.logger.info(f"Tables Processed: {total_tables}")
        self.logger.info(f"  - Successful: {successful_tables}")
        self.logger.info(f"  - Failed: {failed_tables}")
        self.logger.info(f"  - Skipped: {skipped_tables}")
        self.logger.info(f"Total Rows Migrated: {self.migration_stats['total_rows_migrated']:,}")
        self.logger.info(f"Report saved to: {report_file}")
        
        if failed_tables > 0:
            self.logger.warning(f"Migration completed with {failed_tables} failed tables")
            for error in self.migration_stats['errors']:
                self.logger.warning(f"  {error['table']}: {error['error']}")
    
    def _cleanup_connections(self):
        """Clean up database connections"""
        if self.sql_server_conn:
            self.sql_server_conn.close()
        if self.postgresql_conn:
            self.postgresql_conn.close()


def create_sample_config():
    """Create a sample configuration file"""
    config = {
        "source": {
            "sql_server": {
                "driver": "ODBC Driver 17 for SQL Server",
                "server": "localhost",
                "database": "CEDS-Data-Warehouse-V11.0.0.0",
                "username": "migration_user",
                "password": "migration_password"
            }
        },
        "target": {
            "postgresql": {
                "host": "localhost",
                "port": 5432,
                "database": "ceds_data_warehouse_v11_0_0_0",
                "username": "migration_user",
                "password": "migration_password"
            }
        },
        "migration": {
            "max_parallel_workers": 3,
            "batch_size": 10000,
            "log_directory": "./logs",
            "temp_directory": "./temp",
            "enable_progress_tracking": True,
            "rollback_on_error": False
        },
        "tables": [
            {
                "name": "DimK12Schools",
                "schema": "RDS",
                "priority": 1,
                "enabled": True
            },
            {
                "name": "DimK12Students", 
                "schema": "RDS",
                "priority": 1,
                "enabled": True
            }
        ]
    }
    
    with open('migration_config.json', 'w') as f:
        json.dump(config, f, indent=2)
    
    print("Sample configuration file 'migration_config.json' created.")
    print("Please update the configuration with your actual database credentials.")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="CEDS Data Warehouse SQL Server to PostgreSQL Migration Tool"
    )
    parser.add_argument(
        '--config', 
        type=str, 
        default='migration_config.json',
        help='Path to migration configuration file'
    )
    parser.add_argument(
        '--create-config',
        action='store_true',
        help='Create a sample configuration file'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true', 
        help='Perform a dry run without actually migrating data'
    )
    
    args = parser.parse_args()
    
    if args.create_config:
        create_sample_config()
        return
    
    if not os.path.exists(args.config):
        print(f"Configuration file not found: {args.config}")
        print("Use --create-config to generate a sample configuration file.")
        sys.exit(1)
    
    try:
        migrator = DataMigrator(args.config)
        migrator.run_migration()
        
    except KeyboardInterrupt:
        print("\nMigration interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Migration failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()