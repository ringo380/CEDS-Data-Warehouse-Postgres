#!/usr/bin/env python3
"""
ETL Procedure Conversion Tool

This tool converts SQL Server stored procedures used for ETL operations
in the CEDS Data Warehouse to PostgreSQL functions/procedures.

It handles specific patterns common in ETL procedures:
- MERGE statements
- Bulk insert operations  
- Temporary table usage
- Error handling and logging
- Transaction management

Usage:
    python convert-etl-procedures.py --input stored_procedure.sql --output converted_procedure.sql
    python convert-etl-procedures.py --directory input_dir --output-directory output_dir
"""

import re
import argparse
import os
import sys
from pathlib import Path
from typing import Dict, List, Tuple

class ETLProcedureConverter:
    """Converts SQL Server ETL procedures to PostgreSQL"""
    
    def __init__(self):
        self.setup_conversion_patterns()
    
    def setup_conversion_patterns(self):
        """Define conversion patterns specific to ETL procedures"""
        
        # MERGE statement conversion patterns
        self.merge_patterns = [
            # Basic MERGE structure
            (r'MERGE\s+(\w+\.?\w+)\s+AS\s+(\w+)', r'-- MERGE converted to INSERT/UPDATE pattern\n-- Target: \1 AS \2'),
            (r'USING\s+(\w+\.?\w+)\s+AS\s+(\w+)', r'-- Source: \1 AS \2'),
            (r'ON\s+\(([^)]+)\)', r'-- Match condition: \1'),
            (r'WHEN\s+MATCHED\s+THEN\s+UPDATE\s+SET', r'-- UPDATE when matched:'),
            (r'WHEN\s+NOT\s+MATCHED\s+THEN\s+INSERT', r'-- INSERT when not matched:'),
        ]
        
        # Bulk operation patterns
        self.bulk_patterns = [
            (r'INSERT\s+BULK\s+(\w+)', r'COPY \1 FROM STDIN'),
            (r'BULK\s+INSERT\s+(\w+)\s+FROM', r'COPY \1 FROM'),
            (r'WITH\s+\(FIELDTERMINATOR\s*=\s*\'([^\']+)\'\)', r"WITH (FORMAT CSV, DELIMITER '\1')"),
        ]
        
        # Transaction patterns
        self.transaction_patterns = [
            (r'BEGIN\s+TRANSACTION', r'BEGIN;'),
            (r'COMMIT\s+TRANSACTION', r'COMMIT;'),
            (r'ROLLBACK\s+TRANSACTION', r'ROLLBACK;'),
            (r'BEGIN\s+TRAN\b', r'BEGIN;'),
            (r'COMMIT\s+TRAN\b', r'COMMIT;'),
            (r'ROLLBACK\s+TRAN\b', r'ROLLBACK;'),
        ]
        
        # Error handling patterns
        self.error_patterns = [
            (r'BEGIN\s+TRY', r'BEGIN -- TRY block (PostgreSQL uses EXCEPTION handling)'),
            (r'END\s+TRY', r'-- END TRY'),
            (r'BEGIN\s+CATCH', r'EXCEPTION WHEN OTHERS THEN'),
            (r'END\s+CATCH', r'-- END CATCH equivalent'),
            (r'ERROR_MESSAGE\(\)', r'SQLERRM'),
            (r'ERROR_NUMBER\(\)', r'SQLSTATE'),
            (r'RAISERROR\s*\(([^)]+)\)', r'RAISE EXCEPTION USING MESSAGE = \1;'),
        ]
        
        # Logging patterns (CEDS specific)
        self.logging_patterns = [
            (r'INSERT\s+INTO\s+app\.DataMigrationHistories', r'INSERT INTO app.data_migration_histories'),
            (r'DataMigrationHistoryDate', r'data_migration_history_date'),
            (r'DataMigrationTypeId', r'data_migration_type_id'),  
            (r'DataMigrationHistoryMessage', r'data_migration_history_message'),
            (r'GETUTCDATE\(\)', r'CURRENT_TIMESTAMP AT TIME ZONE \'UTC\''),
        ]
        
        # Schema and naming patterns
        self.schema_patterns = [
            (r'\[RDS\]\.', r'rds.'),
            (r'\[Staging\]\.', r'staging.'),
            (r'\[CEDS\]\.', r'ceds.'),
            (r'\[App\]\.', r'app.'),
            (r'\[([^\]]+)\]\.', r'\1.'),  # Generic schema brackets
            (r'\[([^\]]+)\]', r'\1'),     # Generic brackets
        ]
        
        # Table and column naming (PascalCase to snake_case)
        self.naming_patterns = [
            # Common CEDS table name patterns
            (r'\bDimK12Schools\b', r'dim_k12_schools'),
            (r'\bDimK12Students\b', r'dim_k12_students'),
            (r'\bFactK12StudentEnrollments\b', r'fact_k12_student_enrollments'),
            (r'\bK12Enrollment\b', r'k12_enrollment'),
            (r'\bK12Organization\b', r'k12_organization'),
            (r'\bSourceSystemReferenceData\b', r'source_system_reference_data'),
            (r'\bDataMigrationHistories\b', r'data_migration_histories'),
        ]
    
    def convert_merge_statement(self, code: str) -> str:
        """Convert SQL Server MERGE to PostgreSQL UPSERT pattern"""
        
        # Extract MERGE components using regex
        merge_match = re.search(
            r'MERGE\s+(\w+\.?\w+)\s+AS\s+(\w+)\s+USING\s+([^)]+)\s+AS\s+(\w+)\s+ON\s+\(([^)]+)\)\s+WHEN\s+MATCHED.*?WHEN\s+NOT\s+MATCHED.*?;',
            code, re.DOTALL | re.IGNORECASE
        )
        
        if not merge_match:
            return code  # No MERGE found, return unchanged
        
        target_table = merge_match.group(1)
        target_alias = merge_match.group(2)
        source_query = merge_match.group(3)
        source_alias = merge_match.group(4)
        join_condition = merge_match.group(5)
        
        # Convert to PostgreSQL UPSERT (INSERT ... ON CONFLICT)
        upsert_template = f"""
-- Converted MERGE to PostgreSQL UPSERT pattern
INSERT INTO {target_table} (
    -- columns here
)
SELECT 
    -- select columns from source
FROM ({source_query}) AS {source_alias}
ON CONFLICT (-- conflict columns based on: {join_condition})
DO UPDATE SET
    -- update columns here
WHERE -- additional conditions if needed
;
"""
        
        return re.sub(
            r'MERGE\s+.*?;',
            upsert_template,
            code,
            flags=re.DOTALL | re.IGNORECASE
        )
    
    def convert_procedure_signature(self, code: str) -> str:
        """Convert CREATE PROCEDURE to CREATE OR REPLACE FUNCTION"""
        
        # Pattern to match CREATE PROCEDURE
        proc_pattern = r'CREATE\s+PROCEDURE\s+\[?(\w+)\]?\.\[?(\w+)\]?(?:\s*\((.*?)\))?\s+AS\s+BEGIN'
        
        def replace_procedure(match):
            schema = match.group(1).lower() if match.group(1) else 'staging'
            proc_name = self.pascal_to_snake_case(match.group(2))
            parameters = match.group(3) if match.group(3) else ''
            
            # Convert parameters
            pg_params = self.convert_parameters(parameters)
            
            return f"""CREATE OR REPLACE FUNCTION {schema}.{proc_name}({pg_params})
RETURNS void AS $$
BEGIN"""
        
        return re.sub(proc_pattern, replace_procedure, code, flags=re.IGNORECASE | re.DOTALL)
    
    def convert_parameters(self, params: str) -> str:
        """Convert SQL Server parameters to PostgreSQL format"""
        if not params or not params.strip():
            return ''
        
        # Split parameters and convert each
        param_list = []
        for param in params.split(','):
            param = param.strip()
            if param:
                # Remove @ symbol and convert types
                param = re.sub(r'@(\w+)', r'\1', param)
                param = re.sub(r'\bINT\b', 'INTEGER', param, flags=re.IGNORECASE)
                param = re.sub(r'\bDATETIME\b', 'TIMESTAMP', param, flags=re.IGNORECASE)
                param = re.sub(r'\bBIT\b', 'BOOLEAN', param, flags=re.IGNORECASE)
                param = re.sub(r'\bNVARCHAR\b', 'VARCHAR', param, flags=re.IGNORECASE)
                param_list.append(param)
        
        return ', '.join(param_list)
    
    def pascal_to_snake_case(self, name: str) -> str:
        """Convert PascalCase to snake_case"""
        # Handle consecutive uppercase letters
        s1 = re.sub('(.)([A-Z][a-z]+)', r'\1_\2', name)
        return re.sub('([a-z0-9])([A-Z])', r'\1_\2', s1).lower()
    
    def convert_temp_tables(self, code: str) -> str:
        """Convert temporary table usage"""
        
        # Convert temp table creation
        code = re.sub(
            r'CREATE\s+TABLE\s+(#\w+)',
            r'CREATE TEMP TABLE \1_temp',
            code,
            flags=re.IGNORECASE
        )
        
        # Convert temp table references
        code = re.sub(r'#(\w+)', r'\1_temp', code)
        
        # Convert OBJECT_ID checks for temp tables
        code = re.sub(
            r'IF\s+OBJECT_ID\([\'"]tempdb\.\.#(\w+)[\'"]\)\s+IS\s+NOT\s+NULL\s+DROP\s+TABLE\s+#\w+',
            r'DROP TABLE IF EXISTS \1_temp',
            code,
            flags=re.IGNORECASE
        )
        
        return code
    
    def convert_variable_declarations(self, code: str) -> str:
        """Convert variable declarations"""
        
        # Pattern for DECLARE block
        declare_pattern = r'DECLARE\s+((?:@\w+\s+\w+(?:\([^)]*\))?\s*(?:=\s*[^,\n]+)?\s*,?\s*)+)'
        
        def replace_declare(match):
            declarations = match.group(1)
            
            # Split by comma and process each
            vars_list = []
            for decl in re.split(r',(?![^()]*\))', declarations):
                decl = decl.strip()
                if decl:
                    # Convert @var TYPE = value to var TYPE := value
                    decl = re.sub(r'@(\w+)', r'\1', decl)
                    decl = re.sub(r'=', ':=', decl)
                    decl = re.sub(r'\bINT\b', 'INTEGER', decl, flags=re.IGNORECASE)
                    decl = re.sub(r'\bDATETIME\b', 'TIMESTAMP', decl, flags=re.IGNORECASE)
                    decl = re.sub(r'\bBIT\b', 'BOOLEAN', decl, flags=re.IGNORECASE)
                    vars_list.append(f"    {decl};")
            
            return "DECLARE\n" + "\n".join(vars_list)
        
        return re.sub(declare_pattern, replace_declare, code, flags=re.IGNORECASE | re.DOTALL)
    
    def convert_control_flow(self, code: str) -> str:
        """Convert control flow statements"""
        
        # IF...BEGIN...END to IF...THEN...END IF
        code = re.sub(
            r'\bIF\b\s+(.+?)\s+BEGIN\b',
            r'IF \1 THEN',
            code,
            flags=re.IGNORECASE
        )
        
        # WHILE...BEGIN...END to WHILE...LOOP...END LOOP
        code = re.sub(
            r'\bWHILE\b\s+(.+?)\s+BEGIN\b',
            r'WHILE \1 LOOP',
            code,
            flags=re.IGNORECASE
        )
        
        # Convert END statements contextually (simplified)
        lines = code.split('\n')
        result_lines = []
        control_stack = []
        
        for line in lines:
            stripped = line.strip().upper()
            
            if 'IF' in stripped and 'THEN' in stripped:
                control_stack.append('IF')
            elif 'WHILE' in stripped and 'LOOP' in stripped:
                control_stack.append('WHILE')
            elif stripped == 'END' and control_stack:
                control_type = control_stack.pop()
                if control_type == 'IF':
                    line = re.sub(r'\bEND\b', 'END IF;', line, flags=re.IGNORECASE)
                elif control_type == 'WHILE':
                    line = re.sub(r'\bEND\b', 'END LOOP;', line, flags=re.IGNORECASE)
            
            result_lines.append(line)
        
        return '\n'.join(result_lines)
    
    def add_function_footer(self, code: str) -> str:
        """Add PostgreSQL function footer"""
        
        # Replace final END with function footer
        code = re.sub(
            r'\s*END\s*$',
            '\nEND;\n$$ LANGUAGE plpgsql;',
            code.rstrip(),
            flags=re.IGNORECASE
        )
        
        return code
    
    def convert_etl_procedure(self, code: str) -> str:
        """Apply all ETL-specific conversions"""
        
        # Apply conversions in order
        conversions = [
            ('procedure_signature', self.convert_procedure_signature),
            ('variable_declarations', self.convert_variable_declarations),
            ('temp_tables', self.convert_temp_tables),
            ('merge_statements', self.convert_merge_statement),
            ('control_flow', self.convert_control_flow),
        ]
        
        converted = code
        
        for name, converter in conversions:
            try:
                converted = converter(converted)
            except Exception as e:
                print(f"Warning: Error in {name} conversion: {e}")
        
        # Apply pattern replacements
        pattern_groups = [
            self.transaction_patterns,
            self.error_patterns,
            self.logging_patterns,
            self.schema_patterns,
            self.naming_patterns,
            self.bulk_patterns,
        ]
        
        for patterns in pattern_groups:
            for pattern, replacement in patterns:
                converted = re.sub(pattern, replacement, converted, flags=re.IGNORECASE)
        
        # Add function footer
        converted = self.add_function_footer(converted)
        
        return converted

