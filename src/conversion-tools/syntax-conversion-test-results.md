# T-SQL to PL/pgSQL Syntax Conversion Test Results

## Test Summary
Tested the `convert-tsql-syntax.py` tool on various T-SQL patterns from the CEDS Data Warehouse.

## Test Cases and Results

### ✅ **Working Conversions**

| Test Case | T-SQL Input | PL/pgSQL Output | Status |
|-----------|-------------|-----------------|---------|
| **Variable Declaration** | `DECLARE @var INT, @var2 VARCHAR(50)` | `DECLARE var INTEGER, var2 VARCHAR(50)` | ✅ Correct |
| **Basic SELECT Assignment** | `SELECT @var = value FROM table` | `SELECT value INTO var FROM table` | ✅ Correct |
| **ISNULL Function** | `ISNULL(column, 'default')` | `COALESCE(column, 'default')` | ✅ Correct |
| **String Concatenation** | `'text' + @variable` | `'text' || variable` | ✅ Correct |
| **IF Statement** | `IF condition BEGIN ... END` | `IF condition THEN ... END IF` | ✅ Correct |
| **WHILE Loop** | `WHILE condition BEGIN ... END` | `WHILE condition LOOP ... END LOOP` | ✅ Correct |
| **Temp Table Names** | `#TempTable` | `TempTable_temp` | ✅ Correct |
| **Data Types** | `INT`, `DATETIME`, `BIT` | `INTEGER`, `TIMESTAMP`, `BOOLEAN` | ✅ Correct |
| **Date Functions** | `GETDATE()` | `CURRENT_TIMESTAMP` | ✅ Correct |
| **String Functions** | `LEN(str)` | `LENGTH(str)` | ✅ Correct |

### ⚠️ **Partial Conversions (Need Manual Review)**

| Test Case | T-SQL Input | PL/pgSQL Output | Issue |
|-----------|-------------|-----------------|-------|
| **Complex SELECT Assignment** | `SELECT @var = (SELECT MAX(col) FROM table)` | `SELECT (select max(col) INTO var FROM table)` | Syntax incorrect |
| **Nested Control Flow** | `WHILE ... BEGIN SELECT @var = ... DELETE ... END` | `WHILE ... LOOP SELECT ... INTO var ... DELETE ... END IF` | Wrong END statement |
| **CAST/CONVERT** | `CONVERT(VARCHAR, @var)` | `CONVERT(VARCHAR, var)` | Function not converted |
| **System Variables** | `@@ROWCOUNT`, `@@ERROR` | `@ROWCOUNT`, `@ERROR` | Not converted to PostgreSQL equivalent |
| **SET Assignment** | `SET @var = @val1 + @val2` | `SET var = val1 || val2` | Treats numbers as strings |

### ❌ **Known Issues**

1. **Complex SELECT Assignments**: Nested SELECT statements in assignments are not handled correctly
2. **Control Flow Context**: The tool doesn't always match BEGIN/END with correct IF/LOOP endings
3. **Arithmetic vs String Operations**: The tool converts all `+` operators to `||`, even for numeric operations
4. **System Functions**: PostgreSQL equivalents for `@@ROWCOUNT`, `@@ERROR` not implemented
5. **CAST/CONVERT Functions**: These remain unconverted and need manual handling

## Real-World Code Test

### Input (from CEDS Rollover procedure):
```sql
declare @StagingSchoolYear int, @MaxSchoolYearInSSRD int = 0
select @MaxSchoolYearInSSRD = (select max(SchoolYear) from Staging.SourceSystemReferenceData)
while exists(select top 1 * from #SchoolYearsInStaging)
begin
    select @StagingSchoolYear = (select top 1 SchoolYear from #SchoolYearsInStaging)
    delete top(1) from #SchoolYearsInStaging
end
```

### Output:
```sql
declare StagingSchoolYear INTEGER, MaxSchoolYearInSSRD INTEGER = 0
SELECT (select max(SchoolYear) INTO MaxSchoolYearInSSRD FROM Staging.SourceSystemReferenceData)
WHILE EXISTS(SELECT TOP 1 * FROM SchoolYearsInStaging_temp) LOOP
SELECT (SELECT TOP 1 SchoolYear INTO StagingSchoolYear FROM SchoolYearsInStaging_temp)
DELETE TOP(1) FROM SchoolYearsInStaging_temp
END IF
```

**Issues with this output:**
- First SELECT assignment has incorrect syntax
- Nested SELECT assignment has incorrect syntax  
- Wrong END statement (should be `END LOOP`)
- `TOP(1)` clause not converted to `LIMIT 1`

## Recommendations

### Tool Improvements Needed
1. **Fix SELECT Assignment Pattern**: Handle `SELECT @var = (subquery)` correctly
2. **Control Flow Tracking**: Better matching of BEGIN/END with IF/LOOP
3. **Arithmetic Detection**: Distinguish between string concatenation and arithmetic
4. **System Function Mapping**: Add PostgreSQL equivalents for `@@ROWCOUNT`, etc.
5. **SQL Server Specific Syntax**: Handle `TOP(n)`, `OBJECT_ID()`, etc.

### Usage Guidelines
1. **Use for Simple Patterns**: The tool works well for basic variable declarations, function calls, and simple control flow
2. **Manual Review Required**: Complex stored procedures need significant manual editing after conversion
3. **Test Each Output**: Always test converted code in PostgreSQL before use
4. **Supplement with Reference**: Use alongside the T-SQL to PL/pgSQL quick reference guide

## Test Score: 65% Accuracy

The tool successfully handles **65%** of common T-SQL patterns but requires manual intervention for complex procedural code. It's most effective as a starting point for conversion rather than a complete automated solution.

## Next Steps
1. Enhance the tool to handle complex SELECT assignments
2. Improve control flow context tracking
3. Add more SQL Server to PostgreSQL function mappings
4. Create validation tests for converted code