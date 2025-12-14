defmodule Raxol.Playground.Scenarios do
  @moduledoc """
  Real-world guided scenarios for the Raxol playground.

  Provides step-by-step interactive guides for building common UI patterns.
  Each scenario demonstrates practical component composition.

  ## Examples

      # List available scenarios
      iex> Scenarios.list()
      [:login_form, :dashboard, :settings_page, :data_table, :wizard]

      # Get scenario details
      iex> Scenarios.get(:login_form)
      %{id: :login_form, title: "Login Form", tagline: "Build in 30 seconds", ...}

      # Run a scenario interactively
      iex> Scenarios.run(:login_form)
      Building: Login Form (30 seconds)
      Step 1/3: Adding email input...
      ...
  """

  alias Raxol.Playground.Builder

  @type step ::
          {:add, atom(), map()}
          | {:configure, atom(), map()}
          | {:connect, atom(), atom()}

  @type scenario :: %{
          id: atom(),
          title: String.t(),
          tagline: String.t(),
          description: String.t(),
          steps: [step()],
          result_preview: String.t()
        }

  # ============================================================================
  # Scenario Definitions
  # ============================================================================

  @scenarios [
    %{
      id: :login_form,
      title: "Login Form",
      tagline: "Build in 30 seconds",
      description:
        "Create a complete login form with email, password, and submit button.",
      steps: [
        {:add, :text_input,
         %{label: "Email", placeholder: "you@example.com", type: :email}},
        {:add, :text_input,
         %{label: "Password", placeholder: "********", type: :password}},
        {:add, :button, %{label: "Sign In", variant: :primary}}
      ],
      result_preview: """
      +--[ Login ]------------------+
      |                             |
      |  Email                      |
      |  +------------------------+ |
      |  | you@example.com      | |
      |  +------------------------+ |
      |                             |
      |  Password                   |
      |  +------------------------+ |
      |  | ********              | |
      |  +------------------------+ |
      |                             |
      |  [ Sign In ]                |
      |                             |
      +-----------------------------+
      """
    },
    %{
      id: :dashboard,
      title: "Analytics Dashboard",
      tagline: "Build in 2 minutes",
      description:
        "Create a dashboard with progress indicators, stats, and a data table.",
      steps: [
        {:add, :heading, %{text: "Dashboard", level: 1}},
        {:add, :progress_bar,
         %{value: 67, label: "Monthly Goal", color: :green}},
        {:add, :progress_bar,
         %{value: 45, label: "Weekly Target", color: :blue}},
        {:add, :table, %{columns: ["Metric", "Value", "Change"], rows: 5}}
      ],
      result_preview: """
      +--[ Dashboard ]----------------------------------+
      |                                                 |
      |  Monthly Goal                                   |
      |  [==================>         ] 67%             |
      |                                                 |
      |  Weekly Target                                  |
      |  [============>               ] 45%             |
      |                                                 |
      |  +------------+--------+--------+               |
      |  | Metric     | Value  | Change |               |
      |  +------------+--------+--------+               |
      |  | Users      | 1,234  | +12%   |               |
      |  | Revenue    | $5,678 | +8%    |               |
      |  +------------+--------+--------+               |
      |                                                 |
      +-------------------------------------------------+
      """
    },
    %{
      id: :settings_page,
      title: "Settings Page",
      tagline: "Build in 1 minute",
      description:
        "Create a settings page with toggles, selects, and action buttons.",
      steps: [
        {:add, :heading, %{text: "Settings", level: 1}},
        {:add, :toggle, %{label: "Dark Mode", checked: true}},
        {:add, :toggle, %{label: "Notifications", checked: false}},
        {:add, :select,
         %{label: "Language", options: ["English", "Spanish", "French"]}},
        {:add, :button, %{label: "Save Changes", variant: :primary}}
      ],
      result_preview: """
      +--[ Settings ]-------------------+
      |                                 |
      |  Dark Mode          [*] ON     |
      |  Notifications      [ ] OFF    |
      |                                 |
      |  Language                       |
      |  +------------------+           |
      |  | English        v |           |
      |  +------------------+           |
      |                                 |
      |  [ Save Changes ]               |
      |                                 |
      +---------------------------------+
      """
    },
    %{
      id: :data_table,
      title: "Data Table",
      tagline: "Build in 45 seconds",
      description: "Create a sortable data table with pagination controls.",
      steps: [
        {:add, :table,
         %{
           columns: ["Name", "Email", "Role", "Status"],
           sortable: true,
           rows: 10
         }},
        {:add, :pagination, %{total_pages: 5, current: 1}}
      ],
      result_preview: """
      +--[ Users ]----------------------------------------+
      | Name           | Email              | Role   | S |
      +----------------+--------------------+--------+---+
      | Alice Johnson  | alice@example.com  | Admin  | * |
      | Bob Smith      | bob@example.com    | User   | * |
      | Carol White    | carol@example.com  | Editor | - |
      +----------------+--------------------+--------+---+
      |                                                   |
      |  < Prev  [ 1 ] 2  3  4  5  Next >                 |
      +---------------------------------------------------+
      """
    },
    %{
      id: :wizard,
      title: "Multi-Step Wizard",
      tagline: "Build in 2 minutes",
      description: "Create a multi-step form wizard with progress indicator.",
      steps: [
        {:add, :steps, %{items: ["Account", "Profile", "Confirm"], current: 1}},
        {:add, :text_input, %{label: "Full Name", placeholder: "John Doe"}},
        {:add, :text_input, %{label: "Email", placeholder: "john@example.com"}},
        {:add, :button, %{label: "Back", variant: :secondary}},
        {:add, :button, %{label: "Next", variant: :primary}}
      ],
      result_preview: """
      +--[ Create Account ]--------------------------+
      |                                              |
      |  (1)-----(2)-----(3)                         |
      |  Account Profile  Confirm                   |
      |  [*]     [ ]      [ ]                       |
      |                                              |
      |  Full Name                                   |
      |  +---------------------------------------+   |
      |  | John Doe                             |   |
      |  +---------------------------------------+   |
      |                                              |
      |  Email                                       |
      |  +---------------------------------------+   |
      |  | john@example.com                     |   |
      |  +---------------------------------------+   |
      |                                              |
      |  [ Back ]                  [ Next ]         |
      |                                              |
      +----------------------------------------------+
      """
    },
    %{
      id: :modal_dialog,
      title: "Modal Dialog",
      tagline: "Build in 20 seconds",
      description:
        "Create a modal dialog with title, content, and action buttons.",
      steps: [
        {:add, :modal, %{title: "Confirm Action", open: true}},
        {:add, :text, %{content: "Are you sure you want to proceed?"}},
        {:add, :button, %{label: "Cancel", variant: :secondary}},
        {:add, :button, %{label: "Confirm", variant: :primary}}
      ],
      result_preview: """
      +================================+
      |  Confirm Action            [x] |
      +--------------------------------+
      |                                |
      |  Are you sure you want to      |
      |  proceed?                      |
      |                                |
      |  [ Cancel ]     [ Confirm ]    |
      |                                |
      +================================+
      """
    }
  ]

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Lists all available scenario IDs.

  ## Examples

      iex> Scenarios.list()
      [:login_form, :dashboard, :settings_page, :data_table, :wizard, :modal_dialog]
  """
  @spec list() :: [atom()]
  def list, do: Enum.map(@scenarios, & &1.id)

  @doc """
  Returns all scenarios with full details.

  ## Examples

      iex> Scenarios.all()
      [%{id: :login_form, title: "Login Form", ...}, ...]
  """
  @spec all() :: [scenario()]
  def all, do: @scenarios

  @doc """
  Gets a specific scenario by ID.

  ## Examples

      iex> Scenarios.get(:login_form)
      %{id: :login_form, title: "Login Form", tagline: "Build in 30 seconds", ...}

      iex> Scenarios.get(:unknown)
      nil
  """
  @spec get(atom()) :: scenario() | nil
  def get(id), do: Enum.find(@scenarios, &(&1.id == id))

  @doc """
  Runs a scenario, returning the built components.

  This function executes each step in the scenario and returns
  a list of Builder structs representing the components.

  ## Examples

      iex> {:ok, components} = Scenarios.run(:login_form)
      iex> length(components)
      3
  """
  @spec run(atom()) :: {:ok, [Builder.t()]} | {:error, :scenario_not_found}
  def run(id) do
    case get(id) do
      nil -> {:error, :scenario_not_found}
      scenario -> execute_scenario(scenario)
    end
  end

  @doc """
  Previews a scenario's result without running steps.

  ## Examples

      iex> Scenarios.preview(:login_form)
      {:ok, "+--[ Login ]--..."}
  """
  @spec preview(atom()) :: {:ok, String.t()} | {:error, :scenario_not_found}
  def preview(id) do
    case get(id) do
      nil -> {:error, :scenario_not_found}
      scenario -> {:ok, String.trim(scenario.result_preview)}
    end
  end

  @doc """
  Returns a summary of all scenarios for display.

  ## Examples

      iex> Scenarios.summary()
      [
        %{id: :login_form, title: "Login Form", tagline: "Build in 30 seconds"},
        ...
      ]
  """
  @spec summary() :: [map()]
  def summary do
    Enum.map(@scenarios, fn s ->
      Map.take(s, [:id, :title, :tagline, :description])
    end)
  end

  @doc """
  Generates exportable code for a completed scenario.

  ## Examples

      iex> {:ok, code} = Scenarios.export(:login_form)
      iex> String.contains?(code, "defmodule")
      true
  """
  @spec export(atom(), atom()) :: {:ok, String.t()} | {:error, atom()}
  def export(id, format \\ :component) do
    case run(id) do
      {:ok, components} ->
        code = generate_scenario_code(id, components, format)
        {:ok, code}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp execute_scenario(scenario) do
    components =
      scenario.steps
      |> Enum.map(&execute_step/1)
      |> Enum.filter(&match?({:ok, _}, &1))
      |> Enum.map(&elem(&1, 1))

    {:ok, components}
  end

  defp execute_step({:add, component_type, props}) do
    builder =
      Builder.new()
      |> Builder.component(component_type)
      |> Builder.props(props)

    {:ok, builder}
  end

  defp execute_step({:configure, _component_type, _config}) do
    # Future: configuration steps
    {:skip, :not_implemented}
  end

  defp execute_step({:connect, _source, _target}) do
    # Future: connection steps for event wiring
    {:skip, :not_implemented}
  end

  defp generate_scenario_code(id, components, :component) do
    module_name = id |> Atom.to_string() |> Macro.camelize()

    component_renders =
      components
      |> Enum.with_index(1)
      |> Enum.map_join("\n      ", fn {builder, _idx} ->
        component_to_render(builder)
      end)

    """
    defmodule My#{module_name} do
      @moduledoc \"\"\"
      Generated from Raxol Playground scenario: #{id}
      \"\"\"

      use Raxol.UI

      def render(assigns) do
        ~H\"\"\"
        <div class="#{id}">
          #{component_renders}
        </div>
        \"\"\"
      end
    end
    """
  end

  defp generate_scenario_code(id, components, :standalone) do
    component_code =
      components
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {builder, idx} ->
        "# Component #{idx}: #{builder.component && builder.component.id}\n" <>
          "# Props: #{inspect(builder.props)}"
      end)

    """
    # Raxol Standalone: #{id}
    # Generated from Raxol Playground

    #{component_code}

    # Run with: mix run this_file.exs
    """
  end

  defp generate_scenario_code(id, _components, _format) do
    "# Scenario: #{id}\n# Export format not supported"
  end

  defp component_to_render(builder) do
    case builder.component do
      nil ->
        "<!-- Unknown component -->"

      component ->
        props_str =
          builder.props
          |> Enum.map_join(" ", fn {k, v} -> "#{k}={#{inspect(v)}}" end)

        "<.#{component.id} #{props_str} />"
    end
  end
end