def main():
    """Main conversion function"""
    parser = argparse.ArgumentParser(description='Convert SQL Server ETL procedures to PostgreSQL')
    
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--input', '-i', help='Input SQL Server procedure file')
    group.add_argument('--directory', '-d', help='Input directory containing procedure files')
    
    parser.add_argument('--output', '-o', help='Output file (for single file conversion)')
    parser.add_argument('--output-directory', '-od', help='Output directory (for directory conversion)')
    parser.add_argument('--preview', '-p', action='store_true', help='Preview conversion without writing files')
    
    args = parser.parse_args()
    
    converter = ETLProcedureConverter()
    
    if args.input:
        # Single file conversion
        try:
            with open(args.input, 'r') as f:
                sql_content = f.read()
            
            converted = converter.convert_etl_procedure(sql_content)
            
            if args.preview:
                print("=== CONVERSION PREVIEW ===")
                print(converted)
            elif args.output:
                with open(args.output, 'w') as f:
                    f.write(converted)
                print(f"Converted {args.input} -> {args.output}")
            else:
                print(converted)
                
        except FileNotFoundError:
            print(f"Error: Input file '{args.input}' not found")
            return 1
        except Exception as e:
            print(f"Error: {e}")
            return 1
    
    elif args.directory:
        # Directory conversion
        input_dir = Path(args.directory)
        output_dir = Path(args.output_directory) if args.output_directory else input_dir / 'converted'
        
        if not input_dir.exists():
            print(f"Error: Input directory '{args.directory}' not found")
            return 1
        
        output_dir.mkdir(exist_ok=True)
        
        # Process all .sql files
        converted_count = 0
        for sql_file in input_dir.glob('*.sql'):
            try:
                with open(sql_file, 'r') as f:
                    sql_content = f.read()
                
                converted = converter.convert_etl_procedure(sql_content)
                
                output_file = output_dir / f"{sql_file.stem}-postgresql.sql"
                
                if args.preview:
                    print(f"=== {sql_file.name} PREVIEW ===")
                    print(converted[:500] + '...' if len(converted) > 500 else converted)
                    print()
                else:
                    with open(output_file, 'w') as f:
                        f.write(converted)
                    print(f"Converted {sql_file.name} -> {output_file.name}")
                
                converted_count += 1
                
            except Exception as e:
                print(f"Error converting {sql_file.name}: {e}")
        
        print(f"\nConversion complete: {converted_count} files processed")
    
    return 0

if __name__ == '__main__':
    sys.exit(main())