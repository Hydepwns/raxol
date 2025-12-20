defmodule Raxol.ComponentCase do
  @moduledoc """
  Test case helper for component-related tests.

  Provides helper functions for rendering components, simulating events,
  and asserting on component output.

  ## Example

      defmodule MyComponentTest do
        use Raxol.ComponentCase

        test "renders correctly" do
          {:ok, component} = render_component(MyButton,
            label: "Click me"
          )

          assert find_text(component) == "Click me"
          assert has_style?(component, :bold)
        end
      end
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Raxol.ComponentCase
    end
  end

  setup _tags do
    {:ok, %{}}
  end

  @doc """
  Render a component with the given props.

  ## Example

      {:ok, component} = render_component(MyButton, label: "Click")
  """
  def render_component(module, props \\ []) do
    props_map = Enum.into(props, %{})

    component = %{
      module: module,
      props: props_map,
      state: init_component(module, props_map),
      rendered: nil
    }

    rendered = render(component)
    {:ok, %{component | rendered: rendered}}
  end

  @doc """
  Find text content within the rendered component.
  """
  def find_text(component) do
    extract_text(component.rendered)
  end

  @doc """
  Check if the component has a specific style applied.
  """
  def has_style?(component, style) do
    styles = extract_styles(component.rendered)
    style in styles
  end

  @doc """
  Simulate a click event on the component.
  """
  def simulate_click(component) do
    simulate_event(component, {:click, %{x: 0, y: 0}})
  end

  @doc """
  Simulate a key press event on the component.
  """
  def simulate_key(component, key) do
    simulate_event(component, {:key, key})
  end

  @doc """
  Simulate any event on the component.
  """
  def simulate_event(component, event) do
    case apply_event(component, event) do
      {:ok, updated} -> updated
    end
  end

  # Private helpers

  defp init_component(module, props) do
    if function_exported?(module, :init, 1) do
      module.init(props)
    else
      %{}
    end
  end

  defp render(component) do
    if function_exported?(component.module, :render, 1) do
      component.module.render(component.state)
    else
      %{type: :text, content: "", styles: []}
    end
  end

  defp extract_text(nil), do: ""

  defp extract_text(%{content: content}) when is_binary(content) do
    content
  end

  defp extract_text(%{children: children}) when is_list(children) do
    Enum.map_join(children, &extract_text/1)
  end

  defp extract_text(%{type: :text, value: value}), do: value
  defp extract_text(_), do: ""

  defp extract_styles(nil), do: []

  defp extract_styles(%{styles: styles}) when is_list(styles) do
    styles
  end

  defp extract_styles(%{style: style}) when is_map(style) do
    style
    |> Enum.filter(fn {_k, v} -> v == true end)
    |> Enum.map(fn {k, _v} -> k end)
  end

  defp extract_styles(_), do: []

  defp apply_event(component, event) do
    if function_exported?(component.module, :handle_event, 2) do
      new_state = component.module.handle_event(event, component.state)

      {:ok,
       %{
         component
         | state: new_state,
           rendered: render(%{component | state: new_state})
       }}
    else
      {:ok, component}
    end
  end
end
