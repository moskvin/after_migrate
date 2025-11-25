# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2025-04-05

### Added
- **Smart table detection** – automatically identifies tables touched during migrations using `sql.active_record` events
- **PostgreSQL support**
    - `ANALYZE` on affected tables (default) or all tables
    - Optional `VACUUM` via config
- **SQLite support**
    - `PRAGMA optimize` (SQLite 3.35+)
    - Fallback to `VACUUM` + `ANALYZE` on older versions
- **MySQL support** (MySQL 5.6+ / MariaDB)
    - `ANALYZE TABLE` on affected tables
- **Zero false positives** – bulletproof SQL parser ignores:
    - Views, materialized views, functions
    - Column names, joins, CTEs
    - System schemas (`pg_catalog`, `information_schema`)
- **Configurable via environment variables or block DSL**:
  ```ruby
      AfterMigrate.configure do |config|
        config.enabled  = false # default: true
        config.verbose  = false # default: true
        config.vacuum   = false # default: true
        config.analyze  = 'none' # only_affected_tables (default) or 'all_tables' or 'none'
      end
  ```
