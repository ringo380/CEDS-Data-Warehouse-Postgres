#!/usr/bin/env python3
"""
SQL Server to PostgreSQL View Conversion Tool for CEDS Data Warehouse

This script converts SQL Server views to PostgreSQL views,
handling table references, column names, functions, and SQL Server-specific syntax.

Usage:
    python convert-views.py input.sql output.sql
    python convert-views.py --directory ../CEDS-Data-Warehouse-Project/RDS/Views/
"""

import re
import sys
import os
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional

class SQLServerViewToPostgreSQLConverter:
    """Converts SQL Server views to PostgreSQL views"""
    
    def __init__(self):
        # SQL Server to PostgreSQL function mappings
        self.function_map = {
            r'ISNULL\(([^,]+),\s*([^)]+)\)': r'COALESCE(\1, \2)',
            r'CAST\(([^)]+)\s+AS\s+VARCHAR\(MAX\)\)': r'(\1)::TEXT',
            r'CAST\(([^)]+)\s+AS\s+VARCHAR\((\d+)\)\)': r'(\1)::VARCHAR(\2)',
            r'CAST\(([^)]+)\s+AS\s+INT\)': r'(\1)::INTEGER',
            r'LEN\(([^)]+)\)': r'LENGTH(\1)',
            r'UPPER\(([^)]+)\)': r'UPPER(\1)',
            r'LOWER\(([^)]+)\)': r'LOWER(\1)',
        }
        
        # Schema mapping
        self.schema_map = {
            'RDS': 'rds',
            'Staging': 'staging', 
            'CEDS': 'ceds',
            'dbo': 'public'
        }
    
    def pascal_to_snake_case(self, name: str) -> str:
        """Convert PascalCase to snake_case"""
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
        s2 = re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1)
        return s2.lower()
    
    def convert_view_name(self, name: str) -> str:
        """Convert SQL Server view name to PostgreSQL format"""
        name = name.strip('[]')
        # Remove 'vw' prefix and convert to snake_case
        if name.startswith('vw'):
            name = name[2:]
        return self.pascal_to_snake_case(name)
    
    def convert_column_name(self, name: str) -> str:
        """Convert SQL Server column name to PostgreSQL format"""
        name = name.strip('[]')
        return self.pascal_to_snake_case(name)
    
    def convert_schema_name(self, name: str) -> str:
        """Convert SQL Server schema name to PostgreSQL format"""
        name = name.strip('[]')
        return self.schema_map.get(name, name.lower())
    
    def convert_table_reference(self, table_ref: str) -> str:
        """Convert table reference from SQL Server to PostgreSQL format"""
        # Handle schema.table references
        if '.' in table_ref:
            parts = table_ref.split('.')
            if len(parts) == 2:
                schema = self.convert_schema_name(parts[0])
                table = self.pascal_to_snake_case(parts[1].strip('[]'))
                return f"{schema}.{table}"
        
        # Handle single table references (assume dbo schema)
        table = self.pascal_to_snake_case(table_ref.strip('[]'))
        return f"public.{table}"
    
    def convert_column_reference(self, column_ref: str) -> str:
        """Convert column reference, handling table prefixes"""
        # Handle table.column references
        if '.' in column_ref:
            parts = column_ref.split('.')
            if len(parts) == 2:
                # Keep table alias as-is, convert column name
                table_alias = parts[0]
                column = self.convert_column_name(parts[1])
                return f"{table_alias}.{column}"
        
        # Single column reference
        return self.convert_column_name(column_ref)
    
    def parse_view_definition(self, sql: str) -> Dict:
        """Parse CREATE VIEW statement and extract components"""
        result = {
            'schema': None,
            'view_name': None,
            'select_clause': None
        }
        
        # Extract view name with schema
        view_pattern = r'CREATE\s+VIEW\s+(?:(?:\[([^\]]+)\]|(\w+))\.)?(?:\[([^\]]+)\]|(\w+))\s+AS\s+(.*?)(?:GO\s*$|$)'
        view_match = re.search(view_pattern, sql, re.DOTALL | re.IGNORECASE)
        
        if view_match:
            result['schema'] = view_match.group(1) or view_match.group(2) or 'dbo'
            result['view_name'] = view_match.group(3) or view_match.group(4)
            result['select_clause'] = view_match.group(5).strip()
        
        return result
    
    def convert_select_clause(self, select_clause: str) -> str:
        """Convert the SELECT clause of the view"""
        converted = select_clause
        
        # Apply function conversions
        for pattern, replacement in self.function_map.items():
            converted = re.sub(pattern, replacement, converted, flags=re.IGNORECASE)
        
        # Convert table references in FROM and JOIN clauses
        # Pattern for FROM/JOIN table references: FROM/JOIN [schema].[table] alias
        table_ref_pattern = r'(FROM|JOIN)\s+(?:(?:\[([^\]]+)\]|(\w+))\.)?(?:\[([^\]]+)\]|(\w+))(?:\s+(\w+))?'
        def replace_table_ref(match):
            join_type = match.group(1)
            schema = match.group(2) or match.group(3) or 'dbo'
            table = match.group(4) or match.group(5)
            alias = match.group(6) or ''
            
            pg_schema = self.convert_schema_name(schema)
            pg_table = self.pascal_to_snake_case(table)
            
            if alias:
                return f"{join_type} {pg_schema}.{pg_table} {alias}"
            else:
                return f"{join_type} {pg_schema}.{pg_table}"
        
        converted = re.sub(table_ref_pattern, replace_table_ref, converted, flags=re.IGNORECASE)
        
        # Convert column references - be careful with aliases
        # Convert square-bracketed column names
        converted = re.sub(r'\[([^\]]+)\]', 
                          lambda m: self.pascal_to_snake_case(m.group(1)), 
                          converted)
        
        # Convert unquoted PascalCase column names (but preserve SQL keywords and aliases)
        # This is more complex and may need manual review
        
        return converted
    
    def convert_extended_properties_view(self, parsed: Dict) -> str:
        """Special conversion for the CEDS Extended Properties view which uses SQL Server specific functions"""
        schema = self.convert_schema_name(parsed['schema'])
        view_name = self.convert_view_name(parsed['view_name'])
        
        return f"""CREATE OR REPLACE VIEW {schema}.{view_name} AS
-- Note: This view requires manual conversion as it uses SQL Server-specific extended properties
-- PostgreSQL equivalent would use comments and information_schema differently
SELECT 
    c.table_name AS table_name,
    c.column_name AS column_name,
    c.data_type AS data_type,
    c.character_maximum_length AS max_length,
    c.ordinal_position AS column_position,
    NULL::TEXT AS global_id,  -- Extended properties need manual mapping
    NULL::TEXT AS element_technical_name,
    NULL::TEXT AS description,
    NULL::TEXT AS url
FROM information_schema.columns c
INNER JOIN information_schema.tables t ON t.table_name = c.table_name 
WHERE t.table_type = 'BASE TABLE'
    AND t.table_schema = 'rds'

UNION

SELECT 
    t.table_name AS table_name,
    NULL AS column_name,
    NULL AS data_type,
    NULL AS max_length,
    NULL AS column_position,
    NULL::TEXT AS global_id,
    NULL::TEXT AS element_technical_name,
    NULL::TEXT AS description,
    NULL::TEXT AS url
FROM information_schema.tables t 
WHERE t.table_type = 'BASE TABLE'
    AND t.table_schema = 'rds';

-- TODO: Implement PostgreSQL equivalent of extended properties using:
-- 1. Comments on tables/columns: COMMENT ON TABLE/COLUMN
-- 2. Custom metadata tables
-- 3. JSON columns for storing CEDS metadata"""
    
    def convert_view(self, sql: str) -> str:
        """Convert complete CREATE VIEW statement"""
        parsed = self.parse_view_definition(sql)
        
        if not parsed['view_name']:
            return sql  # Can't parse, return original
        
        # Special handling for extended properties view
        if 'extended_properties' in parsed['view_name'].lower():
            return self.convert_extended_properties_view(parsed)
        
        # Convert names
        schema = self.convert_schema_name(parsed['schema'])
        view_name = self.convert_view_name(parsed['view_name'])
        
        # Convert SELECT clause
        select_clause = self.convert_select_clause(parsed['select_clause']) if parsed['select_clause'] else 'SELECT 1'
        
        # Build PostgreSQL view
        result = f"""CREATE OR REPLACE VIEW {schema}.{view_name} AS
{select_clause};"""
        
        return result

