# Raxol Database Documentation

This document provides comprehensive information about Raxol's database system, including setup, configuration, operations, and troubleshooting.

## Overview

Raxol uses Ecto with PostgreSQL for data persistence, providing a robust and flexible database layer with enhanced error handling, connection management, and performance optimizations.

## Configuration

### Configuration Files

The database configuration is stored in the following files:

- `config/config.exs` - Common configuration
- `config/dev.exs` - Development environment configuration
- `config/test.exs` - Test environment configuration
- `config/prod.exs` - Production environment configuration

### Default Configuration

```elixir
config :raxol, Raxol.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "raxol_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  timeout: 15_000,
  idle_timeout: 30_000,
  retry_interval: 1_000,
  max_retries: 5
```

### Environment Variables

You can override these settings using environment variables:

```bash
# Database Configuration
RAXOL_DB_NAME=my_database
RAXOL_DB_USER=my_user
RAXOL_DB_PASS=my_password
RAXOL_DB_HOST=localhost

# Connection Settings
RAXOL_DB_POOL_SIZE=20
RAXOL_DB_TIMEOUT=30000
RAXOL_DB_IDLE_TIMEOUT=60000
```

## Database Setup

### Initial Setup

```bash
# Create database and run migrations
./scripts/setup_db.sh

# Reset database (drop and recreate)
./scripts/setup_db.sh --reset

# Run migrations only
mix ecto.migrate

# Rollback migrations
mix ecto.rollback
```

### Diagnostic Tools

```bash
# Check database connection
./scripts/check_db.exs

# Run full diagnostics
./scripts/diagnose_db.exs

# Check connection pool status
mix raxol.db.pool_status
```

## Architecture

### Connection Management

Raxol implements a sophisticated connection management system:

```elixir
# Connection Manager
Raxol.Database.ConnectionManager.start_link(opts)
Raxol.Database.ConnectionManager.get_connection()
Raxol.Database.ConnectionManager.release_connection(conn)

# Health Checks
Raxol.Database.ConnectionManager.check_health()
Raxol.Database.ConnectionManager.get_metrics()
```

Key features:

1. **Connection Pooling**

   - Dynamic pool sizing
   - Connection reuse
   - Automatic cleanup

2. **Error Handling**

   - Automatic retries
   - Error classification
   - Detailed logging

3. **Health Monitoring**
   - Connection health checks
   - Performance metrics
   - Resource usage tracking

### Database Operations

The `Raxol.Database` module provides a safe interface for all database operations:

```elixir
# Basic Operations
Raxol.Database.create(MySchema, attrs)
Raxol.Database.get(MySchema, id)
Raxol.Database.update(MySchema, record, attrs)
Raxol.Database.delete(record)

# Query Operations
Raxol.Database.all(MySchema)
Raxol.Database.get_by(MySchema, conditions)
Raxol.Database.first(MySchema, conditions)
Raxol.Database.last(MySchema, conditions)

# Transactions
Raxol.Database.transaction(fn ->
  # transaction operations
end)

# Multi-step Operations
Raxol.Database.multi(fn multi ->
  multi
  |> Raxol.Database.insert(:user, user_attrs)
  |> Raxol.Database.insert(:profile, profile_attrs)
end)
```

### Schema Definition

Example schema with common features:

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :name, :string
    field :age, :integer
    field :active, :boolean, default: true
    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :age, :active])
    |> validate_required([:email, :name])
    |> validate_format(:email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/)
    |> validate_number(:age, greater_than: 0)
    |> unique_constraint(:email)
  end
end
```

## Common Issues

### Connection Issues

**Symptoms**:

- "Could not connect to database" error
- Connection timeouts
- Pool exhaustion

**Solutions**:

1. Check PostgreSQL service: `brew services status postgresql`
2. Verify credentials in config
3. Check network connectivity
4. Adjust pool size and timeouts

### Performance Issues

**Symptoms**:

- Slow queries
- High CPU usage
- Connection pool exhaustion

**Solutions**:

1. Add appropriate indexes
2. Optimize query patterns
3. Use preloading for associations
4. Monitor and adjust pool size

### Migration Issues

**Symptoms**:

- Failed migrations
- Schema inconsistencies
- Data type mismatches

**Solutions**:

1. Check migration files
2. Use `mix ecto.migrations` to verify
3. Reset database if needed
4. Review schema changes

## Best Practices

1. **Schema Design**

   - Use appropriate data types
   - Add necessary indexes
   - Define proper constraints
   - Use timestamps for all records

2. **Query Optimization**

   - Use preloading for associations
   - Add indexes for frequent queries
   - Use transactions for related operations
   - Monitor query performance

3. **Error Handling**

   - Use transactions for atomic operations
   - Implement proper error handling
   - Log database errors
   - Use retry logic for transient errors

4. **Security**
   - Use parameterized queries
   - Validate input data
   - Implement proper access control
   - Secure sensitive data

## Monitoring and Maintenance

### Performance Monitoring

```elixir
# Get database metrics
Raxol.Database.get_metrics()

# Monitor query performance
Raxol.Database.enable_query_logging()

# Check connection pool status
Raxol.Database.get_pool_status()
```

### Maintenance Tasks

```bash
# Vacuum database
mix raxol.db.vacuum

# Analyze tables
mix raxol.db.analyze

# Check for deadlocks
mix raxol.db.check_deadlocks
```

## Adding New Features

When adding new database features:

1. Create a new migration
2. Define the schema
3. Add context functions
4. Write tests
5. Update documentation
6. Add monitoring

Example migration:

```elixir
defmodule MyApp.Repo.Migrations.AddUserPreferences do
  use Ecto.Migration

  def change do
    create table(:user_preferences) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :theme, :string
      add :notifications_enabled, :boolean, default: true
      timestamps()
    end

    create index(:user_preferences, [:user_id])
  end
end
```
