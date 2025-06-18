defmodule Raxol.Repo do
  use Ecto.Repo,
    otp_app: :raxol,
    adapter: Ecto.Adapters.Postgres

  require Raxol.Core.Runtime.Log

  @doc '''
  Initializes the repository.

  ## Overrides

  This function is called when the repo is started. It adds improved logging
  around database connection events.
  '''
  def init(_, config) do
    # Apply runtime configuration if needed
    config = apply_runtime_config(config)

    # Log database connection info (hide sensitive data)
    safe_config = Keyword.drop(config, [:password])

    Raxol.Core.Runtime.Log.info(
      "Starting database connection with config: #{inspect(safe_config)}"
    )

    # Set better default timeouts
    config =
      config
      |> Keyword.put_new(:timeout, 15_000)
      |> Keyword.put_new(:connect_timeout, 5_000)
      |> Keyword.put_new(:pool_timeout, 10_000)

    {:ok, config}
  end

  # Apply runtime configuration
  defp apply_runtime_config(config) do
    # Example: Override database name from environment variable if present
    database_url = System.get_env("DATABASE_URL")

    if database_url do
      Keyword.put(config, :url, database_url)
    else
      config
    end
  end

  @doc '''
  Executes raw SQL query with logging.

  This adds better error handling and logging around raw SQL queries.

  ## Returns

  * `{:ok, result}` - on success
  * `{:error, exception}` - on failure
  '''
  def custom_query(sql, params \\ [], opts \\ []) do
    Raxol.Core.Runtime.Log.debug(
      "Executing SQL: #{sql}, params: #{inspect(params)}"
    )

    start_time = System.monotonic_time(:millisecond)

    try do
      # Call the original implementation directly
      result = Ecto.Adapters.SQL.query(__MODULE__, sql, params, opts)

      execution_time = System.monotonic_time(:millisecond) - start_time

      case result do
        {:ok, _} ->
          Raxol.Core.Runtime.Log.debug(
            "SQL executed successfully in #{execution_time}ms"
          )

        {:error, error} ->
          Raxol.Core.Runtime.Log.error(
            "SQL error after #{execution_time}ms: #{inspect(error)}"
          )
      end

      result
    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time

        Raxol.Core.Runtime.Log.error(
          "SQL error after #{execution_time}ms: #{inspect(error)}"
        )

        {:error, error}
    end
  end

  @doc '''
  Executes raw SQL query with logging, raising on errors.

  This adds better error handling and logging around raw SQL queries.
  '''
  def custom_query!(sql, params \\ [], opts \\ []) do
    Raxol.Core.Runtime.Log.debug(
      "Executing SQL: #{sql}, params: #{inspect(params)}"
    )

    start_time = System.monotonic_time(:millisecond)

    try do
      # Call the original implementation directly
      result = Ecto.Adapters.SQL.query!(__MODULE__, sql, params, opts)

      execution_time = System.monotonic_time(:millisecond) - start_time

      Raxol.Core.Runtime.Log.debug(
        "SQL executed successfully in #{execution_time}ms"
      )

      result
    rescue
      error ->
        execution_time = System.monotonic_time(:millisecond) - start_time

        Raxol.Core.Runtime.Log.error(
          "SQL error after #{execution_time}ms: #{inspect(error)}"
        )

        reraise error, __STACKTRACE__
    end
  end
end
