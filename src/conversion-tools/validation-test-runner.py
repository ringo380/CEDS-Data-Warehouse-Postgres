#!/usr/bin/env python3
"""
PostgreSQL Database Validation Test Runner
CEDS Data Warehouse Comprehensive Testing Tool

This Python script runs comprehensive validation tests on the converted
PostgreSQL CEDS Data Warehouse and generates detailed reports.

Features:
- Automated test execution and reporting
- Performance benchmarking
- Data integrity validation
- Security compliance checking
- Detailed HTML and JSON reporting
- Integration with CI/CD pipelines

Requirements:
- Python 3.8+
- psycopg2 (PostgreSQL connectivity)
- jinja2 (HTML template rendering)
- pandas (data analysis)

Usage:
    python validation-test-runner.py --config db_config.json --output-dir ./reports

Author: CEDS PostgreSQL Migration Project
Version: 1.0.0
"""

import argparse
import json
import logging
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any

try:
    import psycopg2
    import pandas as pd
    from psycopg2.extras import RealDictCursor
    from jinja2 import Template
except ImportError as e:
    print(f"Missing required package: {e}")
    print("Install with: pip install psycopg2-binary pandas jinja2")
    sys.exit(1)

class ValidationTestRunner:
    """Comprehensive validation test runner for PostgreSQL CEDS database"""
    
    def __init__(self, config_file: str, output_dir: str = './reports'):
        self.config = self._load_config(config_file)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        self.connection = None
        self.logger = self._setup_logging()
        
        self.test_results = []
        self.validation_summary = {}
        self.performance_metrics = {}
        
    def _load_config(self, config_file: str) -> Dict:
        """Load database configuration"""
        try:
            with open(config_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            print(f"Configuration file not found: {config_file}")
            sys.exit(1)
        except json.JSONDecodeError as e:
            print(f"Invalid JSON in configuration file: {e}")
            sys.exit(1)
    
    def _setup_logging(self) -> logging.Logger:
        """Configure logging"""
        log_file = self.output_dir / f"validation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        
        return logging.getLogger(__name__)
    
    def connect_database(self):
        """Establish database connection"""
        try:
            self.connection = psycopg2.connect(
                host=self.config['host'],
                port=self.config['port'],
                database=self.config['database'],
                user=self.config['username'],
                password=self.config['password']
            )
            self.connection.autocommit = True
            self.logger.info("Connected to PostgreSQL database")
        except Exception as e:
            self.logger.error(f"Database connection failed: {e}")
            raise
    
    def disconnect_database(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            self.connection = None
    
    def install_validation_suite(self):
        """Install validation suite if not already present"""
        self.logger.info("Installing validation suite...")
        
        # Check if validation schema exists
        cursor = self.connection.cursor()
        cursor.execute("SELECT EXISTS(SELECT 1 FROM information_schema.schemata WHERE schema_name = 'validation')")
        validation_exists = cursor.fetchone()[0]
        
        if not validation_exists:
            self.logger.info("Validation suite not found, installing...")
            
            # Read and execute validation suite SQL
            validation_sql_path = Path(__file__).parent / 'postgresql-validation-suite.sql'
            if validation_sql_path.exists():
                with open(validation_sql_path, 'r') as f:
                    validation_sql = f.read()
                
                # Execute in chunks to avoid issues with large scripts
                sql_statements = validation_sql.split(';')
                for statement in sql_statements:
                    statement = statement.strip()
                    if statement and not statement.startswith('--'):
                        try:
                            cursor.execute(statement)
                        except Exception as e:
                            if "already exists" not in str(e).lower():
                                self.logger.warning(f"SQL execution warning: {e}")
                
                self.logger.info("Validation suite installed successfully")
            else:
                self.logger.error("Validation suite SQL file not found")
                raise FileNotFoundError("postgresql-validation-suite.sql not found")
        else:
            self.logger.info("Validation suite already installed")
        
        cursor.close()
    
    def run_comprehensive_validation(self) -> Dict:
        """Run the comprehensive validation suite"""
        self.logger.info("Starting comprehensive validation...")
        
        cursor = self.connection.cursor(cursor_factory=RealDictCursor)
        
        try:
            # Run the comprehensive validation
            cursor.execute("SELECT validation.run_comprehensive_validation();")
            summary_result = cursor.fetchone()
            
            # Get detailed results
            cursor.execute("SELECT * FROM validation.test_results ORDER BY test_category, test_name;")
            test_results = cursor.fetchall()
            
            # Get validation summary
            cursor.execute("SELECT * FROM validation.validation_summary ORDER BY validation_date DESC LIMIT 1;")
            summary = cursor.fetchone()
            
            # Convert to regular dicts for JSON serialization
            self.test_results = [dict(row) for row in test_results]
            self.validation_summary = dict(summary) if summary else {}
            
            self.logger.info(f"Validation completed: {len(self.test_results)} tests executed")
            
            return self.validation_summary
            
        except Exception as e:
            self.logger.error(f"Validation execution failed: {e}")
            raise
        finally:
            cursor.close()
    
    def collect_performance_metrics(self):
        """Collect performance metrics for reporting"""
        self.logger.info("Collecting performance metrics...")
        
        cursor = self.connection.cursor(cursor_factory=RealDictCursor)
        
        try:
            # Database size
            cursor.execute("""
                SELECT 
                    pg_size_pretty(pg_database_size(current_database())) as database_size,
                    pg_database_size(current_database()) as database_size_bytes
            """)
            db_size = cursor.fetchone()
            
            # Table sizes
            cursor.execute("""
                SELECT 
                    schemaname,
                    tablename,
                    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
                    pg_total_relation_size(schemaname||'.'||tablename) as size_bytes
                FROM pg_tables 
                WHERE schemaname IN ('rds', 'staging', 'ceds')
                ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
                LIMIT 10
            """)
            table_sizes = cursor.fetchall()
            
            # Index usage statistics
            cursor.execute("""
                SELECT 
                    schemaname,
                    tablename,
                    indexname,
                    idx_scan,
                    idx_tup_read,
                    idx_tup_fetch,
                    pg_size_pretty(pg_relation_size(indexrelid)) as size
                FROM pg_stat_user_indexes
                WHERE schemaname IN ('rds', 'staging', 'ceds')
                ORDER BY idx_scan DESC
                LIMIT 20
            """)
            index_stats = cursor.fetchall()
            
            # Buffer cache hit ratio
            cursor.execute("""
                SELECT 
                    ROUND(
                        100.0 * SUM(heap_blks_hit) / 
                        NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0), 2
                    ) as cache_hit_ratio
                FROM pg_statio_user_tables
                WHERE schemaname IN ('rds', 'staging', 'ceds')
            """)
            cache_ratio = cursor.fetchone()
            
            # Connection statistics
            cursor.execute("""
                SELECT 
                    state,
                    COUNT(*) as count
                FROM pg_stat_activity
                WHERE datname = current_database()
                GROUP BY state
                ORDER BY count DESC
            """)
            connections = cursor.fetchall()
            
            self.performance_metrics = {
                'database_size': dict(db_size) if db_size else {},
                'table_sizes': [dict(row) for row in table_sizes],
                'index_statistics': [dict(row) for row in index_stats],
                'cache_hit_ratio': dict(cache_ratio) if cache_ratio else {},
                'connections': [dict(row) for row in connections],
                'collection_timestamp': datetime.now().isoformat()
            }
            
        except Exception as e:
            self.logger.error(f"Performance metrics collection failed: {e}")
            self.performance_metrics = {'error': str(e)}
        finally:
            cursor.close()
    
    def analyze_test_results(self) -> Dict:
        """Analyze test results and provide insights"""
        if not self.test_results:
            return {}
        
        # Group results by category
        category_analysis = {}
        for result in self.test_results:
            category = result['test_category']
            if category not in category_analysis:
                category_analysis[category] = {
                    'total': 0,
                    'passed': 0,
                    'failed': 0,
                    'warnings': 0,
                    'skipped': 0,
                    'success_rate': 0.0,
                    'failed_tests': []
                }
            
            category_analysis[category]['total'] += 1
            
            if result['status'] == 'PASS':
                category_analysis[category]['passed'] += 1
            elif result['status'] == 'FAIL':
                category_analysis[category]['failed'] += 1
                category_analysis[category]['failed_tests'].append({
                    'name': result['test_name'],
                    'description': result['test_description'],
                    'error': result.get('error_message', '')
                })
            elif result['status'] == 'WARNING':
                category_analysis[category]['warnings'] += 1
            elif result['status'] == 'SKIP':
                category_analysis[category]['skipped'] += 1
        
        # Calculate success rates
        for category in category_analysis:
            total = category_analysis[category]['total']
            passed = category_analysis[category]['passed']
            if total > 0:
                category_analysis[category]['success_rate'] = (passed / total) * 100
        
        return category_analysis
    
    def generate_html_report(self) -> str:
        """Generate comprehensive HTML report"""
        self.logger.info("Generating HTML report...")
        
        # Analyze results
        category_analysis = self.analyze_test_results()
        
        # HTML template
        html_template = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CEDS PostgreSQL Validation Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 20px; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .summary-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }
        .summary-card h3 { margin: 0; font-size: 2em; }
        .summary-card p { margin: 5px 0 0 0; opacity: 0.9; }
        .section { margin-bottom: 30px; }
        .section h2 { color: #333; border-bottom: 2px solid #ddd; padding-bottom: 10px; }
        .status-pass { color: #4CAF50; font-weight: bold; }
        .status-fail { color: #f44336; font-weight: bold; }
        .status-warning { color: #ff9800; font-weight: bold; }
        .status-skip { color: #9e9e9e; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .category-card { background: white; border: 1px solid #ddd; border-radius: 8px; padding: 20px; margin-bottom: 20px; }
        .progress-bar { width: 100%; height: 20px; background-color: #f0f0f0; border-radius: 10px; overflow: hidden; }
        .progress-fill { height: 100%; background: linear-gradient(90deg, #4CAF50, #8BC34A); transition: width 0.3s ease; }
        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
        .error-details { background: #ffebee; border-left: 4px solid #f44336; padding: 10px; margin: 10px 0; }
        .performance-metric { background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 10px 0; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🗄️ CEDS Data Warehouse PostgreSQL Validation Report</h1>
            <p>Generated on {{ report_date }}</p>
            <p>Database: {{ database_name }}</p>
        </div>

        <div class="summary">
            <div class="summary-card">
                <h3>{{ summary.total_tests }}</h3>
                <p>Total Tests</p>
            </div>
            <div class="summary-card">
                <h3>{{ summary.passed_tests }}</h3>
                <p>Passed</p>
            </div>
            <div class="summary-card">
                <h3>{{ summary.failed_tests }}</h3>
                <p>Failed</p>
            </div>
            <div class="summary-card">
                <h3>{{ "%.1f"|format(success_rate) }}%</h3>
                <p>Success Rate</p>
            </div>
        </div>

        <div class="section">
            <h2>📊 Overall Status: <span class="status-{{ summary.overall_status.lower() }}">{{ summary.overall_status }}</span></h2>
            <div class="progress-bar">
                <div class="progress-fill" style="width: {{ success_rate }}%"></div>
            </div>
            <p>Execution Duration: {{ summary.execution_duration }}</p>
        </div>

        <div class="section">
            <h2>📋 Test Results by Category</h2>
            {% for category, analysis in category_analysis.items() %}
            <div class="category-card">
                <h3>{{ category.replace('_', ' ').title() }}</h3>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {{ analysis.success_rate }}%"></div>
                </div>
                <p>{{ analysis.passed }}/{{ analysis.total }} tests passed ({{ "%.1f"|format(analysis.success_rate) }}%)</p>
                
                {% if analysis.failed_tests %}
                <h4>❌ Failed Tests:</h4>
                {% for failed_test in analysis.failed_tests %}
                <div class="error-details">
                    <strong>{{ failed_test.name }}</strong><br>
                    {{ failed_test.description }}<br>
                    {% if failed_test.error %}
                    <em>Error: {{ failed_test.error }}</em>
                    {% endif %}
                </div>
                {% endfor %}
                {% endif %}
            </div>
            {% endfor %}
        </div>

        <div class="section">
            <h2>⚡ Performance Metrics</h2>
            <div class="metric-grid">
                {% if performance_metrics.database_size %}
                <div class="performance-metric">
                    <h4>Database Size</h4>
                    <p>{{ performance_metrics.database_size.database_size }}</p>
                </div>
                {% endif %}
                
                {% if performance_metrics.cache_hit_ratio %}
                <div class="performance-metric">
                    <h4>Buffer Cache Hit Ratio</h4>
                    <p>{{ performance_metrics.cache_hit_ratio.cache_hit_ratio or 'N/A' }}%</p>
                </div>
                {% endif %}
            </div>

            {% if performance_metrics.table_sizes %}
            <h3>Largest Tables</h3>
            <table>
                <tr><th>Schema</th><th>Table</th><th>Size</th></tr>
                {% for table in performance_metrics.table_sizes[:5] %}
                <tr>
                    <td>{{ table.schemaname }}</td>
                    <td>{{ table.tablename }}</td>
                    <td>{{ table.size }}</td>
                </tr>
                {% endfor %}
            </table>
            {% endif %}
        </div>

        <div class="section">
            <h2>📈 Recommendations</h2>
            <ul>
                {% if summary.failed_tests > 0 %}
                <li>⚠️ Address {{ summary.failed_tests }} failed tests before production deployment</li>
                {% endif %}
                {% if performance_metrics.cache_hit_ratio and performance_metrics.cache_hit_ratio.cache_hit_ratio %}
                    {% if performance_metrics.cache_hit_ratio.cache_hit_ratio < 95 %}
                    <li>🔧 Consider increasing shared_buffers - cache hit ratio is {{ performance_metrics.cache_hit_ratio.cache_hit_ratio }}%</li>
                    {% endif %}
                {% endif %}
                <li>🔄 Run validation tests regularly after schema changes</li>
                <li>📊 Monitor performance metrics and optimize based on actual usage patterns</li>
                <li>🔒 Review security configuration and access controls</li>
            </ul>
        </div>

        <div class="section">
            <h2>📋 Detailed Test Results</h2>
            <table>
                <tr>
                    <th>Category</th>
                    <th>Test Name</th>
                    <th>Status</th>
                    <th>Description</th>
                    <th>Execution Time</th>
                </tr>
                {% for result in test_results %}
                <tr>
                    <td>{{ result.test_category }}</td>
                    <td>{{ result.test_name }}</td>
                    <td class="status-{{ result.status.lower() }}">{{ result.status }}</td>
                    <td>{{ result.test_description }}</td>
                    <td>{{ result.execution_time or 'N/A' }}</td>
                </tr>
                {% endfor %}
            </table>
        </div>

        <div class="section">
            <p><em>Report generated by CEDS PostgreSQL Validation Suite</em></p>
        </div>
    </div>
</body>
</html>
        """
        
        # Render template
        template = Template(html_template)
        success_rate = (self.validation_summary.get('passed_tests', 0) / 
                       max(self.validation_summary.get('total_tests', 1), 1)) * 100
        
        html_content = template.render(
            report_date=datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            database_name=self.config['database'],
            summary=self.validation_summary,
            success_rate=success_rate,
            category_analysis=category_analysis,
            test_results=self.test_results,
            performance_metrics=self.performance_metrics
        )
        
        # Save HTML report
        html_file = self.output_dir / f"validation_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.html"
        with open(html_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        self.logger.info(f"HTML report saved to: {html_file}")
        return str(html_file)
    
    def generate_json_report(self) -> str:
        """Generate JSON report for programmatic consumption"""
        self.logger.info("Generating JSON report...")
        
        report_data = {
            'report_metadata': {
                'generated_at': datetime.now().isoformat(),
                'database': self.config['database'],
                'validation_tool_version': '1.0.0'
            },
            'validation_summary': self.validation_summary,
            'test_results': self.test_results,
            'performance_metrics': self.performance_metrics,
            'category_analysis': self.analyze_test_results()
        }
        
        # Save JSON report
        json_file = self.output_dir / f"validation_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(report_data, f, indent=2, default=str)
        
        self.logger.info(f"JSON report saved to: {json_file}")
        return str(json_file)
    
    def run_full_validation(self) -> Dict:
        """Run complete validation and generate all reports"""
        self.logger.info("Starting full validation process...")
        
        try:
            # Connect to database
            self.connect_database()
            
            # Install validation suite if needed
            self.install_validation_suite()
            
            # Run comprehensive validation
            summary = self.run_comprehensive_validation()
            
            # Collect performance metrics
            self.collect_performance_metrics()
            
            # Generate reports
            html_report = self.generate_html_report()
            json_report = self.generate_json_report()
            
            result = {
                'validation_summary': summary,
                'reports': {
                    'html': html_report,
                    'json': json_report
                },
                'performance_metrics': self.performance_metrics
            }
            
            self.logger.info("Full validation completed successfully")
            return result
            
        except Exception as e:
            self.logger.error(f"Validation process failed: {e}")
            raise
        finally:
            self.disconnect_database()


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="PostgreSQL Database Validation Test Runner for CEDS Data Warehouse"
    )
    parser.add_argument(
        '--config',
        type=str,
        required=True,
        help='Database configuration file (JSON)'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        default='./validation-reports',
        help='Output directory for reports'
    )
    parser.add_argument(
        '--install-suite',
        action='store_true',
        help='Force installation of validation suite'
    )
    parser.add_argument(
        '--performance-only',
        action='store_true',
        help='Run only performance metrics collection'
    )
    
    args = parser.parse_args()
    
    # Validate config file exists
    if not os.path.exists(args.config):
        print(f"Configuration file not found: {args.config}")
        sys.exit(1)
    
    # Create test runner
    runner = ValidationTestRunner(args.config, args.output_dir)
    
    try:
        if args.performance_only:
            # Run performance metrics only
            runner.connect_database()
            runner.collect_performance_metrics()
            json_report = runner.generate_json_report()
            print(f"Performance metrics report: {json_report}")
        else:
            # Run full validation
            result = runner.run_full_validation()
            
            # Display summary
            summary = result['validation_summary']
            print(f"\n{'='*60}")
            print("VALIDATION SUMMARY")
            print(f"{'='*60}")
            print(f"Total Tests: {summary.get('total_tests', 0)}")
            print(f"Passed: {summary.get('passed_tests', 0)}")
            print(f"Failed: {summary.get('failed_tests', 0)}")
            print(f"Warnings: {summary.get('warning_tests', 0)}")
            print(f"Overall Status: {summary.get('overall_status', 'UNKNOWN')}")
            print(f"Duration: {summary.get('execution_duration', 'N/A')}")
            print(f"\nReports generated:")
            print(f"  HTML: {result['reports']['html']}")
            print(f"  JSON: {result['reports']['json']}")
            print(f"{'='*60}")
            
            # Exit with error code if tests failed
            if summary.get('failed_tests', 0) > 0:
                sys.exit(1)
        
    except KeyboardInterrupt:
        print("\nValidation interrupted by user")
        sys.exit(1)
    except Exception as e:
        print(f"Validation failed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()