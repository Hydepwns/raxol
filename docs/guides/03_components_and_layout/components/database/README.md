# Raxol Database Documentation

This document provides information about the database setup, configuration, and how to troubleshoot common issues.

## Configuration

The database configuration is stored in the following files:

- `config/config.exs` - Common configuration
- `config/dev.exs` - Development environment configuration
- `config/test.exs` - Test environment configuration
- `config/prod.exs` - Production environment configuration

The default development configuration is:

```elixir
config :raxol, Raxol.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "raxol_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
```

You can override these settings using environment variables:

- `RAXOL_DB_NAME` - Database name
- `RAXOL_DB_USER` - Database username
- `RAXOL_DB_PASS` - Database password
- `RAXOL_DB_HOST` - Database hostname

## Database Setup

### Initial Setup

Run the setup script to create the database and run migrations:

```bash
./scripts/setup_db.sh
```

### Reset Database

To reset the database (drop and recreate):

```bash
./scripts/setup_db.sh --reset
```

### Diagnostic Tools

The following scripts are available to diagnose database issues:

- `scripts/check_db.exs` - Simple standalone database connection check
- `scripts/diagnose_db.exs` - Full diagnostic tool (requires application startup)

## Architecture

### Connection Management

Raxol uses a robust connection management system to handle database connections:

- `Raxol.Database.ConnectionManager` - Manages database connections with retry logic
- `Raxol.Database` - Provides a safe interface for database operations
- `Raxol.Repo` - Ecto repository with enhanced logging and error handling

Key features:

1. **Connection Retries**: Automatic retries for transient database errors
2. **Error Classification**: Categorizes errors as retryable or non-retryable
3. **Exponential Backoff**: Uses exponential backoff for connection retries
4. **Health Checks**: Periodic health checks to ensure database connectivity
5. **Detailed Logging**: Enhanced logging for database operations
6. **Safe Interfaces**: Wraps database operations with error handling

### Database Operations

All database operations should use the `Raxol.Database` module, which provides safe functions with retry logic:

```elixir
# Create a record
Raxol.Database.create(MySchema, attrs)

# Get a record
Raxol.Database.get(MySchema, id)

# Update a record
Raxol.Database.update(MySchema, record, attrs)

# Delete a record
Raxol.Database.delete(record)

# Execute a transaction
Raxol.Database.transaction(fn ->
  # transaction operations
end)
```

## Common Issues

### Could not connect to database

**Symptoms**:

- "Could not connect to database" error
- Postgrex connection errors

**Possible Causes**:

1. PostgreSQL service is not running
2. Incorrect database credentials
3. Database does not exist
4. Network connectivity issues

**Solutions**:

1. Start PostgreSQL: `brew services start postgresql`
2. Check credentials in `config/dev.exs`
3. Run setup script: `./scripts/setup_db.sh`
4. Check network connectivity and firewall settings

### Connection Pooling Issues

**Symptoms**:

- "Connection refused" errors under load
- Timeouts during peak usage

**Possible Causes**:

1. Pool size too small
2. Long-running queries
3. Connection leaks

**Solutions**:

1. Increase pool size in config
2. Optimize queries
3. Run the diagnostic script to check for connection issues

### Migration Errors

**Symptoms**:

- "Migration failed" errors
- Table/column does not exist errors

**Solutions**:

1. Reset database: `./scripts/setup_db.sh --reset`
2. Check migration files for errors
3. Run migrations manually: `mix ecto.migrate`

## Adding New Schemas

When adding new schemas or migrations:

1. Create a migration file with `mix ecto.gen.migration`
2. Define the schema in a dedicated module
3. Add context functions in the appropriate context module
4. Use `Raxol.Database` functions for all database operations
5. Run tests to verify the schema works as expected
6. Document the schema in this file

## Performance Tips

1. Use `Ecto.Multi` for transactional operations
2. Add indexes for frequently queried fields
3. Use preloading for associations to avoid N+1 queries
4. Consider using database views for complex reports
5. Monitor query performance with the provided logging
