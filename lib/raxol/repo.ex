case Mix.env() do
  :test ->
    defmodule Raxol.Repo do
      @moduledoc false
      # Stub for test environment - implements basic Ecto.Repo callbacks to prevent errors

      @doc """
      Stub for custom_query in test environment.
      """
      def custom_query(_query) do
        {:ok, [%{result: "stub"}]}
      end

      @doc """
      Stub for get in test environment.
      Returns nil or a struct to satisfy Dialyzer type checking.
      """
      def get(schema, id, _opts \\ []) do
        # Return nil for nil id, otherwise return a stub struct
        # This helps Dialyzer understand both return types are possible
        case id do
          nil ->
            nil

          "not_found" ->
            nil

          _ ->
            # Return a basic struct that matches the schema
            case schema do
              Raxol.Web.Session.Session ->
                %Raxol.Web.Session.Session{
                  id: id,
                  user_id: "test_user",
                  metadata: %{},
                  created_at: DateTime.utc_now(),
                  updated_at: DateTime.utc_now()
                }

              _ ->
                # For other schemas, return nil
                nil
            end
        end
      end

      @doc """
      Stub for get_by in test environment.
      """
      def get_by(_schema, _clauses, _opts \\ []) do
        # Return nil for any get_by query in test environment
        nil
      end

      @doc """
      Stub for insert in test environment.
      """
      def insert(_changeset, _opts \\ []) do
        {:ok, %{id: "stub_id"}}
      end

      @doc """
      Stub for update in test environment.
      """
      def update(_changeset, _opts \\ []) do
        {:ok, %{id: "stub_id"}}
      end

      @doc """
      Stub for delete in test environment.
      """
      def delete(_struct, _opts \\ []) do
        {:ok, %{id: "stub_id"}}
      end

      @doc """
      Stub for all in test environment.
      """
      def all(_queryable, _opts \\ []) do
        []
      end

      @doc """
      Stub for query in test environment.
      """
      def query(_query, _params \\ [], _opts \\ []) do
        {:ok, %{rows: [], num_rows: 0}}
      end

      @doc """
      Stub for preload in test environment.
      """
      def preload(struct_or_structs, _preloads, _opts \\ []) do
        # Return the struct as-is since we're not actually loading associations
        case struct_or_structs do
          nil -> nil
          struct when is_map(struct) -> struct
          structs when is_list(structs) -> structs
          _ -> struct_or_structs
        end
      end

      @doc """
      Stub for checkout in test environment.
      """
      def checkout(fun, _opts \\ []) do
        # Execute the function directly without transaction
        fun.()
      end

      @doc """
      Stub for transaction in test environment.
      """
      def transaction(fun, _opts \\ []) do
        # Execute the function directly without transaction
        case fun.() do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> {:error, reason}
          result -> {:ok, result}
        end
      end

      @doc """
      Stub for rollback in test environment.
      """
      def rollback(value) do
        {:error, value}
      end

      @doc """
      Stub for aggregate in test environment.
      """
      def aggregate(_queryable, _aggregate, _field, _opts \\ []) do
        0
      end

      @doc """
      Stub for exists? in test environment.
      """
      def exists?(_queryable, _opts \\ []) do
        false
      end

      @doc """
      Stub for one in test environment.
      """
      def one(_queryable, _opts \\ []) do
        nil
      end

      @doc """
      Stub for stream in test environment.
      """
      def stream(_queryable, _opts \\ []) do
        []
      end

      @doc """
      Stub for update_all in test environment.
      """
      def update_all(_queryable, _updates, _opts \\ []) do
        {:ok, 0}
      end

      @doc """
      Stub for delete_all in test environment.
      """
      def delete_all(_queryable, _opts \\ []) do
        {:ok, 0}
      end

      @doc """
      Stub for insert_all in test environment.
      """
      def insert_all(_schema_or_source, _entries, _opts \\ []) do
        {:ok, []}
      end
    end

  _ ->
    defmodule Raxol.Repo do
      @moduledoc """
      Ecto repository for Raxol application.
      """

      use Ecto.Repo,
        otp_app: :raxol,
        adapter: Ecto.Adapters.Postgres

      @doc """
      Initialize the repository with custom configuration.
      """
      def init(_, config) do
        Raxol.Core.Runtime.Log.info_with_context(
          "Starting database connection with config: #{inspect(config)}",
          %{adapter: config[:adapter]}
        )

        # Apply any runtime configuration
        config = Keyword.put(config, :pool_size, 10)

        {:ok, config}
      end

      @doc """
      Execute a custom query.
      """
      def custom_query(query) do
        query(query)
      end
    end
end
