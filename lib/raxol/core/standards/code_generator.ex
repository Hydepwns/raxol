defmodule Raxol.Core.Standards.CodeGenerator do
  @moduledoc """
  Code generation templates following Raxol coding standards.

  Provides functions to generate consistent code structures for common patterns.
  """

  @doc """
  Generates a new GenServer module following standards.
  """
  def generate_genserver(module_name, opts \\ []) do
    description = Keyword.get(opts, :description, "GenServer implementation")
    state_fields = Keyword.get(opts, :state_fields, [:data])
    callbacks = Keyword.get(opts, :callbacks, [:start_link, :init])

    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      #{description}

      ## State

      The GenServer maintains the following state:
      #{format_state_docs(state_fields)}
      \"\"\"

      use Raxol.Core.Behaviours.BaseManager
      require Logger

      # Type definitions
      @type state :: %{
        #{format_state_types(state_fields)}
      }

      # Public API

      @doc \"\"\"
      Starts the GenServer process.

      ## Options

      - `:name` - Registered name for the process (optional)
      #{_format_option_docs(opts)}

      ## Examples

          iex> {:ok, pid} = #{module_name}.start_link()
          iex> is_pid(pid)
          true
      \"\"\"
      @spec start_link(keyword()) :: GenServer.on_start()
