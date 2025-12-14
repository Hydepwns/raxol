defmodule Raxol.Playground.Builder do
  @moduledoc """
  Pipeable API for playground component building.

  Provides a functional, composable interface for creating and previewing
  Raxol components. Designed for discoverability and ease of use in IEx.

  ## Examples

      # Simple component preview
      iex> Builder.demo(:button, label: "Click me")
      {:ok, "[ Click me ]"}

      # Pipeable API
      iex> Builder.new()
      ...> |> Builder.component(:button)
      ...> |> Builder.props(label: "Submit", variant: :primary)
      ...> |> Builder.preview()
      {:ok, "[ Submit ]"}

      # Export code
      iex> Builder.new()
      ...> |> Builder.component(:text_input)
      ...> |> Builder.props(label: "Email", placeholder: "you@example.com")
      ...> |> Builder.export(:component)
      {:ok, "defmodule MyTextInput do..."}
  """

  alias Raxol.Playground.{Catalog, CodeGenerator, Preview}

  @type t :: %__MODULE__{
          component: map() | nil,
          props: map(),
          state: map(),
          theme: atom()
        }

  defstruct component: nil,
            props: %{},
            state: %{},
            theme: :default

  # ============================================================================
  # Builder API
  # ============================================================================

  @doc """
  Creates a new builder with default values.

  ## Examples

      iex> Builder.new()
      %Builder{component: nil, props: %{}, state: %{}, theme: :default}
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Sets the component by name or ID.

  Accepts atoms or strings. Looks up the component in the catalog.

  ## Examples

      iex> Builder.new() |> Builder.component(:button)
      %Builder{component: %{id: "button", ...}, ...}

      iex> Builder.new() |> Builder.component("text_input")
      %Builder{component: %{id: "text_input", ...}, ...}
  """
  @spec component(t(), atom() | String.t()) :: t()
  def component(builder, name) when is_atom(name) do
    component(builder, Atom.to_string(name))
  end

  def component(builder, name) when is_binary(name) do
    catalog = Catalog.load_components()

    comp =
      Enum.find(catalog, fn c ->
        c.id == name or String.downcase(c.id) == String.downcase(name)
      end)

    case comp do
      nil -> builder
      found -> %{builder | component: found, props: found.default_props || %{}}
    end
  end

  @doc """
  Merges props into the builder's current props.

  ## Examples

      iex> Builder.new()
      ...> |> Builder.component(:button)
      ...> |> Builder.props(label: "Click", variant: :primary)
      %Builder{props: %{label: "Click", variant: :primary}, ...}
  """
  @spec props(t(), map() | keyword()) :: t()
  def props(builder, props) when is_list(props) do
    props(builder, Map.new(props))
  end

  def props(builder, props) when is_map(props) do
    %{builder | props: Map.merge(builder.props, props)}
  end

  @doc """
  Sets a single prop value.

  ## Examples

      iex> Builder.new()
      ...> |> Builder.component(:button)
      ...> |> Builder.prop(:label, "Submit")
      %Builder{props: %{label: "Submit"}, ...}
  """
  @spec prop(t(), atom(), any()) :: t()
  def prop(builder, key, value) do
    %{builder | props: Map.put(builder.props, key, value)}
  end

  @doc """
  Merges state into the builder's current state.

  ## Examples

      iex> Builder.new()
      ...> |> Builder.component(:checkbox)
      ...> |> Builder.state(checked: true)
      %Builder{state: %{checked: true}, ...}
  """
  @spec state(t(), map() | keyword()) :: t()
  def state(builder, state) when is_list(state) do
    state(builder, Map.new(state))
  end

  def state(builder, state) when is_map(state) do
    %{builder | state: Map.merge(builder.state, state)}
  end

  @doc """
  Sets the theme for preview rendering.

  ## Examples

      iex> Builder.new()
      ...> |> Builder.component(:button)
      ...> |> Builder.theme(:dark)
      %Builder{theme: :dark, ...}
  """
  @spec theme(t(), atom()) :: t()
  def theme(builder, theme) when is_atom(theme) do
    %{builder | theme: theme}
  end

  # ============================================================================
  # Output Functions
  # ============================================================================

  @doc """
  Generates a terminal preview of the component.

  Returns `{:ok, preview_string}` on success or `{:error, reason}` if no
  component is selected.

  ## Examples

      iex> Builder.new()
      ...> |> Builder.component(:button)
      ...> |> Builder.props(label: "Click")
      ...> |> Builder.preview()
      {:ok, "[ Click ]"}
  """
  @spec preview(t()) :: {:ok, String.t()} | {:error, atom() | String.t()}
  def preview(%{component: nil}), do: {:error, :no_component_selected}

  def preview(%{component: component, props: props, state: state, theme: theme}) do
    result = Preview.generate(component, props, state, theme: theme)
    {:ok, result}
  end

  @doc """
  Generates exportable Elixir code for the component.

  Supports three formats:
  - `:component` - A reusable component module (default)
  - `:standalone` - A standalone script
  - `:example` - An example with comments

  ## Examples

      iex> Builder.new()
      ...> |> Builder.component(:button)
      ...> |> Builder.props(label: "Submit")
      ...> |> Builder.export()
      {:ok, "defmodule MyButton do..."}

      iex> Builder.new()
      ...> |> Builder.component(:button)
      ...> |> Builder.export(:example)
      {:ok, "# Button Example\\n..."}
  """
  @spec export(t(), atom()) :: {:ok, String.t()} | {:error, atom() | String.t()}
  def export(builder, format \\ :component)

  def export(%{component: nil}, _format), do: {:error, :no_component_selected}

  def export(%{component: component, props: props}, format) do
    result = CodeGenerator.generate(component, props, format)
    {:ok, result}
  end

  # ============================================================================
  # Convenience Functions
  # ============================================================================

  @doc """
  Quick one-liner to demo a component.

  This is the simplest way to see a component in action.

  ## Examples

      iex> Builder.demo(:button)
      {:ok, "[ Button ]"}

      iex> Builder.demo(:button, label: "Click me", variant: :primary)
      {:ok, "[ Click me ]"}

      iex> Builder.demo(:progress_bar, value: 75)
      {:ok, "[=========>  ] 75%"}
  """
  @spec demo(atom() | String.t(), keyword()) ::
          {:ok, String.t()} | {:error, atom()}
  def demo(component_name, props \\ []) do
    new()
    |> component(component_name)
    |> props(props)
    |> preview()
  end

  @doc """
  Returns a list of available component names.

  Useful for discoverability in IEx.

  ## Examples

      iex> Builder.available_components()
      ["button", "text_input", "checkbox", "table", ...]
  """
  @spec available_components() :: [String.t()]
  def available_components do
    Catalog.load_components()
    |> Enum.map(& &1.id)
    |> Enum.sort()
  end

  @doc """
  Shows help for a specific component, including its props and examples.

  ## Examples

      iex> Builder.help(:button)
      %{
        id: "button",
        description: "Interactive button component",
        props: %{label: :string, variant: :atom, disabled: :boolean},
        examples: [...]
      }
  """
  @spec help(atom() | String.t()) :: map() | nil
  def help(component_name) when is_atom(component_name) do
    help(Atom.to_string(component_name))
  end

  def help(component_name) when is_binary(component_name) do
    catalog = Catalog.load_components()

    case Enum.find(catalog, &(&1.id == component_name)) do
      nil ->
        nil

      comp ->
        Map.take(comp, [
          :id,
          :description,
          :prop_types,
          :examples,
          :default_props
        ])
    end
  end

  @doc """
  Prints a formatted preview to the console.

  Useful for interactive exploration in IEx.

  ## Examples

      iex> Builder.new()
      ...> |> Builder.component(:button)
      ...> |> Builder.props(label: "Click")
      ...> |> Builder.show()
      [ Click ]
      :ok
  """
  @spec show(t()) :: :ok | {:error, atom()}
  def show(builder) do
    case preview(builder) do
      {:ok, output} ->
        IO.puts(output)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
