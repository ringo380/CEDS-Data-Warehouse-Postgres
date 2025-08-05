#!/usr/bin/env python3
"""
Enhanced T-SQL to PL/pgSQL Syntax Converter (Production Version)

This enhanced tool converts T-SQL syntax patterns to PostgreSQL PL/pgSQL
with improved handling of complex patterns, control flow, and system functions.

Usage:
    python convert-tsql-syntax-v2.py "T-SQL code snippet"
    python convert-tsql-syntax-v2.py --file input.sql
    python convert-tsql-syntax-v2.py --file input.sql --output output.sql
"""

import re
import argparse
import sys
from typing import List, Tuple, Dict

class EnhancedTSQLConverter:
    """Enhanced converter for T-SQL to PL/pgSQL with improved pattern handling"""
    
    def __init__(self):
        # System function mappings
        self.system_functions = {
            'GETDATE()': 'CURRENT_TIMESTAMP',
            'GETUTCDATE()': 'CURRENT_TIMESTAMP AT TIME ZONE \'UTC\'',
            '@@ROWCOUNT': 'GET DIAGNOSTICS row_count = ROW_COUNT',
            '@@ERROR': 'SQLSTATE',
            '@@IDENTITY': 'lastval()',
            'SCOPE_IDENTITY()': 'currval(pg_get_serial_sequence(\'table_name\', \'column_name\'))',
            'NEWID()': 'gen_random_uuid()',
        }
        
        # Data type mappings
        self.data_types = {
            r'\bINT\b': 'INTEGER',
            r'\bDATETIME\b': 'TIMESTAMP',
            r'\bDATETIME2\b': 'TIMESTAMP',
            r'\bSMALLDATETIME\b': 'TIMESTAMP',
            r'\bBIT\b': 'BOOLEAN',
            r'\bTINYINT\b': 'SMALLINT',
            r'\bBIGINT\b': 'BIGINT',
            r'\bREAL\b': 'REAL',
            r'\bFLOAT\b': 'DOUBLE PRECISION',
            r'\bMONEY\b': 'DECIMAL(19,4)',
            r'\bSMALLMONEY\b': 'DECIMAL(10,4)',
            r'\bNVARCHAR\b': 'VARCHAR',
            r'\bNCHAR\b': 'CHAR',
            r'\bNTEXT\b': 'TEXT',
            r'\bIMAGE\b': 'BYTEA',
            r'\bVARBINARY\b': 'BYTEA',
            r'\bUNIQUEIDENTIFIER\b': 'UUID',
        }
        
        # String function mappings
        self.string_functions = {
            r'LEN\(([^)]+)\)': r'LENGTH(\1)',
            r'LTRIM\(RTRIM\(([^)]+)\)\)': r'TRIM(\1)',
            r'LTRIM\(([^)]+)\)': r'LTRIM(\1)',
            r'RTRIM\(([^)]+)\)': r'RTRIM(\1)',
            r'CHARINDEX\(([^,]+),\s*([^)]+)\)': r'POSITION(\1 IN \2)',
            r'LEFT\(([^,]+),\s*([^)]+)\)': r'LEFT(\1, \2)',
            r'RIGHT\(([^,]+),\s*([^)]+)\)': r'RIGHT(\1, \2)',
            r'UPPER\(([^)]+)\)': r'UPPER(\1)',
            r'LOWER\(([^)]+)\)': r'LOWER(\1)',
        }
        
        # Date function mappings  
        self.date_functions = {
            r'DATEADD\(day,\s*([^,]+),\s*([^)]+)\)': r'\2 + INTERVAL \'\1 day\'',
            r'DATEADD\(month,\s*([^,]+),\s*([^)]+)\)': r'\2 + INTERVAL \'\1 month\'',
            r'DATEADD\(year,\s*([^,]+),\s*([^)]+)\)': r'\2 + INTERVAL \'\1 year\'',
            r'DATEADD\(hour,\s*([^,]+),\s*([^)]+)\)': r'\2 + INTERVAL \'\1 hour\'',
            r'DATEADD\(minute,\s*([^,]+),\s*([^)]+)\)': r'\2 + INTERVAL \'\1 minute\'',
            r'DATEDIFF\(day,\s*([^,]+),\s*([^)]+)\)': r'(\2::date - \1::date)',
            r'YEAR\(([^)]+)\)': r'EXTRACT(YEAR FROM \1)',
            r'MONTH\(([^)]+)\)': r'EXTRACT(MONTH FROM \1)',
            r'DAY\(([^)]+)\)': r'EXTRACT(DAY FROM \1)',
        }
        
        # CAST/CONVERT mappings
        self.cast_convert_patterns = [
            (r'CONVERT\(VARCHAR\((\d+)\),\s*([^)]+)\)', r'\2::VARCHAR(\1)'),
            (r'CONVERT\(VARCHAR,\s*([^)]+)\)', r'\1::TEXT'),
            (r'CONVERT\(INT,\s*([^)]+)\)', r'\1::INTEGER'),
            (r'CONVERT\(DATETIME,\s*([^)]+)\)', r'\1::TIMESTAMP'),
            (r'CAST\(([^)]+)\s+AS\s+VARCHAR\((\d+)\)\)', r'\1::VARCHAR(\2)'),
            (r'CAST\(([^)]+)\s+AS\s+VARCHAR\)', r'\1::TEXT'),
            (r'CAST\(([^)]+)\s+AS\s+INT\)', r'\1::INTEGER'),
            (r'CAST\(([^)]+)\s+AS\s+DATETIME\)', r'\1::TIMESTAMP'),
        ]
    
    def detect_arithmetic_context(self, code: str, plus_match) -> bool:
        """Detect if + operator is arithmetic or string concatenation"""
        start, end = plus_match.span()
        
        # Look at context around the + operator
        before = code[max(0, start-20):start].strip()
        after = code[end:min(len(code), end+20)].strip()
        
        # If either side has quotes, it's likely string concatenation
        if "'" in before or '"' in before or "'" in after or '"' in after:
            return False
            
        # If either side has string functions, it's string concatenation
        string_indicators = ['CONVERT', 'CAST', 'VARCHAR', 'CHAR', 'TEXT']
        for indicator in string_indicators:
            if indicator in before.upper() or indicator in after.upper():
                return False
        
        # If both sides look numeric, it's arithmetic
        numeric_pattern = r'(\d+|\w+\s*[\+\-\*/]\s*\w+|@\w+)'
        if re.search(numeric_pattern, before) and re.search(numeric_pattern, after):
            return True
            
        # Default to string concatenation for safety
        return False
    
    def convert_string_concatenation(self, code: str) -> str:
        """Convert string concatenation, preserving arithmetic operations"""
        # Find all + operators
        plus_pattern = r'(\w+|\'[^\']*\'|\([^)]+\))\s*\+\s*(\w+|\'[^\']*\'|\([^)]+\))'
        
        def replace_plus(match):
            if self.detect_arithmetic_context(code, match):
                return match.group(0)  # Keep as arithmetic
            else:
                return f"{match.group(1)} || {match.group(2)}"  # Convert to concatenation
        
        return re.sub(plus_pattern, replace_plus, code)
    
    def convert_select_assignment(self, code: str) -> str:
        """Handle complex SELECT assignments with proper INTO syntax"""
        # Pattern 1: SELECT @var = value FROM table
        simple_assignment = r'SELECT\s+@(\w+)\s*=\s*([^,\n]+?)\s+FROM\s+([^\n;]+)'
        code = re.sub(simple_assignment, r'SELECT \2 INTO \1 FROM \3', code, flags=re.IGNORECASE)
        
        # Pattern 2: SELECT @var = (subquery)  
        subquery_assignment = r'SELECT\s+@(\w+)\s*=\s*\(([^)]+)\)'
        def replace_subquery(match):
            var_name = match.group(1)
            subquery = match.group(2)
            # Remove @ from variables in subquery
            subquery = re.sub(r'@(\w+)', r'\1', subquery)
            return f'{var_name} := ({subquery});'
        
        code = re.sub(subquery_assignment, replace_subquery, code, flags=re.IGNORECASE)
        
        # Pattern 3: Multiple assignments in one SELECT
        multi_assignment = r'SELECT\s+(@\w+\s*=\s*[^,]+(?:\s*,\s*@\w+\s*=\s*[^,]+)*)\s+FROM\s+([^\n;]+)'
        def replace_multi(match):
            assignments = match.group(1)
            from_clause = match.group(2)
            
            # Split assignments and convert each
            assign_parts = re.split(r',\s*(?=@\w+\s*=)', assignments)
            into_vars = []
            select_exprs = []
            
            for part in assign_parts:
                assign_match = re.match(r'@(\w+)\s*=\s*(.+)', part.strip())
                if assign_match:
                    var_name = assign_match.group(1)
                    expression = assign_match.group(2)
                    into_vars.append(var_name)
                    select_exprs.append(expression)
            
            if into_vars:
                return f"SELECT {', '.join(select_exprs)} INTO {', '.join(into_vars)} FROM {from_clause}"
            return match.group(0)
        
        code = re.sub(multi_assignment, replace_multi, code, flags=re.IGNORECASE)
        
        return code
    
    def convert_control_flow(self, code: str) -> str:
        """Enhanced control flow conversion with proper BEGIN/END tracking"""
        lines = code.split('\n')
        result_lines = []
        control_stack = []
        
        for line in lines:
            original_line = line
            line = line.strip()
            
            # Track control flow structures
            if re.search(r'\bIF\b.*\bBEGIN\b', line, re.IGNORECASE):
                # IF ... BEGIN pattern
                line = re.sub(r'\bIF\b\s+(.+?)\s+BEGIN\b', r'IF \1 THEN', line, flags=re.IGNORECASE)
                control_stack.append('IF')
            elif re.search(r'\bIF\b', line, re.IGNORECASE) and not re.search(r'\bBEGIN\b', line, re.IGNORECASE):
                # IF without BEGIN (single statement)
                line = re.sub(r'\bIF\b\s+(.+)', r'IF \1 THEN', line, flags=re.IGNORECASE)
                control_stack.append('IF_SIMPLE')
            elif re.search(r'\bWHILE\b.*\bBEGIN\b', line, re.IGNORECASE):
                # WHILE ... BEGIN pattern
                line = re.sub(r'\bWHILE\b\s+(.+?)\s+BEGIN\b', r'WHILE \1 LOOP', line, flags=re.IGNORECASE)
                control_stack.append('WHILE')
            elif re.search(r'\bBEGIN\b', line, re.IGNORECASE) and not any(kw in line.upper() for kw in ['IF', 'WHILE']):
                # Standalone BEGIN
                line = 'BEGIN'
                control_stack.append('BEGIN')
            elif line.upper() == 'END' and control_stack:
                # Handle END based on context
                control_type = control_stack.pop()
                if control_type == 'IF':
                    line = 'END IF;'
                elif control_type == 'WHILE':
                    line = 'END LOOP;'
                elif control_type == 'BEGIN':
                    line = 'END;'
                elif control_type == 'IF_SIMPLE':
                    line = 'END IF;'
            
            # Preserve original indentation
            if line != original_line.strip():
                indentation = original_line[:len(original_line) - len(original_line.lstrip())]
                line = indentation + line
            
            result_lines.append(line)
        
        return '\n'.join(result_lines)
    
    def convert_sql_server_specific(self, code: str) -> str:
        """Convert SQL Server specific syntax"""
        # TOP clause
        code = re.sub(r'\bSELECT\s+TOP\s*\((\d+)\)', r'SELECT', code, flags=re.IGNORECASE)
        code = re.sub(r'\bSELECT\s+TOP\s+(\d+)', r'SELECT', code, flags=re.IGNORECASE)
        code = re.sub(r'\bDELETE\s+TOP\s*\((\d+)\)\s+FROM\s+(\w+)', r'DELETE FROM \2', code, flags=re.IGNORECASE)
        
        # Add LIMIT to SELECT statements that had TOP
        code = re.sub(r'(SELECT[^;]+?)(\s+FROM\s+[^;]+?)(?=\s*;|\s*$)', r'\1\2 LIMIT 1', code, flags=re.IGNORECASE)
        
        # OBJECT_ID function
        code = re.sub(r'OBJECT_ID\(N?[\'"]([^\'"]+)[\'"]\)', r"(SELECT oid FROM pg_class WHERE relname = '\1')", code, flags=re.IGNORECASE)
        
        # Temporary table checks
        code = re.sub(r'IF\s+OBJECT_ID\([^)]+\)\s+IS\s+NOT\s+NULL\s+DROP\s+TABLE\s+(#?\w+)', 
                     r'DROP TABLE IF EXISTS \1_temp', code, flags=re.IGNORECASE)
        
        return code
    
    def convert_variable_declarations(self, code: str) -> str:
        """Enhanced variable declaration handling"""
        # Handle DECLARE with initialization
        declare_pattern = r'DECLARE\s+([@\w\s,()=\d\'"]+?)(?=\n|$|;)'
        
        def replace_declare(match):
            declarations = match.group(1)
            # Split by comma and process each declaration
            decl_parts = []
            current_decl = ""
            paren_count = 0
            
            for char in declarations:
                if char == '(':
                    paren_count += 1
                elif char == ')':
                    paren_count -= 1
                elif char == ',' and paren_count == 0:
                    decl_parts.append(current_decl.strip())
                    current_decl = ""
                    continue
                current_decl += char
            
            if current_decl.strip():
                decl_parts.append(current_decl.strip())
            
            pg_declarations = []
            for decl in decl_parts:
                # Handle initialization: @var TYPE = value
                init_match = re.match(r'@(\w+)\s+([^=]+?)(?:\s*=\s*(.+))?$', decl.strip())
                if init_match:
                    var_name = init_match.group(1)
                    var_type = init_match.group(2).strip()
                    init_value = init_match.group(3)
                    
                    # Convert data type
                    for pattern, replacement in self.data_types.items():
                        var_type = re.sub(pattern, replacement, var_type, flags=re.IGNORECASE)
                    
                    if init_value:
                        pg_declarations.append(f"    {var_name} {var_type} := {init_value.strip()};")
                    else:
                        pg_declarations.append(f"    {var_name} {var_type};")
                else:
                    # Fallback for complex patterns
                    cleaned = re.sub(r'@(\w+)', r'\1', decl)
                    for pattern, replacement in self.data_types.items():
                        cleaned = re.sub(pattern, replacement, cleaned, flags=re.IGNORECASE)
                    pg_declarations.append(f"    {cleaned};")
            
            return "DECLARE\n" + "\n".join(pg_declarations)
        
        return re.sub(declare_pattern, replace_declare, code, flags=re.IGNORECASE | re.MULTILINE)
    
    def convert_code_block(self, code: str) -> str:
        """Convert a complete code block with all enhancements"""
        # 1. Convert variable declarations first
        converted = self.convert_variable_declarations(code)
        
        # 2. Remove @ from variables
        converted = re.sub(r'@(\w+)', r'\1', converted)
        
        # 3. Handle SELECT assignments
        converted = self.convert_select_assignment(converted)
        
        # 4. Convert ISNULL and COALESCE
        converted = re.sub(r'ISNULL\(([^,]+),\s*([^)]+)\)', r'COALESCE(\1, \2)', converted, flags=re.IGNORECASE)
        
        # 5. Convert string concatenation (with arithmetic detection)
        converted = self.convert_string_concatenation(converted)
        
        # 6. Apply system function mappings
        for tsql_func, pg_func in self.system_functions.items():
            converted = re.sub(re.escape(tsql_func), pg_func, converted, flags=re.IGNORECASE)
        
        # 7. Apply string function mappings
        for pattern, replacement in self.string_functions.items():
            converted = re.sub(pattern, replacement, converted, flags=re.IGNORECASE)
        
        # 8. Apply date function mappings
        for pattern, replacement in self.date_functions.items():
            converted = re.sub(pattern, replacement, converted, flags=re.IGNORECASE)
        
        # 9. Apply CAST/CONVERT mappings
        for pattern, replacement in self.cast_convert_patterns:
            converted = re.sub(pattern, replacement, converted, flags=re.IGNORECASE)
        
        # 10. Apply data type mappings
        for pattern, replacement in self.data_types.items():
            converted = re.sub(pattern, replacement, converted, flags=re.IGNORECASE)
        
        # 11. Handle SQL Server specific syntax
        converted = self.convert_sql_server_specific(converted)
        
        # 12. Handle temporary table names
        converted = re.sub(r'#(\w+)', r'\1_temp', converted)
        
        # 13. Convert control flow (must be last to handle processed code)
        converted = self.convert_control_flow(converted)
        
        return converted