#       def start_link(opts \\\\ []) do
#         GenServer.start_link(__MODULE__, opts, name: opts[:name])
#       end

      #{_generate_public_api(module_name, callbacks)}

      # GenServer callbacks

      @impl true
      def init_manager(opts) do
        state = %{
          #{_format_initial_state(state_fields, opts)}
        }

        Logger.info("#{module_name} started with options: \#{inspect(opts)}")
        {:ok, state}
      end

      #{_generate_callbacks(callbacks)}

      # Private functions

      #{_generate_private_helpers(module_name, state_fields)}
    end
    """
  end

  @doc """
  Generates a new supervisor module.
  """
  def generate_supervisor(module_name, children \\ []) do
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Supervisor for managing child processes.

      ## Children

      #{format_children_docs(children)}
      \"\"\"

      use Supervisor

      @doc \"\"\"
      Starts the supervisor.
      \"\"\"
      @spec start_link(keyword()) :: Supervisor.on_start()
#       def start_link(opts \\\\ []) do
#         Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
#       end

      @impl true
      def init_manager(_opts) do
        children = [
          #{format_children_specs(children)}
        ]

        opts = [strategy: :one_for_one]
        Supervisor.init(children, opts)
      end
    end
    """
  end

  @doc """
  Generates a context module for business logic.
  """
  def generate_context(module_name, functions \\ []) do
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Business logic context for #{context_name(module_name)}.

      This module provides the public API for #{context_name(module_name)} operations.
      \"\"\"

      import Ecto.Query, warn: false
      alias Raxol.Repo

      #{generate_context_functions(functions)}

      # Private functions

      defp validate_params(params, required_fields) do
        missing_fields = required_fields -- Map.keys(params)
        do_validate_params(missing_fields, params)
      end

      defp do_validate_params([], params), do: {:ok, params}
      defp do_validate_params(missing_fields, _params) do
        {:error, {:missing_fields, missing_fields}}
      end

      defp handle_operation_result({:ok, result}), do: {:ok, result}
      defp handle_operation_result({:error, changeset}), do: {:error, format_errors(changeset)}

      defp format_errors(%Ecto.Changeset{} = changeset) do
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{\#{key}}", to_string(value))
          end)
        end)
      end
      defp format_errors(error), do: error
    end
    """
  end

  @doc """
  Generates a test module template.
  """
  def generate_test(module_name, test_cases \\ []) do
    """
    defmodule #{module_name}Test do
      use ExUnit.Case, async: true

      alias #{module_name}

      describe "module initialization" do
        test "module is loaded correctly" do
          assert Code.ensure_loaded?(#{module_name})
        end
      end

      #{generate_test_cases(module_name, test_cases)}
    end
    """
  end

  @doc """
  Generates a LiveView module.
  """
  def generate_liveview(module_name, opts \\ []) do
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      LiveView for #{liveview_name(module_name)}.
      \"\"\"

      use RaxolWeb, :live_view

      alias Phoenix.LiveView.Socket

      @impl true
      def mount(params, session, socket) do
        socket =
          socket
          |> assign(:page_title, "#{liveview_name(module_name)}")
          |> assign_defaults(params, session)

        {:ok, socket}
      end

      @impl true
      def handle_params(params, _url, socket) do
        {:noreply, apply_action(socket, socket.assigns.live_action, params)}
      end

      @impl true
      def render(assigns) do
        ~H\"\"\"
        <div class="#{module_class_name(module_name)}">
          <.header>
            <%= @page_title %>
          </.header>

          <div class="content">
            <%= render_content(assigns) %>
          </div>
        </div>
        \"\"\"
      end

      #{generate_liveview_handlers(opts)}

      # Private functions

      defp assign_defaults(socket, _params, _session) do
        socket
      end

      defp apply_action(socket, :index, _params) do
        socket
      end

      defp render_content(assigns) do
        ~H\"\"\"
        <p>Content goes here</p>
        \"\"\"
      end
    end
    """
  end

  @doc """
  Generates a migration template.
  """
  def generate_migration(name, operations \\ []) do
    _timestamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d%H%M%S")

    """
    defmodule Raxol.Repo.Migrations.#{Macro.camelize(name)} do
      use Ecto.Migration

      def change do
        #{format_migration_operations(operations)}
      end

      # Optional: Define up and down for complex migrations
      # def up do
      #   execute("complex SQL")
      # end
      #
      # def down do
      #   execute("rollback SQL")
      # end
    end
    """
  end

  @doc """
  Generates a schema module.
  """
  def generate_schema(module_name, table_name, fields \\ []) do
    """
    defmodule #{module_name} do
      @moduledoc \"\"\"
      Schema for #{table_name} table.
      \"\"\"

      use Ecto.Schema
      import Ecto.Changeset

      @type t :: %__MODULE__{
        #{format_schema_types(fields)}
      }

      schema "#{table_name}" do
        #{format_schema_fields(fields)}

        timestamps()
      end

      @doc \"\"\"
      Creates a changeset for #{schema_name(module_name)}.
      \"\"\"
      @spec changeset(t(), map()) :: Ecto.Changeset.t()
      def changeset(#{schema_var(module_name)}, attrs) do
        #{schema_var(module_name)}
        |> cast(attrs, #{format_cast_fields(fields)})
        |> validate_required(#{format_required_fields(fields)})
        #{format_validations(fields)}
      end
    end
    """
  end

  # Private helper functions

  @spec format_state_docs(any()) :: String.t()
  defp format_state_docs(fields) do
    fields
    |> Enum.map_join("\n", fn field ->
      "  - `#{field}` - Description of #{field}"
    end)
  end

  @spec format_state_types(any()) :: String.t()
  defp format_state_types(fields) do
    fields
    |> Enum.map_join(
      ",\n        ",
      fn field ->
        "#{field}: term()"
      end
    )
  end

  @spec _format_option_docs(keyword()) :: any()
  defp _format_option_docs(_opts) do
    # Additional option documentation
    ""
  end

  @spec _format_initial_state(any(), keyword()) :: any()
  defp _format_initial_state(fields, _opts) do
    fields
    |> Enum.map_join(
      ",\n          ",
      fn field ->
        "#{field}: nil"
      end
    )
  end

  @spec _generate_public_api(module(), any()) :: any()
  defp _generate_public_api(_module_name, callbacks) do
    Enum.map_join(
      callbacks,
      "\n",
      fn
        :get_state ->
          """
          @doc \"\"\"
          Gets the current state.
          \"\"\"
          @spec get_state(GenServer.server()) :: {:ok, state()}
          def get_state(server) do
            GenServer.call(server, :get_state)
          end
          """

        :update ->
          """
          @doc \"\"\"
          Updates the state with new data.
          \"\"\"
          @spec update(GenServer.server(), map()) :: :ok | {:error, term()}
          def update(server, data) do
            GenServer.call(server, {:update, data})
          end
          """

        _ ->
          ""
      end
    )
  end

  @spec _generate_callbacks(any()) :: any()
  defp _generate_callbacks(callbacks) do
    callback_impls =
      Enum.map_join(callbacks, "\n\n", fn
        :get_state ->
          """
          @impl true
          def handle_manager_call(:get_state, _from, state) do
            {:reply, {:ok, state}, state}
          end
          """

        :update ->
          """
          @impl true
          def handle_manager_call({:update, data}, _from, state) do
            case validate_update(data) do
              {:ok, valid_data} ->
                new_state = Map.merge(state, valid_data)
                {:reply, :ok, new_state}

              {:error, reason} = error ->
                {:reply, error, state}
            end
          end
          """

        _ ->
          ""
      end)

    Enum.join(callback_impls, "\n")
  end

  @spec _generate_private_helpers(module(), any()) :: any()
  defp _generate_private_helpers(_module_name, _fields) do
    """
    defp validate_update(data) when is_map(data) do
      {:ok, data}
    end

    defp validate_update(_data) do
      {:error, :invalid_data}
    end
    """
  end

  @spec format_children_docs(any()) :: String.t()
  defp format_children_docs([]), do: "No children defined yet."

  @spec format_children_docs(any()) :: String.t()
  defp format_children_docs(children) do
    Enum.map_join(children, "\n", fn child -> "  - #{child}" end)
  end

  @spec format_children_specs(any()) :: String.t()
  defp format_children_specs([]), do: "# Add child specifications here"

  @spec format_children_specs(any()) :: String.t()
  defp format_children_specs(children) do
    Enum.map_join(children, ",\n          ", fn child -> "{#{child}, []}" end)
  end

  @spec context_name(module()) :: any()
  defp context_name(module_name) do
    module_name
    |> String.split(".")
    |> List.last()
    |> String.replace("Context", "")
  end

  @spec generate_context_functions(atom()) :: any()
  defp generate_context_functions(functions) do
    Enum.map_join(functions, "\n\n", fn {name, opts} ->
      """
      @doc \"\"\"
      #{Keyword.get(opts, :doc, "Performs #{name} operation")}
      \"\"\"
      @spec #{name}(map()) :: {:ok, term()} | {:error, term()}
      def #{name}(params) do
        with {:ok, valid_params} <- validate_params(params, #{inspect(Keyword.get(opts, :required, []))}) do
          # Implementation here
          {:ok, :result}
        end
      end
      """
    end)
  end

  @spec generate_test_cases(module(), any()) :: any()
  defp generate_test_cases(_module_name, []) do
    """
    describe "basic functionality" do
      test "placeholder test" do
        assert true
      end
    end
    """
  end

  @spec generate_test_cases(module(), any()) :: any()
  defp generate_test_cases(_module_name, test_cases) do
    Enum.map_join(
      test_cases,
      "\n",
      fn {function, tests} ->
        """
        describe "#{function}/#{length(tests)}" do
          #{format_tests(function, tests)}
        end
        """
      end
    )
  end

  @spec format_tests(atom(), any()) :: String.t()
  defp format_tests(_function, tests) do
    Enum.map_join(
      tests,
      "\n",
      fn test_name ->
        """
        test "#{test_name}" do
          # Test implementation
          assert true
        end
        """
      end
    )
  end

  @spec liveview_name(module()) :: any()
  defp liveview_name(module_name) do
    module_name
    |> String.split(".")
    |> List.last()
    |> String.replace("Live", "")
  end

  @spec module_class_name(module()) :: any()
  defp module_class_name(module_name) do
    module_name
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
    |> String.replace("_", "-")
  end

  @spec generate_liveview_handlers(keyword()) :: any()
  defp generate_liveview_handlers(opts) do
    handlers = Keyword.get(opts, :handlers, [:form_change, :form_submit])

    Enum.map_join(
      handlers,
      "\n\n",
      fn
        :form_change ->
          """
          @impl true
          def handle_event("form_change", %{"form" => params}, socket) do
            changeset = build_changeset(params)
            {:noreply, assign(socket, changeset: changeset)}
          end
          """

        :form_submit ->
          """
          @impl true
          def handle_event("form_submit", %{"form" => params}, socket) do
            case save_form(params) do
              {:ok, _result} ->
                {:noreply,
                 socket
                 |> put_flash(:info, "Saved successfully")
                 |> push_navigate(to: ~p"/")}

              {:error, changeset} ->
                {:noreply, assign(socket, changeset: changeset)}
            end
          end
          """

        _ ->
          ""
      end
    )
  end

  @spec format_migration_operations(any()) :: String.t()
  defp format_migration_operations([]) do
    """
    create table(:example) do
      add :name, :string, null: false
      add :description, :text

      timestamps()
    end

    create index(:example, [:name])
    """
  end

  @spec format_migration_operations(any()) :: String.t()
  defp format_migration_operations(operations) do
    Enum.map_join(
      operations,
      "\n\n    ",
      fn
        {:create_table, name, fields} ->
          """
          create table(:#{name}) do
            #{format_table_fields(fields)}

            timestamps()
          end
          """

        {:add_index, table, columns} ->
          "create index(:#{table}, #{inspect(columns)})"

        {:add_column, _table, column, type} ->
          "add :#{column}, :#{type}"

        _ ->
          "# Add migration operations"
      end
    )
  end

  @spec format_table_fields(any()) :: String.t()
  defp format_table_fields(fields) do
    fields
    |> Enum.map_join("\n      ", fn {name, type, opts} ->
      opts_str = format_field_opts(opts)
      "add :#{name}, :#{type}#{opts_str}"
    end)
  end

  @spec format_field_opts(any()) :: String.t()
  defp format_field_opts([]), do: ""

  @spec format_field_opts(keyword()) :: String.t()
  defp format_field_opts(opts) do
    ", " <> Enum.map_join(opts, ", ", fn {k, v} -> "#{k}: #{inspect(v)}" end)
  end

  @spec schema_name(module()) :: any()
  defp schema_name(module_name) do
    module_name
    |> String.split(".")
    |> List.last()
  end

  @spec schema_var(module()) :: any()
  defp schema_var(module_name) do
    module_name
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
  end

  @spec format_schema_types(any()) :: String.t()
  defp format_schema_types(fields) do
    fields
    |> Enum.map_join(",\n        ", fn {name, type, _opts} ->
      "#{name}: #{elixir_type(type)}"
    end)
  end

  @spec format_schema_fields(any()) :: String.t()
  defp format_schema_fields(fields) do
    fields
    |> Enum.map_join("\n    ", fn {name, type, _opts} ->
      "field :#{name}, :#{type}"
    end)
  end

  @spec format_cast_fields(any()) :: String.t()
  defp format_cast_fields(fields) do
    fields
    |> Enum.map_join(fn {name, _type, _opts} -> ":#{name}" end)
    |> inspect()
  end

  @spec format_required_fields(any()) :: String.t()
  defp format_required_fields(fields) do
    fields
    |> Enum.filter(fn {_name, _type, opts} ->
      Keyword.get(opts, :required, false)
    end)
    |> Enum.map(fn {name, _type, _opts} -> ":#{name}" end)
    |> inspect()
  end

  @spec format_validations(any()) :: String.t()
  defp format_validations(fields) do
    fields
    |> Enum.flat_map(fn {name, type, opts} ->
      []
      |> add_min_length_validation(name, opts)
      |> add_max_length_validation(name, opts)
      |> add_email_validation(name, type)
    end)
    |> Enum.join("\n    ")
  end

  @spec add_min_length_validation(
          String.t() | integer(),
          String.t() | atom(),
          keyword()
        ) :: any()
  defp add_min_length_validation(validations, name, opts) do
    case Keyword.get(opts, :min_length) do
      nil -> validations
      length -> ["|> validate_length(:#{name}, min: #{length})" | validations]
    end
  end

  @spec add_max_length_validation(
          String.t() | integer(),
          String.t() | atom(),
          keyword()
        ) :: any()
  defp add_max_length_validation(validations, name, opts) do
    case Keyword.get(opts, :max_length) do
      nil -> validations
      length -> ["|> validate_length(:#{name}, max: #{length})" | validations]
    end
  end

  @spec add_email_validation(String.t() | integer(), String.t() | atom(), any()) ::
          any()
  defp add_email_validation(validations, name, :email) do
    ["|> validate_format(:#{name}, ~r/@/)" | validations]
  end

  @spec add_email_validation(String.t() | integer(), String.t() | atom(), any()) ::
          any()
  defp add_email_validation(validations, _name, _type), do: validations

  @spec elixir_type(any()) :: any()
  defp elixir_type(:string), do: "String.t()"
  @spec elixir_type(any()) :: any()
  defp elixir_type(:integer), do: "integer()"
  @spec elixir_type(any()) :: any()
  defp elixir_type(:boolean), do: "boolean()"
  @spec elixir_type(any()) :: any()
  defp elixir_type(:datetime), do: "DateTime.t()"
  @spec elixir_type(any()) :: any()
  defp elixir_type(:date), do: "Date.t()"
  @spec elixir_type(any()) :: any()
  defp elixir_type(:decimal), do: "Decimal.t()"
  @spec elixir_type(any()) :: any()
  defp elixir_type(:float), do: "float()"
  @spec elixir_type(any()) :: any()
  defp elixir_type(:uuid), do: "String.t()"
  @spec elixir_type(any()) :: any()
  defp elixir_type(_), do: "term()"
end