def convert_view_file(input_path: Path, output_path: Path):
    """Convert a single SQL view file"""
    converter = SQLServerViewToPostgreSQLConverter()
    
    try:
        with open(input_path, 'r', encoding='utf-8-sig') as f:  # Handle BOM
            sql_content = f.read()
        
        # Remove GO statements
        sql_content = re.sub(r'^\s*GO\s*$', '', sql_content, flags=re.MULTILINE)
        
        # Convert the view
        converted_sql = converter.convert_view(sql_content)
        
        # Add header comment
        header = f"""-- Converted from SQL Server view: {input_path.name}
-- Original SQL Server view converted to PostgreSQL
-- 
"""
        
        # Write output
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(header + converted_sql)
        
        print(f"Converted: {input_path} -> {output_path}")
        
    except Exception as e:
        print(f"Error converting {input_path}: {e}")

def convert_views_directory(input_dir: Path, output_dir: Path):
    """Convert all view SQL files in a directory"""
    output_dir.mkdir(parents=True, exist_ok=True)
    
    for sql_file in input_dir.glob('*.sql'):
        output_file = output_dir / f"{sql_file.stem}-postgresql.sql"
        convert_view_file(sql_file, output_file)

def main():
    parser = argparse.ArgumentParser(description='Convert SQL Server views to PostgreSQL')
    parser.add_argument('input', help='Input SQL file or directory')
    parser.add_argument('output', nargs='?', help='Output SQL file or directory')
    parser.add_argument('--directory', '-d', action='store_true', help='Process directory of files')
    
    args = parser.parse_args()
    
    input_path = Path(args.input)
    
    if args.directory or input_path.is_dir():
        output_path = Path(args.output) if args.output else input_path.parent / f"{input_path.name}-postgresql"
        convert_views_directory(input_path, output_path)
    else:
        output_path = Path(args.output) if args.output else input_path.with_suffix('.postgresql.sql')
        convert_view_file(input_path, output_path)

if __name__ == '__main__':
    main()