# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2026-04-28

### Added
- `defer` configuration option (default: `true`) — when enabled, rake task enhancements only collect touched tables; they do not run maintenance automatically
- `AfterMigrate.run!` public API to explicitly trigger maintenance on all collected tables across all schemas, then clear the store — intended to be called once after all tenant migrations complete in multi-tenant setups
- `after_migrate:run` rake task as a convenience wrapper around `AfterMigrate.run!`

### Changed
- **Breaking**: replaced `AfterMigrate::Current` (`ActiveSupport::CurrentAttributes`) with a module-level persistent store (`Concurrent::Map`). The store accumulates touched tables across multiple rake task invocations and only resets when `AfterMigrate.run!` is called.
- Fixed `all_tables` analyze mode - previously iterated `.each_value` (yielding `Concurrent::Set` objects) instead of schema names, producing incorrect SQL queries.

### Removed
- `AfterMigrate::Current` - no longer needed. If you referenced this class directly, use `AfterMigrate.affected_tables` instead.
- `Executor.call(reset:)` parameter - the store is always cleared after `run!`; pass `schema:` to scope execution to a single schema.

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
