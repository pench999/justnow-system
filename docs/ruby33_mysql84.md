# Ruby 3.3 / MySQL 8.4 migration notes

This tree targets Ruby 3.3 and MySQL 8.4 LTS.

## Runtime

Install dependencies with:

```sh
bundle install
```

Create the schema with:

```sh
RACK_ENV=production bundle exec ruby scripts/db_schema.rb
```

Run the app with:

```sh
RACK_ENV=production bundle exec rackup config.ru
```

## Compatibility changes

- `Gemfile` now uses HTTPS rubygems, Ruby 3.3, `mysql2` 0.5.x, Sinatra 3.2, Haml 5.2, and `net-ldap`.
- `stratum` is vendored under `vendor/stratum` so the app does not depend on the old `git://` source or `mysql2-cs-bind`.
- Stratum now binds SQL placeholders through `mysql2` escaping instead of `mysql2-cs-bind`.
- LDAP helper code uses `net-ldap` instead of `ruby-ldap`.
- Database schemas use `utf8mb4`; the `tagchains` fulltext table now uses InnoDB.

## Remaining validation

Run the RSpec suite against a disposable MySQL 8.4 database before using this with production data. Pay special attention to:

- Fulltext tag search behavior.
- LDAP authentication plugins in your real directory.
- Existing data migration from `utf8` tables to `utf8mb4`.
