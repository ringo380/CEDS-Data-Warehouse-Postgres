#!/usr/bin/env python3
"""
Comprehensive Test Suite for T-SQL to PL/pgSQL Conversion Tool

This test suite validates the conversion tool against known patterns
and provides regression testing for the enhancement process.
"""

import os
import sys
import subprocess
from typing import List, Tuple

class ConversionTest:
    def __init__(self, name: str, input_sql: str, expected_output: str, category: str = "general"):
        self.name = name
        self.input_sql = input_sql
        self.expected_output = expected_output
        self.category = category

def run_converter(input_sql: str, converter_path: str = "convert-tsql-syntax-v2.py") -> str:
    """Run the conversion tool and return output"""
    try:
        result = subprocess.run([
            'python', converter_path, '--test', input_sql
        ], capture_output=True, text=True, cwd=os.path.dirname(__file__))
        return result.stdout.strip()
    except Exception as e:
        return f"ERROR: {e}"

def create_test_cases() -> List[ConversionTest]:
    """Define comprehensive test cases"""
    tests = []
    
    # Variable Declaration Tests
    tests.append(ConversionTest(
        "Simple Variable Declaration",
        "DECLARE @var INT",
        "DECLARE\n    var INTEGER;",
        "variables"
    ))
    
    tests.append(ConversionTest(
        "Variable Declaration with Initialization",
        "DECLARE @counter INT = 1",
        "DECLARE\n    counter INTEGER := 1;",
        "variables"
    ))
    
    tests.append(ConversionTest(
        "Multiple Variable Declaration",
        "DECLARE @var1 INT, @var2 VARCHAR(50)",
        "DECLARE\n    var1 INTEGER;\n    var2 VARCHAR(50);",
        "variables"
    ))
    
    # SELECT Assignment Tests
    tests.append(ConversionTest(
        "Simple SELECT Assignment",
        "SELECT @var = value FROM table",
        "SELECT value INTO var FROM table",
        "assignment"
    ))
    
    tests.append(ConversionTest(
        "SELECT Assignment with Function",
        "SELECT @maxId = MAX(Id) FROM Users",
        "SELECT MAX(Id) INTO maxId FROM Users",
        "assignment"
    ))
    
    # Control Flow Tests
    tests.append(ConversionTest(
        "IF Statement with BEGIN/END",
        "IF @count > 0 BEGIN PRINT 'Found' END",
        "IF count > 0 THEN\\n    PRINT 'Found'\\nEND IF;",
        "control_flow"
    ))
    
    tests.append(ConversionTest(
        "WHILE Loop",
        "WHILE @counter <= 10 BEGIN SET @counter = @counter + 1 END",
        "WHILE counter <= 10 LOOP\\n    SET counter = counter + 1\\nEND LOOP;",
        "control_flow"
    ))
    
    # Function Conversion Tests
    tests.append(ConversionTest(
        "ISNULL Function",
        "SELECT ISNULL(@var, 'default')",
        "SELECT COALESCE(var, 'default')",
        "functions"
    ))
    
    tests.append(ConversionTest(
        "GETDATE Function",
        "SELECT GETDATE()",
        "SELECT CURRENT_TIMESTAMP",
        "functions"
    ))
    
    tests.append(ConversionTest(
        "LEN Function",
        "SELECT LEN(@name)",
        "SELECT LENGTH(name)",
        "functions"
    ))
    
    # String Concatenation Tests
    tests.append(ConversionTest(
        "String Concatenation",
        "SELECT 'Hello ' + @name",
        "SELECT 'Hello ' || name",
        "strings"
    ))
    
    tests.append(ConversionTest(
        "Complex String Concatenation",
        "INSERT INTO log VALUES ('Error: ' + CONVERT(VARCHAR, @error))",
        "INSERT INTO log VALUES ('Error: ' || error::TEXT)",
        "strings"
    ))
    
    # Data Type Tests
    tests.append(ConversionTest(
        "Data Type Conversion",
        "DECLARE @date DATETIME, @flag BIT",
        "DECLARE\\n    date TIMESTAMP;\\n    flag BOOLEAN;",
        "datatypes"
    ))
    
    # System Function Tests
    tests.append(ConversionTest(
        "System Functions",
        "SELECT @@ROWCOUNT",
        "SELECT GET DIAGNOSTICS row_count = ROW_COUNT",
        "system"
    ))
    
    # Temp Table Tests
    tests.append(ConversionTest(
        "Temp Table Reference",
        "SELECT * FROM #tempTable",
        "SELECT * FROM tempTable_temp",
        "temp_tables"
    ))
    
    # CAST/CONVERT Tests
    tests.append(ConversionTest(
        "CONVERT Function",
        "CONVERT(VARCHAR, @id)",
        "id::TEXT",
        "casting"
    ))
    
    tests.append(ConversionTest(
        "CAST Function",
        "CAST(@value AS INT)",
        "value::INTEGER",
        "casting"
    ))
    
    return tests

def run_test_suite(converter_path: str = "convert-tsql-syntax-v2.py"):
    """Run the complete test suite"""
    tests = create_test_cases()
    
    print("T-SQL to PL/pgSQL Conversion Tool Test Suite")
    print("=" * 50)
    
    passed = 0
    failed = 0
    categories = {}
    
    for test in tests:
        print(f"\\nTesting: {test.name}")
        print(f"Category: {test.category}")
        print(f"Input:    {test.input_sql}")
        
        actual_output = run_converter(test.input_sql, converter_path)
        
        # Simple comparison (could be enhanced with fuzzy matching)
        test_passed = actual_output.strip() == test.expected_output.strip()
        
        if test_passed:
            print("✅ PASSED")
            passed += 1
        else:
            print("❌ FAILED")
            print(f"Expected: {test.expected_output}")
            print(f"Actual:   {actual_output}")
            failed += 1
        
        # Track by category
        if test.category not in categories:
            categories[test.category] = {'passed': 0, 'failed': 0}
        
        if test_passed:
            categories[test.category]['passed'] += 1
        else:
            categories[test.category]['failed'] += 1
    
    # Summary
    print("\\n" + "=" * 50)
    print("TEST SUMMARY")
    print("=" * 50)
    print(f"Total Tests: {len(tests)}")
    print(f"Passed: {passed}")
    print(f"Failed: {failed}")
    print(f"Success Rate: {(passed/len(tests)*100):.1f}%")
    
    print("\\nBy Category:")
    for category, results in categories.items():
        total = results['passed'] + results['failed']
        rate = (results['passed'] / total * 100) if total > 0 else 0
        print(f"  {category}: {results['passed']}/{total} ({rate:.1f}%)")
    
    return passed, failed

if __name__ == "__main__":
    converter_path = sys.argv[1] if len(sys.argv) > 1 else "convert-tsql-syntax-v2.py"
    passed, failed = run_test_suite(converter_path)
    sys.exit(0 if failed == 0 else 1)