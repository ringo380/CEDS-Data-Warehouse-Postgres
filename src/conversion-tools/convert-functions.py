#!/usr/bin/env python3
"""
SQL Server to PostgreSQL Function Conversion Tool for CEDS Data Warehouse

This script converts SQL Server scalar functions to PostgreSQL PL/pgSQL functions,
handling T-SQL syntax, data types, and SQL Server-specific functions.

Usage:
    python convert-functions.py input.sql output.sql
    python convert-functions.py --directory ../CEDS-Data-Warehouse-Project/Staging/Functions/
"""

import re
import sys
import os
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional

class TSQLToPlPgSQLConverter:
    """Converts SQL Server T-SQL functions to PostgreSQL PL/pgSQL"""
    
    def __init__(self):
        # T-SQL to PL/pgSQL function mappings
        self.function_map = {
            # Date/Time functions
            r'GETDATE\(\)': 'CURRENT_TIMESTAMP',
            r'CAST\(([^)]+)\s+AS\s+DATE\)': r'(\1)::DATE',
            r'CAST\(([^)]+)\s+AS\s+VARCHAR\((\d+)\)\)': r'(\1)::VARCHAR(\2)',
            r'CAST\(([^)]+)\s+AS\s+VARCHAR\)': r'(\1)::TEXT',
            r'CAST\(([^)]+)\s+AS\s+INT\)': r'(\1)::INTEGER',
            r'CAST\(([^)]+)\s+AS\s+SMALLINT\)': r'(\1)::SMALLINT',
            
            # String functions
            r'ISNULL\(([^,]+),\s*([^)]+)\)': r'COALESCE(\1, \2)',
            r'CONVERT\(VARCHAR\((\d+)\),\s*([^)]+)\)': r'(\2)::VARCHAR(\1)',
            r'CONVERT\(INT,\s*([^)]+)\)': r'(\1)::INTEGER',
            r'CONVERT\(char\((\d+)\),\s*([^,]+),\s*(\d+)\)': r'TO_CHAR(\2, \'YYYYMMDD\')',  # Date format 112
            
            # Data type mappings
            r'@(\w+)': r'\1',  # Remove @ from parameter names
            r'SMALLINT': 'SMALLINT',
            r'VARCHAR\((\d+)\)': r'VARCHAR(\1)',
            r'CHAR\((\d+)\)': r'CHAR(\1)',
            r'INT': 'INTEGER',
            r'DATETIME': 'TIMESTAMP',
            r'BIT': 'BOOLEAN',
        }
        
        # Schema mapping
        self.schema_map = {
            'RDS': 'rds',
            'Staging': 'staging', 
            'CEDS': 'ceds'
        }
    
    def convert_parameter_name(self, param: str) -> str:
        """Convert SQL Server parameter name to PostgreSQL format"""
        # Remove @ prefix and convert to snake_case
        param = param.lstrip('@')
        return self.pascal_to_snake_case(param)
    
    def pascal_to_snake_case(self, name: str) -> str:
        """Convert PascalCase to snake_case"""
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
        s2 = re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1)
        return s2.lower()
    
    def convert_function_name(self, name: str) -> str:
        """Convert SQL Server function name to PostgreSQL format"""
        name = name.strip('[]')
        # Handle underscores in original name
        if '_' in name:
            return name.lower()
        return self.pascal_to_snake_case(name)
    
    def convert_schema_name(self, name: str) -> str:
        """Convert SQL Server schema name to PostgreSQL format"""
        name = name.strip('[]')
        return self.schema_map.get(name, name.lower())
    
    def convert_data_type(self, datatype: str) -> str:
        """Convert SQL Server data type to PostgreSQL equivalent"""
        datatype = datatype.strip()
        
        # Apply data type mappings
        for pattern, replacement in self.function_map.items():
            if pattern in ['SMALLINT', 'INT', 'DATETIME', 'BIT'] and pattern == datatype:
                return replacement
            datatype = re.sub(pattern, replacement, datatype, flags=re.IGNORECASE)
        
        return datatype
    
    def parse_function_signature(self, sql: str) -> Dict:
        """Parse CREATE FUNCTION statement and extract components"""
        result = {
            'schema': None,
            'function_name': None,
            'parameters': [],
            'return_type': None,
            'body': None
        }
        
        # Extract function signature
        func_pattern = r'CREATE\s+FUNCTION\s+(?:(?:\[([^\]]+)\]|(\w+))\.)?(?:\[([^\]]+)\]|(\w+))\s*\(([^)]*)\)\s*RETURNS\s+([A-Z]+(?:\([^)]+\))?)'
        func_match = re.search(func_pattern, sql, re.IGNORECASE | re.DOTALL)
        
        if func_match:
            result['schema'] = func_match.group(1) or func_match.group(2) or 'dbo'
            result['function_name'] = func_match.group(3) or func_match.group(4)
            params_str = func_match.group(5)
            result['return_type'] = func_match.group(6)
            
            # Parse parameters
            if params_str.strip():
                params = [p.strip() for p in params_str.split(',')]
                for param in params:
                    param_match = re.match(r'(@?\w+)\s+([^=]+)(?:\s*=\s*([^,]+))?', param.strip())
                    if param_match:
                        param_name = param_match.group(1)
                        param_type = param_match.group(2).strip()
                        default_val = param_match.group(3).strip() if param_match.group(3) else None
                        result['parameters'].append({
                            'name': param_name,
                            'type': param_type,
                            'default': default_val
                        })
        
        # Extract function body
        body_pattern = r'BEGIN\s*(.*?)\s*END'
        body_match = re.search(body_pattern, sql, re.DOTALL | re.IGNORECASE)
        if body_match:
            result['body'] = body_match.group(1).strip()
        
        return result
    
    def convert_function_body(self, body: str) -> str:
        """Convert T-SQL function body to PL/pgSQL"""
        # Apply function mappings
        converted_body = body
        
        for pattern, replacement in self.function_map.items():
            converted_body = re.sub(pattern, replacement, converted_body, flags=re.IGNORECASE)
        
        # Convert variable declarations
        converted_body = re.sub(r'DECLARE\s+(@\w+)\s+([^\n]+)', 
                               lambda m: f"DECLARE\n    {self.convert_parameter_name(m.group(1))} {self.convert_data_type(m.group(2))};",
                               converted_body, flags=re.IGNORECASE)
        
        # Convert variable assignments in SELECT statements
        converted_body = re.sub(r'SELECT\s+(@\w+)\s*=\s*(.+?)\s+FROM',
                               lambda m: f"SELECT {m.group(2)} INTO {self.convert_parameter_name(m.group(1))} FROM",
                               converted_body, flags=re.IGNORECASE)
        
        # Convert table references (remove square brackets and convert schema)
        converted_body = re.sub(r'(?:dbo\.)?(?:\[([^\]]+)\])\.(?:\[([^\]]+)\])',
                               lambda m: f"{m.group(1).lower()}.{self.pascal_to_snake_case(m.group(2))}",
                               converted_body)
        
        converted_body = re.sub(r'dbo\.(?:\[([^\]]+)\]|(\w+))',
                               lambda m: f"public.{self.pascal_to_snake_case(m.group(1) or m.group(2))}",
                               converted_body)
        
        # Convert column references in square brackets
        converted_body = re.sub(r'\[([^\]]+)\]', 
                               lambda m: self.pascal_to_snake_case(m.group(1)),
                               converted_body)
        
        # Convert RETURN statement
        converted_body = re.sub(r'RETURN\s*\(([^)]+)\)', r'RETURN \1', converted_body, flags=re.IGNORECASE)
        converted_body = re.sub(r'RETURN\s+(.+)', r'RETURN \1', converted_body, flags=re.IGNORECASE)
        
        return converted_body.strip()
    
    def convert_get_age_function(self, parsed: Dict) -> str:
        """Special conversion for the Get_Age function with complex date logic"""
        schema = self.convert_schema_name(parsed['schema'])
        func_name = self.convert_function_name(parsed['function_name'])
        
        # Create PostgreSQL version with better date handling
        return f"""CREATE OR REPLACE FUNCTION {schema}.{func_name}(
    birth_date TIMESTAMP DEFAULT NULL,
    as_of_date TIMESTAMP DEFAULT NULL
) RETURNS INTEGER
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN 
        CASE 
            WHEN birth_date IS NULL THEN -1
            WHEN EXTRACT(YEAR FROM AGE(COALESCE(as_of_date, CURRENT_TIMESTAMP), birth_date)) <= 0 THEN -1
            ELSE EXTRACT(YEAR FROM AGE(COALESCE(as_of_date, CURRENT_TIMESTAMP), birth_date))::INTEGER
        END;
END;
$$;"""
    
    def convert_function(self, sql: str) -> str:
        """Convert complete CREATE FUNCTION statement"""
        parsed = self.parse_function_signature(sql)
        
        if not parsed['function_name']:
            return sql  # Can't parse, return original
        
        # Special handling for Get_Age function
        if parsed['function_name'].lower() in ['get_age']:
            return self.convert_get_age_function(parsed)
        
        # Convert names
        schema = self.convert_schema_name(parsed['schema'])
        func_name = self.convert_function_name(parsed['function_name'])
        return_type = self.convert_data_type(parsed['return_type'])
        
        # Build parameter list
        param_list = []
        for param in parsed['parameters']:
            param_name = self.convert_parameter_name(param['name'])
            param_type = self.convert_data_type(param['type'])
            if param['default']:
                default_val = param['default']
                if default_val.upper() == 'NULL':
                    default_val = 'NULL'
                param_list.append(f"{param_name} {param_type} DEFAULT {default_val}")
            else:
                param_list.append(f"{param_name} {param_type}")
        
        params_str = ',\n    '.join(param_list)
        
        # Convert function body
        body = self.convert_function_body(parsed['body']) if parsed['body'] else 'RETURN NULL;'
        
        # Special fixes for common patterns
        if 'get_fiscal_year_start_date' in func_name:
            body = body.replace('CAST(SchoolYear - 1::TEXT + \'-07-01\' AS DATE)', 
                               '((school_year - 1)::TEXT || \'-07-01\')::DATE')
        elif 'get_fiscal_year_end_date' in func_name:
            body = body.replace('CAST(SchoolYear::TEXT + \'-06-30\' AS DATE)',
                               '(school_year::TEXT || \'-06-30\')::DATE')
        
        # Build PostgreSQL function
        result = f"""CREATE OR REPLACE FUNCTION {schema}.{func_name}(
    {params_str}
) RETURNS {return_type}
LANGUAGE plpgsql
AS $$
BEGIN
    {body}
END;
$$;"""
        
        return result

