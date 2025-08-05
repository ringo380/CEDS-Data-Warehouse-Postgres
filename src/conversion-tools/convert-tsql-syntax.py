#!/usr/bin/env python3
"""
Small-batch T-SQL to PL/pgSQL Syntax Converter

This lightweight tool converts common T-SQL syntax patterns to PostgreSQL PL/pgSQL
by processing small code snippets and applying focused transformations.

Usage:
    python convert-tsql-syntax.py "T-SQL code snippet"
    python convert-tsql-syntax.py --file input.sql
"""

import re
import argparse

class TSQLSyntaxConverter:
    """Lightweight converter for common T-SQL syntax patterns"""
    
    def __init__(self):
        # Simple find-and-replace patterns (order matters!)
        self.patterns = [
            # Variables
            (r'@(\w+)', r'\1'),  # Remove @ from variables
            
            # String concatenation
            (r"(\w+|\)|'[^']*')\s*\+\s*(\w+|\(|'[^']*')", r'\1 || \2'),
            
            # Functions
            (r'GETDATE\(\)', r'CURRENT_TIMESTAMP'),
            (r'ISNULL\(([^,]+),\s*([^)]+)\)', r'COALESCE(\1, \2)'),
            (r'LEN\(([^)]+)\)', r'LENGTH(\1)'),
            (r'LTRIM\(RTRIM\(([^)]+)\)\)', r'TRIM(\1)'),
            
            # Control flow
            (r'IF\s+(.+?)\s+BEGIN', r'IF \1 THEN'),
            (r'WHILE\s+(.+?)\s+BEGIN', r'WHILE \1 LOOP'),
            (r'\bEND\b(?!\s+IF|LOOP)', r'END IF'),  # Handle END for IF blocks
            
            # Data types
            (r'\bINT\b', r'INTEGER'),
            (r'\bDATETIME\b', r'TIMESTAMP'),
            (r'\bBIT\b', r'BOOLEAN'),
            
            # System functions
            (r'@@ROWCOUNT', r'GET DIAGNOSTICS row_count = ROW_COUNT'),
            
            # Temporary tables
            (r'#(\w+)', r'\1_temp'),
            
            # SELECT assignment
            (r'SELECT\s+(\w+)\s*=\s*(.+?)\s+FROM', r'SELECT \2 INTO \1 FROM'),
        ]
    
    def convert_snippet(self, tsql_code: str) -> str:
        """Convert a small T-SQL code snippet to PL/pgSQL"""
        converted = tsql_code
        
        # Apply patterns sequentially
        for pattern, replacement in self.patterns:
            converted = re.sub(pattern, replacement, converted, flags=re.IGNORECASE)
        
        return converted
    
    def convert_variable_declarations(self, code: str) -> str:
        """Handle DECLARE statements specifically"""
        # Pattern: DECLARE @var1 TYPE1, @var2 TYPE2
        declare_pattern = r'DECLARE\s+([@\w\s,()]+?)(?=\n|$|;)'
        
        def replace_declare(match):
            declarations = match.group(1)
            # Split by comma and process each declaration
            decl_parts = [d.strip() for d in declarations.split(',')]
            pg_declarations = []
            
            for decl in decl_parts:
                # Remove @, handle type conversions
                cleaned = re.sub(r'@(\w+)', r'\1', decl)
                cleaned = re.sub(r'\bINT\b', 'INTEGER', cleaned, flags=re.IGNORECASE)
                cleaned = re.sub(r'\bDATETIME\b', 'TIMESTAMP', cleaned, flags=re.IGNORECASE)
                cleaned = re.sub(r'\bBIT\b', 'BOOLEAN', cleaned, flags=re.IGNORECASE)
                pg_declarations.append(f"    {cleaned};")
            
            return "DECLARE\n" + "\n".join(pg_declarations)
        
        return re.sub(declare_pattern, replace_declare, code, flags=re.IGNORECASE | re.MULTILINE)
    
    def convert_code_block(self, code: str) -> str:
        """Convert a complete code block"""
        # First handle declarations
        converted = self.convert_variable_declarations(code)
        
        # Then apply general patterns
        converted = self.convert_snippet(converted)
        
        # Handle specific control flow endings
        # Convert standalone END to END IF or END LOOP based on context
        lines = converted.split('\n')
        result_lines = []
        control_stack = []
        
        for line in lines:
            line = line.strip()
            if re.search(r'\bIF\b.*\bTHEN\b', line, re.IGNORECASE):
                control_stack.append('IF')
            elif re.search(r'\bWHILE\b.*\bLOOP\b', line, re.IGNORECASE):
                control_stack.append('LOOP')
            elif line.upper() == 'END' and control_stack:
                control_type = control_stack.pop()
                if control_type == 'IF':
                    line = 'END IF;'
                elif control_type == 'LOOP':
                    line = 'END LOOP;'
            
            result_lines.append(line)
        
        return '\n'.join(result_lines)

def main():
    parser = argparse.ArgumentParser(description='Convert T-SQL syntax to PL/pgSQL')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('code', nargs='?', help='T-SQL code snippet to convert')
    group.add_argument('--file', '-f', help='File containing T-SQL code')
    
    args = parser.parse_args()
    
    converter = TSQLSyntaxConverter()
    
    if args.file:
        try:
            with open(args.file, 'r') as f:
                tsql_code = f.read()
        except FileNotFoundError:
            print(f"Error: File '{args.file}' not found")
            return
    else:
        tsql_code = args.code
    
    # Convert the code
    plpgsql_code = converter.convert_code_block(tsql_code)
    
    print("=== Original T-SQL ===")
    print(tsql_code)
    print("\n=== Converted PL/pgSQL ===")
    print(plpgsql_code)

if __name__ == '__main__':
    main()