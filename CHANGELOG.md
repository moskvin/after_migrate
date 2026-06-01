# Changelog

All notable changes to this project will be documented in this file.

## [0.2.3] - 2026-06-01

### Added
- Redis-backed store via `config.store = :redis` for sharing collected migration tables across processes
- `config.redis` for passing a Redis client, connection pool, or callable client provider
- `config.redis_key_prefix` and `config.redis_ttl` for namespacing and expiring Redis store keys
- Redis store support for run isolation via `config.run_id`
- Redis store specs for persistence, merging, reset behavior, connection pools, `Redis.new` fallback, and missing-client errors

### Changed
- Store cache keys now include Redis-specific configuration, so changing Redis store settings rebuilds the active store instance

## [0.2.2] - 2026-05-31

### Added
- Configurable store backend via `config.store`, with `:memory` as the default and `:file` for persistence across separate migration task processes
- `config.store_path` to control where the file-backed store writes collected table names
- `config.run_id` to isolate persisted file-store data between independent migration runs
- File-store locking and atomic writes to avoid corrupting persisted table data during concurrent access
- Specs for file-store persistence, corrupt JSON handling, adapter dispatch, unsupported adapters, and deferred rake task behavior

### Changed
- `AfterMigrate.affected_tables`, `AfterMigrate.merge_tables`, and `AfterMigrate.reset!` now delegate through the configured store backend
- Executor resets the store when maintenance is disabled or no tables are pending, but keeps collected tables when adapter optimization raises so a later run can retry

## [0.2.1] - 2026-05-29

### Changed
- Refactored SQL identifier matching used by the parser without changing supported table-detection behavior
- Split executor migration logging message construction into a local variable for clearer formatting and maintenance
- Added RuboCop project configuration for documentation, method length, and spec block length rules

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