def convert_function_file(input_path: Path, output_path: Path):
    """Convert a single SQL function file"""
    converter = TSQLToPlPgSQLConverter()
    
    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        # Remove GO statements
        sql_content = re.sub(r'^\s*GO\s*$', '', sql_content, flags=re.MULTILINE)
        
        # Convert the function
        converted_sql = converter.convert_function(sql_content)
        
        # Add header comment
        header = f"""-- Converted from SQL Server function: {input_path.name}
-- Original T-SQL converted to PostgreSQL PL/pgSQL
-- 
"""
        
        # Write output
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(header + converted_sql)
        
        print(f"Converted: {input_path} -> {output_path}")
        
    except Exception as e:
        print(f"Error converting {input_path}: {e}")

def convert_functions_directory(input_dir: Path, output_dir: Path):
    """Convert all function SQL files in a directory"""
    output_dir.mkdir(parents=True, exist_ok=True)
    
    for sql_file in input_dir.glob('*.sql'):
        output_file = output_dir / f"{sql_file.stem}-postgresql.sql"
        convert_function_file(sql_file, output_file)

def main():
    parser = argparse.ArgumentParser(description='Convert SQL Server functions to PostgreSQL')
    parser.add_argument('input', help='Input SQL file or directory')
    parser.add_argument('output', nargs='?', help='Output SQL file or directory')
    parser.add_argument('--directory', '-d', action='store_true', help='Process directory of files')
    
    args = parser.parse_args()
    
    input_path = Path(args.input)
    
    if args.directory or input_path.is_dir():
        output_path = Path(args.output) if args.output else input_path.parent / f"{input_path.name}-postgresql"
        convert_functions_directory(input_path, output_path)
    else:
        output_path = Path(args.output) if args.output else input_path.with_suffix('.postgresql.sql')
        convert_function_file(input_path, output_path)

if __name__ == '__main__':
    main()