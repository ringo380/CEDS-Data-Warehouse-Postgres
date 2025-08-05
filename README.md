![CEDS Data Warehouse Logo](/res/CEDS-Data-Warehouse-Logo-Full-Medium.png "CEDS Data Warehouse")

# CEDS Data Warehouse - PostgreSQL Implementation
Modeled for longitudinal storage and reporting of P-20W data, the Common Education Data Standards (CEDS) Data Warehouse implements star schema data warehouse normalization techniques for improved query performance.

**This repository contains a PostgreSQL conversion of the original CEDS Data Warehouse, which was designed for SQL Server.** The original source repository is maintained by the CEDS community at: https://github.com/CEDStandards/CEDS-Data-Warehouse

## Key Features of the PostgreSQL Implementation

- Complete database schema conversion from SQL Server to PostgreSQL
- Automated conversion tools for SQL Server T-SQL to PostgreSQL PL/pgSQL
- PostgreSQL-optimized performance configurations
- Comprehensive migration guides and validation tools
- Production-ready security and monitoring setup

## Getting Started

### Prerequisites

- **PostgreSQL 12+** (PostgreSQL 14+ recommended)
- **System Requirements**: 8GB RAM minimum (16GB+ recommended), 100GB+ storage
- **Python 3.8+** (for conversion tools)
- PostgreSQL client tools (psql, pgAdmin, or similar)

### Fresh PostgreSQL Installation

To create a new instance of the CEDS Data Warehouse on PostgreSQL, follow these steps:

#### 1. Set Up PostgreSQL Environment
```bash
# Create the database
createdb ceds_data_warehouse_v11_0_0_0

# Connect as database administrator
psql -d ceds_data_warehouse_v11_0_0_0
```

#### 2. Set Up Schemas and Security
```bash
# Navigate to conversion tools directory
cd src/conversion-tools

# First, create schemas and security roles (must be done before configuration)
psql -d ceds_data_warehouse_v11_0_0_0 -f postgresql-schemas-and-security.sql

# Then apply PostgreSQL-specific database settings
psql -d ceds_data_warehouse_v11_0_0_0 -f postgresql-database-configuration.sql
```

#### 3. Create Database Structure ⚠️ CRITICAL STEP
```bash
# IMPORTANT: Create all tables, functions, and views BEFORE loading data
# This step creates 100+ dimension and fact tables required for the data warehouse
psql -d ceds_data_warehouse_v11_0_0_0 -f ../ddl/CEDS-Data-Warehouse-V11.0.0.0-PostgreSQL.sql
```

**⚠️ Do not skip this step!** The dimension data loader will fail if the tables don't exist.

#### 4. Load Dimension Data
```bash
# Load CEDS Elements and Option Set values (requires tables from step 3)
psql -d ceds_data_warehouse_v11_0_0_0 -f postgresql-dimension-data-loader.sql

# Populate essential dimension tables (races, ages, dates)
psql -d ceds_data_warehouse_v11_0_0_0 -f junk-table-population-postgresql.sql
```

#### 5. Validate Installation
```bash
# Run validation tests
psql -d ceds_data_warehouse_v11_0_0_0 -f validate-postgresql-config.sql
```

### Detailed Installation Guide

For comprehensive installation instructions, security configuration, performance optimization, and troubleshooting, see:
- [PostgreSQL Installation Guide](src/conversion-tools/postgresql-installation-guide.md)

## Conversion Tools

This repository includes powerful conversion tools for migrating from SQL Server to PostgreSQL:

- **`convert-table-ddl.py`** - Converts SQL Server table definitions
- **`convert-functions.py`** - Converts SQL Server functions to PostgreSQL
- **`convert-views.py`** - Converts SQL Server views  
- **`convert-etl-procedures.py`** - Converts stored procedures to PostgreSQL
- **`bulk-data-migration.py`** - Handles data migration between systems

### Migration from SQL Server

If you have an existing SQL Server CEDS Data Warehouse and want to migrate to PostgreSQL:

1. Review the [Data Migration Guide](src/conversion-tools/data-migration-guide.md)
2. Use the conversion tools to transform your existing scripts
3. Follow the [SQL Server to PostgreSQL Migration Guide](src/conversion-tools/sql-server-to-postgresql-security-guide.md)

## Documentation

### Quick Reference Guides
- [T-SQL to PL/pgSQL Quick Reference](src/conversion-tools/tsql-to-plpgsql-quick-reference.md)
- [SQL Server to PostgreSQL Data Types](src/conversion-tools/sql-server-to-postgresql-datatypes.md)
- [Performance Tuning Guide](src/conversion-tools/performance-tuning-guide.md)
- [Testing Documentation](src/conversion-tools/testing-documentation.md)

### Advanced Topics
- [Function Conversion Guide](src/conversion-tools/function-conversion-guide.md)
- [View Conversion Guide](src/conversion-tools/view-conversion-guide.md)
- [Stored Procedure Conversion Guide](src/conversion-tools/stored-procedure-conversion-guide.md)
- [Identity to Serial Migration](src/conversion-tools/identity-to-serial-guide.md)

## Project Structure

```
src/
├── ddl/                          # Database definition scripts
│   ├── CEDS-Data-Warehouse-V11.0.0.0-PostgreSQL.sql    # PostgreSQL DDL
│   └── CEDS-Data-Warehouse-V11.0.0.0.sql               # Original SQL Server DDL
├── conversion-tools/             # PostgreSQL conversion utilities
│   ├── *.py                     # Python conversion scripts
│   ├── *.sql                    # PostgreSQL-specific SQL scripts
│   └── *.md                     # Documentation and guides
├── dimension-data/               # Reference data for dimensions
└── CEDS-Data-Warehouse-Project/  # Original SQL Server project structure
```

## Contributing

Please read [Contributing.md](/Contributing.md) for details on our code of conduct, and the process for submitting pull requests to us.

### Contributing to PostgreSQL Implementation

When contributing PostgreSQL-specific improvements:

1. Test your changes against both small and large datasets
2. Include performance benchmarks where applicable
3. Update relevant documentation in `src/conversion-tools/`
4. Ensure conversion tools generate valid PostgreSQL syntax
5. Follow PostgreSQL best practices for naming and coding standards

## Versioning

We use a customized version of [Explicit Versioning](https://github.com/exadra37-versioning/explicit-versioning) for versioning. To keep the various CEDS Open Source projects in alignment with the CEDS Elements, we are replacing the concept of "disruptive" releases with "alignment" releases. These releases ensure that the data models are in sync with the official, community approved list of CEDS Elements.

For the versions available:
- **Original CEDS Data Warehouse**: See [tags on the original repository](https://github.com/CEDStandards/CEDS-Data-Warehouse/tags)
- **PostgreSQL Implementation**: See [tags on this repository](https://github.com/ringo380/CEDS-Data-Warehouse-Postgres/tags)

## Authors

See the list of [contributors](/Contributors.md) who participated in this project.

### PostgreSQL Implementation Contributors

This PostgreSQL implementation builds upon the original CEDS Data Warehouse and includes additional work by contributors focused on PostgreSQL compatibility, performance optimization, and migration tooling.

## References

- **Original CEDS Data Warehouse**: https://github.com/CEDStandards/CEDS-Data-Warehouse
- **CEDS Website**: https://ceds.ed.gov/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **CEDS Community**: https://github.com/CEDStandards

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