def main():
    parser = argparse.ArgumentParser(description='Enhanced T-SQL to PL/pgSQL Converter')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('code', nargs='?', help='T-SQL code snippet to convert')
    group.add_argument('--file', '-f', help='File containing T-SQL code')
    parser.add_argument('--output', '-o', help='Output file (optional)')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    converter = EnhancedTSQLConverter()
    
    if args.file:
        try:
            with open(args.file, 'r') as f:
                tsql_code = f.read()
        except FileNotFoundError:
            print(f"Error: File '{args.file}' not found", file=sys.stderr)
            return 1
        except Exception as e:
            print(f"Error reading file: {e}", file=sys.stderr)
            return 1
    else:
        tsql_code = args.code
    
    # Convert the code
    try:
        plpgsql_code = converter.convert_code_block(tsql_code)
        
        if args.output:
            with open(args.output, 'w') as f:
                f.write(plpgsql_code)
            print(f"Converted code written to '{args.output}'")
        else:
            if args.verbose:
                print("=== Original T-SQL ===")
                print(tsql_code)
                print("\n=== Converted PL/pgSQL ===")
            print(plpgsql_code)
            
    except Exception as e:
        print(f"Conversion error: {e}", file=sys.stderr)
        return 1
    
    return 0

if __name__ == '__main__':
    sys.exit(main())