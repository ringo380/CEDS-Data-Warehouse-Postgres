#!/usr/bin/env python3
"""
SQL Server to PostgreSQL DDL Conversion Tool for CEDS Data Warehouse

This script converts SQL Server table DDL statements to PostgreSQL format,
handling data types, naming conventions, constraints, and indexes.

Usage:
    python convert-table-ddl.py input.sql output.sql
    python convert-table-ddl.py --directory ../CEDS-Data-Warehouse-Project/RDS/Tables/
"""

import re
import sys
import os
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional

class SQLServerToPostgreSQLConverter:
    """Converts SQL Server DDL to PostgreSQL format"""
    
    def __init__(self):
        # Data type mapping
        self.datatype_map = {
            # String types
            r'NVARCHAR\s*\((\d+)\)': r'VARCHAR(\1)',
            r'NVARCHAR\s*\(MAX\)': 'TEXT',
            r'VARCHAR\s*\(MAX\)': 'TEXT',
            r'NCHAR\s*\((\d+)\)': r'CHAR(\1)',
            r'NTEXT': 'TEXT',
            
            # Numeric types
            r'INT\s+IDENTITY\s*\(\s*1\s*,\s*1\s*\)': 'SERIAL',
            r'BIGINT\s+IDENTITY\s*\(\s*1\s*,\s*1\s*\)': 'BIGSERIAL',
            r'SMALLINT\s+IDENTITY\s*\(\s*1\s*,\s*1\s*\)': 'SMALLSERIAL',
            r'INT(?!\s+IDENTITY)': 'INTEGER',
            r'TINYINT': 'SMALLINT',
            r'BIT': 'BOOLEAN',
            r'MONEY': 'DECIMAL(19,4)',
            r'SMALLMONEY': 'DECIMAL(10,4)',
            r'FLOAT(?:\s*\(\d+\))?': 'DOUBLE PRECISION',
            
            # Date/time types
            r'DATETIME2?': 'TIMESTAMP',
            r'SMALLDATETIME': 'TIMESTAMP',
            r'DATETIMEOFFSET': 'TIMESTAMPTZ',
            
            # Other types
            r'UNIQUEIDENTIFIER': 'UUID',
            r'VARBINARY\s*\((?:MAX|\d+)\)': 'BYTEA',
            r'BINARY\s*\(\d+\)': 'BYTEA',
            r'IMAGE': 'BYTEA',
        }
        
        # Schema mapping
        self.schema_map = {
            'RDS': 'rds',
            'Staging': 'staging', 
            'CEDS': 'ceds'
        }
    
    def pascal_to_snake_case(self, name: str) -> str:
        """Convert PascalCase to snake_case"""
        # Handle acronyms and numbers
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
        s2 = re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1)
        return s2.lower()
    
    def convert_column_name(self, name: str) -> str:
        """Convert SQL Server column name to PostgreSQL format"""
        # Remove square brackets
        name = name.strip('[]')
        # Convert to snake_case
        return self.pascal_to_snake_case(name)
    
    def convert_table_name(self, name: str) -> str:
        """Convert SQL Server table name to PostgreSQL format"""
        # Remove square brackets and convert to snake_case
        name = name.strip('[]')
        return self.pascal_to_snake_case(name)
    
    def convert_schema_name(self, name: str) -> str:
        """Convert SQL Server schema name to PostgreSQL format"""
        name = name.strip('[]')
        return self.schema_map.get(name, name.lower())
    
    def convert_data_type(self, datatype: str) -> str:
        """Convert SQL Server data type to PostgreSQL equivalent"""
        datatype = datatype.strip()
        
        # Apply data type mappings
        for pattern, replacement in self.datatype_map.items():
            datatype = re.sub(pattern, replacement, datatype, flags=re.IGNORECASE)
        
        return datatype
    
    def convert_constraint_name(self, name: str) -> str:
        """Convert SQL Server constraint name to PostgreSQL format"""
        name = name.strip('[]')
        # Convert PK_, FK_, DF_ prefixes
        name = re.sub(r'^PK_', 'pk_', name)
        name = re.sub(r'^FK_', 'fk_', name) 
        name = re.sub(r'^DF_', 'df_', name)
        name = re.sub(r'^IX_', 'idx_', name)
        return self.pascal_to_snake_case(name)
    
    def parse_create_table(self, sql: str) -> Dict:
        """Parse CREATE TABLE statement and extract components"""
        result = {
            'schema': None,
            'table_name': None,
            'columns': [],
            'constraints': [],
            'indexes': []
        }
        
        # Extract table name with schema
        table_match = re.search(r'CREATE\s+TABLE\s+(?:\[([^\]]+)\]\.)?\[([^\]]+)\]', sql, re.IGNORECASE)
        if table_match:
            result['schema'] = table_match.group(1) if table_match.group(1) else 'dbo'
            result['table_name'] = table_match.group(2)
        
        # Extract column definitions
        # Find content between parentheses after CREATE TABLE
        table_content_match = re.search(r'CREATE\s+TABLE[^(]+\((.*?)\);', sql, re.DOTALL | re.IGNORECASE)
        if table_content_match:
            content = table_content_match.group(1)
            
            # Split by commas, but handle nested parentheses
            parts = self._split_table_content(content)
            
            for part in parts:
                part = part.strip()
                if part.startswith('CONSTRAINT'):
                    result['constraints'].append(part)
                elif part and not part.startswith('--'):
                    result['columns'].append(part)
        
        # Extract indexes (after the table definition)
        index_pattern = r'CREATE\s+(?:NONCLUSTERED\s+)?INDEX\s+\[([^\]]+)\]\s+ON\s+(?:\[([^\]]+)\]\.)?\[([^\]]+)\]\s*\(([^)]+)\)(?:\s+INCLUDE\s*\(([^)]+)\))?'
        indexes = re.findall(index_pattern, sql, re.IGNORECASE | re.MULTILINE)
        
        for index_match in indexes:
            index_name, schema, table, columns, include_cols = index_match
            result['indexes'].append({
                'name': index_name,
                'columns': columns,
                'include': include_cols
            })
        
        return result
    
    def _split_table_content(self, content: str) -> List[str]:
        """Split table content by commas, respecting nested parentheses"""
        parts = []
        current = ""
        paren_depth = 0
        
        for char in content:
            if char == '(':
                paren_depth += 1
            elif char == ')':
                paren_depth -= 1
            elif char == ',' and paren_depth == 0:
                if current.strip():
                    parts.append(current.strip())
                current = ""
                continue
            
            current += char
        
        if current.strip():
            parts.append(current.strip())
        
        return parts
    
    def convert_column_definition(self, column_def: str) -> str:
        """Convert a single column definition"""
        # Parse column definition: [ColumnName] DATATYPE [NULL|NOT NULL] [DEFAULT ...]
        
        # Extract column name
        name_match = re.match(r'\[([^\]]+)\]', column_def.strip())
        if not name_match:
            return column_def  # Can't parse, return as-is
        
        original_name = name_match.group(1)
        new_name = self.convert_column_name(original_name)
        
        # Remove the original column name from the definition
        remaining = column_def[name_match.end():].strip()
        
        # Convert data type
        datatype_match = re.match(r'([A-Z_]+(?:\s*\([^)]+\))?(?:\s+IDENTITY\s*\([^)]+\))?)', remaining, re.IGNORECASE)
        if datatype_match:
            original_datatype = datatype_match.group(1)
            new_datatype = self.convert_data_type(original_datatype)
            remaining = remaining[datatype_match.end():].strip()
            
            # Handle NULL/NOT NULL
            null_clause = ""
            if remaining.upper().startswith('NOT NULL'):
                null_clause = " NOT NULL"
                remaining = remaining[8:].strip()
            elif remaining.upper().startswith('NULL'):
                # PostgreSQL defaults to NULL, so we can omit it
                remaining = remaining[4:].strip()
            
            # Handle DEFAULT clause
            default_clause = ""
            default_match = re.match(r'(?:CONSTRAINT\s+\[[^\]]+\]\s+)?DEFAULT\s+\(([^)]+)\)', remaining, re.IGNORECASE)
            if default_match:
                default_value = default_match.group(1)
                # Convert (-1) to -1, etc.
                default_value = default_value.strip('()')
                default_clause = f" DEFAULT {default_value}"
                remaining = remaining[default_match.end():].strip()
            
            return f"{new_name} {new_datatype}{null_clause}{default_clause}"
        
        return column_def  # Fallback
    
    def convert_constraint(self, constraint_def: str) -> str:
        """Convert constraint definition"""
        # PRIMARY KEY constraint
        pk_match = re.match(r'CONSTRAINT\s+\[([^\]]+)\]\s+PRIMARY\s+KEY\s+CLUSTERED\s+\(\[([^\]]+)\][^)]*\)', constraint_def, re.IGNORECASE)
        if pk_match:
            constraint_name = self.convert_constraint_name(pk_match.group(1))
            column_name = self.convert_column_name(pk_match.group(2))
            return f"CONSTRAINT {constraint_name} PRIMARY KEY ({column_name})"
        
        # FOREIGN KEY constraint
        fk_match = re.search(r'CONSTRAINT\s+\[([^\]]+)\]\s+FOREIGN\s+KEY\s+\(\[([^\]]+)\]\)\s+REFERENCES\s+(?:\[([^\]]+)\]\.)?\[([^\]]+)\]\s+\(\[([^\]]+)\]\)', constraint_def, re.IGNORECASE)
        if fk_match:
            constraint_name = self.convert_constraint_name(fk_match.group(1))
            column_name = self.convert_column_name(fk_match.group(2))
            ref_schema = self.convert_schema_name(fk_match.group(3)) if fk_match.group(3) else None
            ref_table = self.convert_table_name(fk_match.group(4))
            ref_column = self.convert_column_name(fk_match.group(5))
            
            if ref_schema:
                ref_table = f"{ref_schema}.{ref_table}"
            
            return f"CONSTRAINT {constraint_name} FOREIGN KEY ({column_name}) REFERENCES {ref_table} ({ref_column})"
        
        return constraint_def  # Fallback
    
    def convert_index(self, index_info: Dict) -> str:
        """Convert index definition"""
        index_name = self.convert_constraint_name(index_info['name'])
        
        # Convert column names
        columns = [self.convert_column_name(col.strip().strip('[]')) 
                  for col in index_info['columns'].split(',')]
        
        # Handle INCLUDE columns (PostgreSQL doesn't have INCLUDE, so add to main columns)
        if index_info['include']:
            include_cols = [self.convert_column_name(col.strip().strip('[]')) 
                           for col in index_info['include'].split(',')]
            columns.extend(include_cols)
        
        columns_str = ', '.join(columns)
        return f"CREATE INDEX {index_name} ON {{table_name}} ({columns_str});"
    
    def convert_table_ddl(self, sql: str) -> str:
        """Convert complete CREATE TABLE statement"""
        parsed = self.parse_create_table(sql)
        
        if not parsed['table_name']:
            return sql  # Can't parse, return original
        
        # Convert names
        schema = self.convert_schema_name(parsed['schema'])
        table_name = self.convert_table_name(parsed['table_name'])
        full_table_name = f"{schema}.{table_name}"
        
        # Build PostgreSQL CREATE TABLE
        result = [f"CREATE TABLE {full_table_name} ("]
        
        # Convert columns
        column_lines = []
        for col_def in parsed['columns']:
            converted_col = self.convert_column_definition(col_def)
            column_lines.append(f"    {converted_col}")
        
        # Convert constraints
        for constraint_def in parsed['constraints']:
            converted_constraint = self.convert_constraint(constraint_def)
            column_lines.append(f"    {converted_constraint}")
        
        result.append(',\n'.join(column_lines))
        result.append(");")
        
        # Add indexes
        for index_info in parsed['indexes']:
            index_sql = self.convert_index(index_info)
            index_sql = index_sql.replace('{table_name}', full_table_name)
            result.append(f"\n{index_sql}")
        
        # Add comments
        result.append(f"\nCOMMENT ON TABLE {full_table_name} IS 'Converted from SQL Server table [{parsed['schema']}].[{parsed['table_name']}]';")
        
        return '\n'.join(result)

