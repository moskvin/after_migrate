# AfterMigrate

**Automatically run database maintenance after Rails migrations**

`after_migrate` detects tables touched during `rails db:migrate` (or related tasks) and runs the appropriate optimizer commands:

- **PostgreSQL** → `ANALYZE` (affected tables or all) + optional `VACUUM`
- **SQLite**     → `PRAGMA optimize` (or `VACUUM` + `ANALYZE`)
- **MySQL**      → `ANALYZE TABLE`

Stale statistics and fragmentation after schema changes silently hurt query performance.  
`after_migrate` fixes it - automatically and precisely.

![after_migrate](./logo.png)

> **Because every migration deserves a cleanup.**

[![Gem Version](https://badge.fury.io/rb/after_migrate.svg)](https://badge.fury.io/rb/after_migrate)

---

## ✨ Features

- Smart detection of affected tables (CREATE/ALTER/INSERT/UPDATE/DELETE/etc.)
- Zero false positives - ignores views, columns, system tables, and complex joins
- Configurable via environment variables or initializer block
- Supports `db:migrate`, `db:rollback`, `db:migrate:redo`
- No monkey-patching of ActiveRecord core classes
- Works in development, test, CI, and production
- Rails 7.0+ / Ruby 3.2+ only

---

## 📦 Installation

Add to your Gemfile:

```ruby
gem 'after_migrate'
```

Then run:

```bash
bundle install
```

---

## 🚀 Usage

The gem activates automatically. No code required for default behavior.

### Default behavior (recommended)

Out of the box, it runs `ANALYZE` on **only the tables touched** during the migration (PostgreSQL default).

### Configuration

Create `config/initializers/after_migrate.rb`:

```ruby
AfterMigrate.configure do |config|
  # Enable/disable the gem
  config.enabled = true

  # Log what’s happening
  config.verbose = true

  # Run VACUUM on affected tables (PostgreSQL only)
  config.vacuum = false

  # Choose ANALYZE strategy
  # "only_affected_tables" - default, precise
  # "all_tables"           - full database analyze
  # "none"                 - skip ANALYZE entirely
  config.analyze = "only_affected_tables"

  # Enhance rake tasks (runs maintenance after db:migrate etc.)
  # Set to false in test env if needed
  config.rake_tasks_enhanced = true
end
```
---

## 🤝 Contributing

Bug reports, feature requests, and pull requests are very welcome!

https://github.com/moskvin/after_migrate

---

## 📝 License

This project is available under the MIT License.
