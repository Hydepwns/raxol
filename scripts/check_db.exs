#!/usr/bin/env elixir

# Simple script to check database connection
# Bypasses the full application startup
# Run with: elixir scripts/check_db.exs

IO.puts("===== Raxol Database Connection Check =====\n")

# Get database config from environment
db_name = System.get_env("RAXOL_DB_NAME") || "raxol_dev"
db_user = System.get_env("RAXOL_DB_USER") || "postgres"
db_pass = System.get_env("RAXOL_DB_PASS") || "postgres"
db_host = System.get_env("RAXOL_DB_HOST") || "localhost"

IO.puts("Database configuration:")
IO.puts("  Database: #{db_name}")
IO.puts("  User: #{db_user}")
IO.puts("  Host: #{db_host}")
IO.puts("")

# Check if PostgreSQL is running
IO.puts("\nChecking if PostgreSQL server is running...")

pg_running =
  try do
    {output, status} = System.cmd("pg_isready", ["-h", db_host], stderr_to_stdout: true)

    case status do
      0 ->
        IO.puts("✅ PostgreSQL is running: #{String.trim(output)}")
        true
      _ ->
        IO.puts("❌ PostgreSQL is not running: #{String.trim(output)}")
        IO.puts("   Try starting PostgreSQL with: brew services start postgresql")
        false
    end
  rescue
    e ->
      IO.puts("❌ Could not check PostgreSQL status: #{inspect(e)}")
      false
  end

# Check if database exists
if pg_running do
  IO.puts("\nChecking if database exists...")

  db_exists =
    try do
      args = [
        "-h", db_host,
        "-U", db_user,
        "-c", "SELECT 1 FROM pg_database WHERE datname = '#{db_name}'",
        "postgres"
      ]

      System.put_env("PGPASSWORD", db_pass)
      {output, status} = System.cmd("psql", args, stderr_to_stdout: true)
      System.delete_env("PGPASSWORD")

      if status == 0 && String.contains?(output, "(1 row)") do
        IO.puts("✅ Database '#{db_name}' exists")
        true
      else
        IO.puts("❌ Database '#{db_name}' does not exist")
        IO.puts("   Run: scripts/setup_db.sh to create it")
        false
      end
    rescue
      e ->
        IO.puts("❌ Error checking database existence: #{inspect(e)}")
        false
    end

  # Try a direct connection via Postgrex
  if db_exists do
    IO.puts("\nTrying to connect directly with Postgrex...")

    try do
      Mix.install([
        {:postgrex, "~> 0.17.1"}
      ])

      # Connect to PostgreSQL
      opts = [
        hostname: db_host,
        username: db_user,
        password: db_pass,
        database: db_name
      ]

      case Postgrex.start_link(opts) do
        {:ok, conn} ->
          # Try a simple query
          case Postgrex.query(conn, "SELECT version();", []) do
            {:ok, result} ->
              version = result.rows |> List.first() |> List.first()
              IO.puts("✅ Successfully connected to database")
              IO.puts("PostgreSQL version: #{version}")

              # Check schema_migrations table
              case Postgrex.query(conn, "SELECT count(*) FROM schema_migrations;", []) do
                {:ok, result} ->
                  count = result.rows |> List.first() |> List.first()
                  IO.puts("✅ Found #{count} completed migrations")

                {:error, error} ->
                  IO.puts("❌ Could not check migrations: #{inspect(error)}")
                  IO.puts("   Run: mix ecto.migrate to set up the database schema")
              end

            {:error, error} ->
              IO.puts("❌ Query failed: #{inspect(error)}")
          end

          # Close the connection
          Process.exit(conn, :normal)

        {:error, error} ->
          IO.puts("❌ Connection failed: #{inspect(error)}")

          # Safely inspect error details without matching on Postgrex.Error struct
          error_map = inspect(error)
          IO.puts("Error details: #{error_map}")

          # Try to extract helpful information based on the error string representation
          cond do
            String.contains?(error_map, "3D000") ->
              IO.puts("\nSuggestion: Database does not exist. Run: scripts/setup_db.sh")
            String.contains?(error_map, "28P01") ->
              IO.puts("\nSuggestion: Invalid username/password. Check config/dev.exs")
            String.contains?(error_map, "08006") ->
              IO.puts("\nSuggestion: Could not connect to server. Is PostgreSQL running?")
            true ->
              IO.puts("\nSuggestion: Check database configuration in config/dev.exs")
          end
      end
    rescue
      e -> IO.puts("❌ Postgrex error: #{inspect(e)}")
    end
  end
end

IO.puts("\n===== End of Database Check =====")