def convert_file(input_path: Path, output_path: Path):
    """Convert a single SQL file"""
    converter = SQLServerToPostgreSQLConverter()
    
    try:
        with open(input_path, 'r', encoding='utf-8') as f:
            sql_content = f.read()
        
        # Remove GO statements
        sql_content = re.sub(r'^\s*GO\s*$', '', sql_content, flags=re.MULTILINE)
        
        # Convert the DDL
        converted_sql = converter.convert_table_ddl(sql_content)
        
        # Write output
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(converted_sql)
        
        print(f"Converted: {input_path} -> {output_path}")
        
    except Exception as e:
        print(f"Error converting {input_path}: {e}")

def convert_directory(input_dir: Path, output_dir: Path):
    """Convert all SQL files in a directory"""
    output_dir.mkdir(parents=True, exist_ok=True)
    
    for sql_file in input_dir.glob('*.sql'):
        output_file = output_dir / f"{sql_file.stem}-postgresql.sql"
        convert_file(sql_file, output_file)

def main():
    parser = argparse.ArgumentParser(description='Convert SQL Server DDL to PostgreSQL')
    parser.add_argument('input', help='Input SQL file or directory')
    parser.add_argument('output', nargs='?', help='Output SQL file or directory')
    parser.add_argument('--directory', '-d', action='store_true', help='Process directory of files')
    
    args = parser.parse_args()
    
    input_path = Path(args.input)
    
    if args.directory or input_path.is_dir():
        output_path = Path(args.output) if args.output else input_path.parent / f"{input_path.name}-postgresql"
        convert_directory(input_path, output_path)
    else:
        output_path = Path(args.output) if args.output else input_path.with_suffix('.postgresql.sql')
        convert_file(input_path, output_path)

if __name__ == '__main__':
    main()