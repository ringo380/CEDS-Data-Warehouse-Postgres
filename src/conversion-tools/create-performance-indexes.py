#!/usr/bin/env python3
"""
PostgreSQL Performance Index Creation Tool
CEDS Data Warehouse Intelligent Index Generator

This Python script analyzes PostgreSQL query patterns and automatically creates
optimized indexes for the CEDS Data Warehouse. It uses query statistics and
table metadata to suggest and create the most beneficial indexes.

Features:
- Analyzes pg_stat_statements for query patterns
- Identifies missing indexes for common queries
- Creates indexes concurrently to avoid locking
- Monitors index usage and effectiveness
- Provides recommendations for index maintenance

Requirements:
- Python 3.8+
- psycopg2 (PostgreSQL connectivity)
- pandas (data analysis)

Usage:
    python create-performance-indexes.py --config db_config.json --analyze --create

Author: CEDS PostgreSQL Migration Project
Version: 1.0.0
"""

import argparse
import json
import logging
import re
import sys
import time
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Set

try:
    import psycopg2
    import pandas as pd
    from psycopg2.extras import RealDictCursor
except ImportError as e:
    print(f"Missing required package: {e}")
    print("Install with: pip install psycopg2-binary pandas")
    sys.exit(1)

class IndexAnalyzer:
    """Analyzes queries and suggests optimal indexes"""
    
    def __init__(self, connection_config: Dict):
        self.config = connection_config
        self.connection = None
        self.logger = self._setup_logging()
        self.index_suggestions = []
        self.created_indexes = []
        
    def _setup_logging(self) -> logging.Logger:
        """Configure logging"""
        log_dir = Path('./logs')
        log_dir.mkdir(exist_ok=True)
        
        log_file = log_dir / f"index_creation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        
        return logging.getLogger(__name__)
    
    def connect(self):
        """Establish database connection"""
        try:
            self.connection = psycopg2.connect(
                host=self.config['host'],
                port=self.config['port'],
                database=self.config['database'],
                user=self.config['username'],
                password=self.config['password']
            )
            self.connection.autocommit = False
            self.logger.info("Connected to PostgreSQL")
        except Exception as e:
            self.logger.error(f"Database connection failed: {e}")
            raise
    
    def disconnect(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            self.connection = None
    
    def analyze_query_patterns(self) -> List[Dict]:
        """Analyze pg_stat_statements to identify query patterns"""
        self.logger.info("Analyzing query patterns...")
        
        query = """
        SELECT 
            query,
            calls,
            total_time,
            mean_time,
            rows,
            shared_blks_hit,
            shared_blks_read,
            shared_blks_written,
            CASE 
                WHEN shared_blks_hit + shared_blks_read = 0 THEN 0
                ELSE ROUND(100.0 * shared_blks_hit / (shared_blks_hit + shared_blks_read), 2)
            END as cache_hit_ratio
        FROM pg_stat_statements
        WHERE query NOT LIKE '%pg_stat_statements%'
        AND query NOT LIKE '%information_schema%'
        AND query NOT LIKE '%pg_catalog%'
        AND calls > 10
        AND mean_time > 100  -- Focus on queries taking > 100ms
        ORDER BY total_time DESC
        LIMIT 100;
        """
        
        cursor = self.connection.cursor(cursor_factory=RealDictCursor)
        cursor.execute(query)
        query_patterns = cursor.fetchall()
        cursor.close()
        
        self.logger.info(f"Found {len(query_patterns)} significant query patterns")
        return query_patterns
    
    def extract_table_columns_from_query(self, query: str) -> Dict[str, Set[str]]:
        """Extract table names and columns from SQL query"""
        # Normalize query
        query = query.lower().strip()
        
        # Remove comments and extra whitespace
        query = re.sub(r'--.*?\n', ' ', query)
        query = re.sub(r'/\*.*?\*/', ' ', query, flags=re.DOTALL)
        query = re.sub(r'\s+', ' ', query)
        
        table_columns = defaultdict(set)
        
        # Extract FROM clauses
        from_matches = re.finditer(r'\bfrom\s+([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)?)', query)
        for match in from_matches:
            table_name = match.group(1)
            if '.' in table_name:
                schema, table = table_name.split('.', 1)
                if schema in ['rds', 'staging', 'ceds']:
                    table_columns[table_name] = set()
        
        # Extract JOIN clauses
        join_matches = re.finditer(r'\bjoin\s+([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)?)', query)
        for match in join_matches:
            table_name = match.group(1)
            if '.' in table_name:
                schema, table = table_name.split('.', 1)
                if schema in ['rds', 'staging', 'ceds']:
                    table_columns[table_name] = set()
        
        # Extract WHERE conditions
        where_matches = re.finditer(r'\bwhere\s+(.+?)(?:\bgroup\s+by\b|\border\s+by\b|\blimit\b|\bhaving\b|\bunion\b|$)', query)
        for match in where_matches:
            where_clause = match.group(1)
            self._extract_columns_from_conditions(where_clause, table_columns)
        
        # Extract ORDER BY columns
        order_matches = re.finditer(r'\border\s+by\s+([^;\s]+(?:\s*,\s*[^;\s]+)*)', query)
        for match in order_matches:
            order_clause = match.group(1)
            self._extract_columns_from_order_by(order_clause, table_columns)
        
        return dict(table_columns)
    
    def _extract_columns_from_conditions(self, conditions: str, table_columns: Dict):
        """Extract column names from WHERE conditions"""
        # Find column references (table.column or just column)
        column_matches = re.finditer(r'\b([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)?)\s*[=<>!]', conditions)
        for match in column_matches:
            column_ref = match.group(1)
            if '.' in column_ref:
                table_alias, column = column_ref.rsplit('.', 1)
                # Try to match table alias to actual table name
                for table_name in table_columns:
                    if table_name.endswith(table_alias) or table_alias in table_name:
                        table_columns[table_name].add(column)
            else:
                # Add to all tables (will be refined later)
                for table_name in table_columns:
                    table_columns[table_name].add(column_ref)
    
    def _extract_columns_from_order_by(self, order_clause: str, table_columns: Dict):
        """Extract column names from ORDER BY clause"""
        columns = re.findall(r'\b([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)?)', order_clause)
        for column_ref in columns:
            if '.' in column_ref:
                table_alias, column = column_ref.rsplit('.', 1)
                for table_name in table_columns:
                    if table_name.endswith(table_alias) or table_alias in table_name:
                        table_columns[table_name].add(column)
            else:
                for table_name in table_columns:
                    table_columns[table_name].add(column_ref)
    
    def get_table_metadata(self) -> Dict:
        """Get table and column metadata"""
        self.logger.info("Retrieving table metadata...")
        
        query = """
        SELECT 
            t.table_schema,
            t.table_name,
            c.column_name,
            c.data_type,
            c.is_nullable,
            CASE 
                WHEN pk.column_name IS NOT NULL THEN 'PRIMARY KEY'
                WHEN fk.column_name IS NOT NULL THEN 'FOREIGN KEY'
                ELSE 'REGULAR'
            END as column_type,
            pg_stats.n_distinct,
            pg_stats.most_common_vals,
            pg_stats.histogram_bounds
        FROM information_schema.tables t
        JOIN information_schema.columns c ON t.table_name = c.table_name 
            AND t.table_schema = c.table_schema
        LEFT JOIN (
            SELECT kcu.table_schema, kcu.table_name, kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
            WHERE tc.constraint_type = 'PRIMARY KEY'
        ) pk ON c.table_schema = pk.table_schema 
            AND c.table_name = pk.table_name 
            AND c.column_name = pk.column_name
        LEFT JOIN (
            SELECT kcu.table_schema, kcu.table_name, kcu.column_name
            FROM information_schema.table_constraints tc
            JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
            WHERE tc.constraint_type = 'FOREIGN KEY'
        ) fk ON c.table_schema = fk.table_schema 
            AND c.table_name = fk.table_name 
            AND c.column_name = fk.column_name
        LEFT JOIN pg_stats ON pg_stats.schemaname = c.table_schema 
            AND pg_stats.tablename = c.table_name 
            AND pg_stats.attname = c.column_name
        WHERE t.table_schema IN ('rds', 'staging', 'ceds')
        AND t.table_type = 'BASE TABLE'
        ORDER BY t.table_schema, t.table_name, c.ordinal_position;
        """
        
        cursor = self.connection.cursor(cursor_factory=RealDictCursor)
        cursor.execute(query)
        metadata = cursor.fetchall()
        cursor.close()
        
        # Organize metadata by table
        table_metadata = defaultdict(lambda: {'columns': {}, 'primary_keys': [], 'foreign_keys': []})
        
        for row in metadata:
            table_key = f"{row['table_schema']}.{row['table_name']}"
            table_metadata[table_key]['columns'][row['column_name']] = {
                'data_type': row['data_type'],
                'is_nullable': row['is_nullable'],
                'column_type': row['column_type'],
                'n_distinct': row['n_distinct'],
                'selectivity': self._calculate_selectivity(row['n_distinct'])
            }
            
            if row['column_type'] == 'PRIMARY KEY':
                table_metadata[table_key]['primary_keys'].append(row['column_name'])
            elif row['column_type'] == 'FOREIGN KEY':
                table_metadata[table_key]['foreign_keys'].append(row['column_name'])
        
        return dict(table_metadata)
    
    def _calculate_selectivity(self, n_distinct):
        """Calculate column selectivity for index recommendation"""
        if n_distinct is None:
            return 0.5  # Unknown selectivity
        elif n_distinct < 0:
            # Negative values indicate percentage of distinct values
            return abs(n_distinct)
        else:
            # Positive values indicate actual count of distinct values
            # This is a rough estimate - would need row count for exact calculation
            return min(n_distinct / 1000000.0, 1.0)  # Assume 1M rows max
    
    def get_existing_indexes(self) -> Dict:
        """Get existing indexes to avoid duplicates"""
        self.logger.info("Retrieving existing indexes...")
        
        query = """
        SELECT 
            schemaname,
            tablename,
            indexname,
            indexdef
        FROM pg_indexes
        WHERE schemaname IN ('rds', 'staging', 'ceds')
        ORDER BY schemaname, tablename, indexname;
        """
        
        cursor = self.connection.cursor(cursor_factory=RealDictCursor)
        cursor.execute(query)
        indexes = cursor.fetchall()
        cursor.close()
        
        # Organize by table
        existing_indexes = defaultdict(list)
        for idx in indexes:
            table_key = f"{idx['schemaname']}.{idx['tablename']}"
            existing_indexes[table_key].append({
                'name': idx['indexname'],
                'definition': idx['indexdef']
            })
        
        return dict(existing_indexes)
    
    def generate_index_suggestions(self) -> List[Dict]:
        """Generate intelligent index suggestions based on query analysis"""
        self.logger.info("Generating index suggestions...")
        
        # Get data needed for analysis
        query_patterns = self.analyze_query_patterns()
        table_metadata = self.get_table_metadata()
        existing_indexes = self.get_existing_indexes()
        
        suggestions = []
        column_usage = defaultdict(int)  # Track column usage frequency
        
        # Analyze each query pattern
        for query_data in query_patterns:
            query = query_data['query']
            weight = query_data['calls'] * query_data['mean_time']  # Weight by impact
            
            # Extract table and column information
            table_columns = self.extract_table_columns_from_query(query)
            
            # Track column usage
            for table, columns in table_columns.items():
                for column in columns:
                    column_usage[f"{table}.{column}"] += weight
        
        # Generate suggestions based on usage patterns
        for column_key, usage_weight in sorted(column_usage.items(), key=lambda x: x[1], reverse=True):
            table, column = column_key.rsplit('.', 1)
            
            if table not in table_metadata:
                continue
                
            # Check if column exists and get its properties
            if column not in table_metadata[table]['columns']:
                continue
                
            column_info = table_metadata[table]['columns'][column]
            
            # Skip if already indexed (primary key or has existing index)
            if column in table_metadata[table]['primary_keys']:
                continue
                
            if self._column_already_indexed(table, column, existing_indexes):
                continue
            
            # Generate suggestion based on column properties
            suggestion = self._create_index_suggestion(
                table, column, column_info, usage_weight, existing_indexes
            )
            
            if suggestion:
                suggestions.append(suggestion)
        
        # Add foreign key index suggestions
        fk_suggestions = self._generate_foreign_key_indexes(table_metadata, existing_indexes)
        suggestions.extend(fk_suggestions)
        
        # Add composite index suggestions for common patterns
        composite_suggestions = self._generate_composite_indexes(query_patterns, table_metadata, existing_indexes)
        suggestions.extend(composite_suggestions)
        
        # Sort by priority and limit results
        suggestions.sort(key=lambda x: x['priority_score'], reverse=True)
        return suggestions[:50]  # Top 50 suggestions
    
    def _column_already_indexed(self, table: str, column: str, existing_indexes: Dict) -> bool:
        """Check if column is already indexed"""
        if table not in existing_indexes:
            return False
            
        for index in existing_indexes[table]:
            # Simple check - could be more sophisticated
            if column in index['definition'].lower():
                return True
        return False
    
    def _create_index_suggestion(self, table: str, column: str, column_info: Dict, 
                               usage_weight: float, existing_indexes: Dict) -> Optional[Dict]:
        """Create an index suggestion for a single column"""
        # Calculate priority based on various factors
        priority_score = usage_weight
        
        # Boost foreign keys
        if column_info['column_type'] == 'FOREIGN KEY':
            priority_score *= 2.0
        
        # Boost high-selectivity columns
        if column_info['selectivity'] > 0.1:
            priority_score *= 1.5
        
        # Reduce priority for very low selectivity
        if column_info['selectivity'] < 0.01:
            priority_score *= 0.5
        
        schema, table_name = table.split('.', 1)
        index_name = f"idx_{table_name}_{column}"
        
        return {
            'type': 'single_column',
            'table': table,
            'columns': [column],
            'index_name': index_name,
            'sql': f"CREATE INDEX CONCURRENTLY {index_name} ON {table} ({column});",
            'priority_score': priority_score,
            'reasoning': f"Column used frequently in queries (weight: {usage_weight:.0f}), selectivity: {column_info['selectivity']:.3f}",
            'estimated_benefit': 'HIGH' if priority_score > 1000000 else 'MEDIUM' if priority_score > 100000 else 'LOW'
        }
    
    def _generate_foreign_key_indexes(self, table_metadata: Dict, existing_indexes: Dict) -> List[Dict]:
        """Generate indexes for all foreign key columns"""
        suggestions = []
        
        for table, metadata in table_metadata.items():
            for fk_column in metadata['foreign_keys']:
                if not self._column_already_indexed(table, fk_column, existing_indexes):
                    schema, table_name = table.split('.', 1)
                    index_name = f"idx_{table_name}_{fk_column}"
                    
                    suggestions.append({
                        'type': 'foreign_key',
                        'table': table,
                        'columns': [fk_column],
                        'index_name': index_name,
                        'sql': f"CREATE INDEX CONCURRENTLY {index_name} ON {table} ({fk_column});",
                        'priority_score': 1000000,  # High priority for FK indexes
                        'reasoning': f"Foreign key column needs index for join performance",
                        'estimated_benefit': 'HIGH'
                    })
        
        return suggestions
    
    def _generate_composite_indexes(self, query_patterns: List, table_metadata: Dict, 
                                  existing_indexes: Dict) -> List[Dict]:
        """Generate composite index suggestions for common multi-column patterns"""
        suggestions = []
        
        # Common CEDS patterns
        common_patterns = [
            {
                'table': 'rds.fact_k12_student_enrollments',
                'columns': ['school_year_id', 'dim_k12_school_id'],
                'reasoning': 'Common pattern: filtering by year and school'
            },
            {
                'table': 'rds.fact_k12_student_enrollments', 
                'columns': ['school_year_id', 'dim_grade_level_id'],
                'reasoning': 'Common pattern: filtering by year and grade'
            },
            {
                'table': 'rds.fact_k12_student_enrollments',
                'columns': ['dim_lea_id', 'school_year_id'],
                'reasoning': 'Common pattern: LEA reports by year'
            },
            {
                'table': 'staging.k12_enrollment',
                'columns': ['school_year', 'student_identifier_state'],
                'reasoning': 'ETL pattern: student lookup by year'
            },
            {
                'table': 'staging.k12_enrollment',
                'columns': ['school_identifier_state', 'school_year'],
                'reasoning': 'ETL pattern: school enrollment by year'
            }
        ]
        
        for pattern in common_patterns:
            table = pattern['table']
            columns = pattern['columns']
            
            # Check if table exists and all columns exist
            if table not in table_metadata:
                continue
                
            if not all(col in table_metadata[table]['columns'] for col in columns):
                continue
            
            # Check if similar composite index already exists
            if self._composite_index_exists(table, columns, existing_indexes):
                continue
            
            schema, table_name = table.split('.', 1)
            index_name = f"idx_{table_name}_{'_'.join(columns)}"
            column_list = ', '.join(columns)
            
            suggestions.append({
                'type': 'composite',
                'table': table,
                'columns': columns,
                'index_name': index_name,
                'sql': f"CREATE INDEX CONCURRENTLY {index_name} ON {table} ({column_list});",
                'priority_score': 500000,  # Medium-high priority
                'reasoning': pattern['reasoning'],
                'estimated_benefit': 'MEDIUM'
            })
        
        return suggestions
    
    def _composite_index_exists(self, table: str, columns: List[str], existing_indexes: Dict) -> bool:
        """Check if a similar composite index already exists"""
        if table not in existing_indexes:
            return False
            
        column_set = set(columns)
        for index in existing_indexes[table]:
            # Extract columns from index definition (simplified)
            index_def = index['definition'].lower()
            # This is a simple check - could be more sophisticated
            if all(col.lower() in index_def for col in columns):
                return True
        return False
    
    def create_indexes(self, suggestions: List[Dict], max_indexes: int = 20) -> List[Dict]:
        """Create suggested indexes"""
        self.logger.info(f"Creating up to {max_indexes} indexes...")
        
        created = []
        for i, suggestion in enumerate(suggestions[:max_indexes]):
            if self._create_single_index(suggestion):
                created.append(suggestion)
                self.logger.info(f"Created index {i+1}/{max_indexes}: {suggestion['index_name']}")
            else:
                self.logger.warning(f"Failed to create index: {suggestion['index_name']}")
        
        return created
    
    def _create_single_index(self, suggestion: Dict) -> bool:
        """Create a single index with error handling"""
        try:
            cursor = self.connection.cursor()
            
            # Check if index already exists
            check_query = """
            SELECT 1 FROM pg_indexes 
            WHERE indexname = %s;
            """
            cursor.execute(check_query, (suggestion['index_name'],))
            if cursor.fetchone():
                self.logger.info(f"Index {suggestion['index_name']} already exists, skipping")
                cursor.close()
                return True
            
            # Create index
            self.logger.info(f"Creating index: {suggestion['sql']}")
            cursor.execute(suggestion['sql'])
            self.connection.commit()
            cursor.close()
            
            return True
            
        except Exception as e:
            self.logger.error(f"Failed to create index {suggestion['index_name']}: {e}")
            self.connection.rollback()
            return False
    
    def analyze_index_effectiveness(self) -> pd.DataFrame:
        """Analyze the effectiveness of existing indexes"""
        self.logger.info("Analyzing index effectiveness...")
        
        query = """
        SELECT 
            schemaname,
            tablename,
            indexname,
            idx_scan as scans,
            idx_tup_read as tuples_read,
            idx_tup_fetch as tuples_fetched,
            pg_size_pretty(pg_relation_size(indexrelid)) as size,
            CASE 
                WHEN idx_scan = 0 THEN 'UNUSED'
                WHEN idx_scan < 100 THEN 'LOW_USAGE'
                WHEN idx_tup_fetch::float / NULLIF(idx_tup_read, 0) < 0.1 THEN 'LOW_SELECTIVITY'
                ELSE 'GOOD'
            END as status,
            CASE 
                WHEN idx_scan = 0 THEN 'Consider dropping this unused index'
                WHEN idx_scan < 100 THEN 'Low usage - monitor for potential removal'
                WHEN idx_tup_fetch::float / NULLIF(idx_tup_read, 0) < 0.1 THEN 'Low selectivity - review necessity'
                ELSE 'Index performing well'
            END as recommendation
        FROM pg_stat_user_indexes
        WHERE schemaname IN ('rds', 'staging', 'ceds')
        ORDER BY 
            CASE 
                WHEN idx_scan = 0 THEN 1
                WHEN idx_scan < 100 THEN 2
                ELSE 3
            END,
            idx_scan DESC;
        """
        
        return pd.read_sql(query, self.connection)
    
    def generate_report(self, suggestions: List[Dict], created_indexes: List[Dict]) -> str:
        """Generate a comprehensive report"""
        report_lines = [
            "=" * 80,
            "PostgreSQL Index Analysis and Creation Report",
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "=" * 80,
            "",
            f"Total Index Suggestions Generated: {len(suggestions)}",
            f"Indexes Successfully Created: {len(created_indexes)}",
            "",
        ]
        
        if suggestions:
            report_lines.extend([
                "TOP INDEX SUGGESTIONS:",
                "-" * 40,
            ])
            
            for i, suggestion in enumerate(suggestions[:10], 1):
                report_lines.extend([
                    f"{i}. {suggestion['index_name']} ({suggestion['estimated_benefit']} benefit)",
                    f"   Table: {suggestion['table']}",
                    f"   Columns: {', '.join(suggestion['columns'])}",
                    f"   Type: {suggestion['type']}",
                    f"   Reasoning: {suggestion['reasoning']}",
                    f"   SQL: {suggestion['sql']}",
                    ""
                ])
        
        if created_indexes:
            report_lines.extend([
                "INDEXES CREATED:",
                "-" * 20,
            ])
            
            for idx in created_indexes:
                report_lines.extend([
                    f"✓ {idx['index_name']} - {idx['estimated_benefit']} benefit expected",
                    f"  {idx['sql']}",
                    ""
                ])
        
        # Add index effectiveness analysis
        try:
            effectiveness_df = self.analyze_index_effectiveness()
            report_lines.extend([
                "INDEX EFFECTIVENESS ANALYSIS:",
                "-" * 35,
            ])
            
            unused_indexes = effectiveness_df[effectiveness_df['status'] == 'UNUSED']
            if not unused_indexes.empty:
                report_lines.extend([
                    f"⚠️  UNUSED INDEXES ({len(unused_indexes)} found):",
                ])
                for _, row in unused_indexes.head(10).iterrows():
                    report_lines.append(f"   - {row['schemaname']}.{row['indexname']} ({row['size']})")
                report_lines.append("")
            
            low_usage = effectiveness_df[effectiveness_df['status'] == 'LOW_USAGE']
            if not low_usage.empty:
                report_lines.extend([
                    f"⚠️  LOW USAGE INDEXES ({len(low_usage)} found):",
                ])
                for _, row in low_usage.head(5).iterrows():
                    report_lines.append(f"   - {row['schemaname']}.{row['indexname']} ({row['scans']} scans)")
                report_lines.append("")
                
        except Exception as e:
            report_lines.extend([
                "INDEX EFFECTIVENESS ANALYSIS: Failed",
                f"Error: {e}",
                ""
            ])
        
        report_lines.extend([
            "RECOMMENDATIONS:",
            "-" * 20,
            "1. Monitor new index usage after creation",
            "2. Consider removing unused indexes to improve DML performance", 
            "3. Re-run this analysis monthly to identify new optimization opportunities",
            "4. Update table statistics with ANALYZE after creating indexes",
            "",
            "=" * 80
        ])
        
        return "\n".join(report_lines)

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="PostgreSQL Performance Index Creation Tool for CEDS Data Warehouse"
    )
    parser.add_argument(
        '--config',
        type=str,
        default='db_config.json',
        help='Database configuration file'
    )
    parser.add_argument(
        '--analyze',
        action='store_true',
        help='Analyze queries and generate index suggestions'
    )
    parser.add_argument(
        '--create',
        action='store_true',
        help='Create suggested indexes'
    )
    parser.add_argument(
        '--max-indexes',
        type=int,
        default=20,
        help='Maximum number of indexes to create'
    )
    parser.add_argument(
        '--report-only',
        action='store_true',
        help='Generate report without creating indexes'
    )
    
    args = parser.parse_args()
    
    # Load configuration
    try:
        with open(args.config, 'r') as f:
            config = json.load(f)
    except FileNotFoundError:
        print(f"Configuration file not found: {args.config}")
        print("Create a configuration file with database connection details.")
        sys.exit(1)
    
    # Create analyzer
    analyzer = IndexAnalyzer(config)
    
    try:
        # Connect to database
        analyzer.connect()
        
        suggestions = []
        created_indexes = []
        
        if args.analyze or args.report_only:
            # Generate suggestions
            suggestions = analyzer.generate_index_suggestions()
            print(f"Generated {len(suggestions)} index suggestions")
        
        if args.create and not args.report_only:
            # Create indexes
            if not suggestions:
                suggestions = analyzer.generate_index_suggestions()
            
            created_indexes = analyzer.create_indexes(suggestions, args.max_indexes)
            print(f"Successfully created {len(created_indexes)} indexes")
        
        # Generate and save report
        report = analyzer.generate_report(suggestions, created_indexes)
        
        # Save report to file
        report_file = Path(f"index_analysis_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
        with open(report_file, 'w') as f:
            f.write(report)
        
        print(f"\nReport saved to: {report_file}")
        print("\n" + report)
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
    finally:
        analyzer.disconnect()

if __name__ == "__main__":
    main()