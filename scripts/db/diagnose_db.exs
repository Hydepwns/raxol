#!/usr/bin/env elixir

# Script to diagnose database connection issues
# Run with: mix run scripts/diagnose_db.exs

Mix.Task.run("loadpaths")
Raxol.Core.Runtime.Log.configure(level: :info)

IO.puts("===== Raxol Database Diagnostics =====\n")

# Get database config
db_config = Application.get_env(:raxol, Raxol.Repo)

# Check Postgres installation
IO.puts("Checking PostgreSQL installation...")
pg_version_cmd = System.cmd("psql", ["--version"], stderr_to_stdout: true)

case pg_version_cmd do
  {version, 0} ->
    IO.puts("[OK] PostgreSQL installed: #{String.trim(version)}")
  {error, _} ->
    IO.puts("[FAIL] PostgreSQL not properly installed: #{error}")
end

# Check if PostgreSQL is running
IO.puts("\nChecking if PostgreSQL server is running...")
pg_running_cmd = System.cmd("pg_isready", ["-h", db_config[:hostname] || "localhost"], stderr_to_stdout: true)

case pg_running_cmd do
  {output, 0} ->
    IO.puts("[OK] PostgreSQL is running: #{String.trim(output)}")
  {output, _} ->
    IO.puts("[FAIL] PostgreSQL is not running: #{String.trim(output)}")
    IO.puts("   Try starting PostgreSQL with: brew services start postgresql")
end

# Check if database exists
IO.puts("\nChecking if database exists...")
db_exists_cmd = System.cmd("psql", [
  "-h", db_config[:hostname] || "localhost",
  "-U", db_config[:username] || "postgres",
  "-c", "SELECT 1 FROM pg_database WHERE datname = '#{db_config[:database]}'",
  "postgres"
], stderr_to_stdout: true)

case db_exists_cmd do
  {output, 0} ->
    if String.contains?(output, "(1 row)") do
      IO.puts("[OK] Database '#{db_config[:database]}' exists")
    else
      IO.puts("[FAIL] Database '#{db_config[:database]}' does not exist")
      IO.puts("   Run: scripts/setup_db.sh to create it")
    end
  {error, _} ->
    IO.puts("[FAIL] Error checking database existence: #{error}")
end

# Try to connect to database using Ecto
IO.puts("\nTrying to connect to database using Raxol.Repo...")

try do
  {:ok, _} = Application.ensure_all_started(:postgrex)
  {:ok, _} = Application.ensure_all_started(:ecto_sql)

  # Start the Repo
  Raxol.Repo.start_link()

  # Test a simple query
  query_result = Raxol.Repo.custom_query("SELECT version();")

  case query_result do
    {:ok, result} ->
      IO.puts("[OK] Successfully connected to database")
      IO.puts("PostgreSQL version: #{List.first(result.rows) |> List.first()}")

      # Test migrations
      migrations_path = Path.join(["priv", "repo", "migrations"])
      migration_files = File.ls!(migrations_path)

      IO.puts("\nFound #{length(migration_files)} migration files")

      # Try to query the migrations table
      migrations_query = Raxol.Repo.custom_query("SELECT * FROM schema_migrations;")

      case migrations_query do
        {:ok, result} ->
          completed_migrations = length(result.rows)
          IO.puts("[OK] #{completed_migrations} migrations have been run")

          if completed_migrations < length(migration_files) do
            IO.puts("[WARN]  Not all migrations have been run. Run: mix ecto.migrate")
          end

        {:error, error} ->
          handle_postgres_error(error, "Migrations table not found. Run: mix ecto.migrate")
      end

    {:error, error} ->
      handle_postgres_error(error, "Error connecting to database")
  end
rescue
  error ->
    IO.puts("[FAIL] Error connecting to database: #{inspect(error)}")

    case error do
      # Handle other types of errors that might occur
      %DBConnection.ConnectionError{message: message} ->
        IO.puts("\nConnection Error: #{message}")
        IO.puts("\nSuggestion: Check if PostgreSQL is running and accessible")

      _ ->
        IO.puts("\nSuggestion: Check config/dev.exs for correct database settings")
    end
end

IO.puts("\n===== End of Database Diagnostics =====")

# Helper function to handle Postgres errors
defp handle_postgres_error(error, default_message) do
  IO.puts("[FAIL] #{default_message}")

  case error do
    %Postgrex.Error{postgres: %{code: code, message: message}} ->
      IO.puts("\nPostgres Error Code: #{code}")
      IO.puts("Postgres Message: #{message}")

      # Suggest solutions based on error code
      case code do
        "3D000" ->
          IO.puts("\nSuggestion: Database does not exist. Run: scripts/setup_db.sh")
        "28P01" ->
          IO.puts("\nSuggestion: Invalid username/password. Check config/dev.exs")
        "08006" ->
          IO.puts("\nSuggestion: Could not connect to server. Is PostgreSQL running?")
        "42P01" ->
          IO.puts("\nSuggestion: Table does not exist. Run migrations: mix ecto.migrate")
        _ ->
          IO.puts("\nSuggestion: Check PostgreSQL logs for more details")
      end

    _ ->
      IO.puts("\nError: #{inspect(error)}")
      IO.puts("\nSuggestion: Check database configuration and connection settings")
  end
end

# Ensure the script exits properly
System.halt(0)
