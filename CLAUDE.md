# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
bundle install          # install dependencies
bundle exec rspec       # run all tests
bundle exec rspec spec/after_migrate_spec.rb  # run a single spec file
bundle exec rake        # default task (runs spec)
bundle exec rubocop     # lint
bundle exec rubocop -a  # lint with auto-fix
rake release            # build and push gem to RubyGems
```

## Architecture

This is a Rails gem that automatically runs database maintenance (`ANALYZE`, `VACUUM`, `PRAGMA optimize`) after `db:migrate` tasks. The core flow is:

1. **`Railtie`** (`lib/after_migrate/railtie.rb`) — the entry point. On Rails init, it subscribes to `sql.active_record` notifications so every SQL statement during a migration is intercepted. It enhances `db:migrate`, `db:migrate:up`, and `db:migrate:redo` to call `AfterMigrate.run!` when they complete — unless `defer: true` (the default), in which case the rake task only collects. It also registers the `after_migrate:run` task.

2. **`Collector`** (`lib/after_migrate/collector.rb`) — receives every SQL notification, filters to DDL/DML statements (CREATE/ALTER/DROP/INSERT/UPDATE/DELETE), calls the adapter-specific parser, and accumulates table names into `AfterMigrate.affected_tables` (a `Concurrent::Map<schema, Concurrent::Set<table_name>>`).

3. **`AfterMigrate.store`** (`lib/after_migrate/store.rb`) — defaults to an in-memory `Concurrent::Map` wrapped by `AfterMigrate::Stores::Memory`. `AfterMigrate.affected_tables`, `merge_tables`, and `reset!` delegate to the store. The memory store persists across multiple rake task invocations inside one Ruby process and is cleared by `AfterMigrate.run!` (or `AfterMigrate.reset!`). This replaces the old `Current` (`ActiveSupport::CurrentAttributes`) which was reset after every migration.

4. **`Executor`** (`lib/after_migrate/executor.rb`) — iterates `AfterMigrate.affected_tables` and calls the correct adapter's `optimize_tables`. Respects the `analyze` config option (`only_affected_tables` / `all_tables` / `none`). Always calls `AfterMigrate.reset!` in its `ensure` block.

5. **Adapters** (`lib/after_migrate/adapters/`) — one module per database:
   - `Sql` — shared regex-based table parser (used by MySQL and SQLite, which can't use pg_query)
   - `Postgresql` — uses `pg_query` gem for accurate SQL parsing; runs `VACUUM` (checking `pg_stat_all_tables` for dead tuples) then `ANALYZE VERBOSE` per table
   - `Mysql` — runs `ANALYZE TABLE` per table; lists tables from `information_schema`
   - `Sqlite` — runs `PRAGMA optimize` (SQLite ≥ 3.35.0) or `VACUUM; ANALYZE;`

## Key design decisions

- PostgreSQL uses `pg_query` (the actual Postgres parser) for table extraction, which avoids false positives from regex. MySQL and SQLite fall back to the shared `Sql` regex patterns.
- `pg_query` is a hard runtime dependency (listed in gemspec), not optional — even though it's only used for PostgreSQL.
- Table collection uses `Concurrent::Map` + `Concurrent::Set` (from `concurrent-ruby`) for thread-safe accumulation across parallel migration workers.
- The gem does **not** monkey-patch ActiveRecord. It only uses public `ActiveSupport::Notifications` and `Rake::Task#enhance` APIs.
- `defer: true` (the default) is the multi-tenant-friendly mode: rake tasks only collect, never execute. Call `AfterMigrate.run!` (or `rake after_migrate:run`) once after all tenant migrations complete.
- The `app.executor.to_run` unsubscription in `Railtie` ensures the SQL subscription is dropped before the app starts serving web requests, so normal traffic is never collected.

## Configuration

Config values are in `AfterMigrate::Configuration` (initialized in `lib/after_migrate.rb`):

| Option                | Default                  | Values                                             |
|-----------------------|--------------------------|----------------------------------------------------|
| `enabled`             | `true`                   | bool                                               |
| `verbose`             | `true`                   | bool                                               |
| `vacuum`              | `true`                   | bool (PostgreSQL only)                             |
| `analyze`             | `"only_affected_tables"` | `"only_affected_tables"`, `"all_tables"`, `"none"` |
| `rake_tasks_enhanced` | `true`                   | bool                                               |
| `defer`               | `true`                   | bool — skip auto-run; call `AfterMigrate.run!` manually |

## Multi-tenant usage

```ruby
# In your tenant migration runner:
Tenant.each do |tenant|
  tenant.switch { ActiveRecord::MigrationContext.new(...).migrate }
end
# Tables are now accumulated per schema in AfterMigrate.affected_tables
AfterMigrate.run!           # or: Rake::Task['after_migrate:run'].invoke
```

Set `defer: false` to restore the v0.1 behaviour of running after each `db:migrate`.

## Dependencies

- Ruby ≥ 3.2, Rails ≥ 7.0
- `pg_query ≥ 6.1` (required even for non-Postgres installs)
- Dev: `rspec ~> 3.0`, `rubocop ~> 1.81`, `bundler ~> 4`
