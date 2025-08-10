defmodule Raxol.Svelte.Actions do
  @moduledoc """
  Svelte-style actions for Raxol components.

  Actions are functions that enhance elements with additional behavior,
  similar to Svelte's use: directive.

  ## Example

      defmodule MyComponent do
        use Raxol.Svelte.Component
        use Raxol.Svelte.Actions
        
        # Define actions
        action :tooltip, fn element, text ->
          element
          |> on_mouse_enter(fn -> show_tooltip(text) end)
          |> on_mouse_leave(fn -> hide_tooltip() end)
        end
        
        action :clickOutside, fn element, callback ->
          # Add global click handler that calls callback if click is outside element
          register_click_outside(element, callback)
        end
        
        def render do
          ~H'''
          <Box use:tooltip={"Help text"} use:clickOutside={&close_modal/0}>
            <Text>Hover for tooltip, click outside to close</Text>
          </Box>
          '''
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Raxol.Svelte.Actions

      @actions %{}
      @before_compile Raxol.Svelte.Actions
    end
  end

  @doc """
  Define an action that can be used with the use: directive.
  """
  defmacro action(name, implementation) do
    quote do
      @actions Map.put(@actions, unquote(name), unquote(implementation))

      @doc "Action: #{unquote(name)}"
      def unquote(name)(element, params \\ nil) do
        action_fn = @actions[unquote(name)]
        action_fn.(element, params)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      # Apply actions during element creation
      defp apply_actions(element, actions) when is_map(actions) do
        Enum.reduce(actions, element, fn {action_name, params}, acc ->
          if function_exported?(__MODULE__, action_name, 2) do
            apply(__MODULE__, action_name, [acc, params])
          else
            acc
          end
        end)
      end

      defp apply_actions(element, _), do: element
    end
  end
end

# Built-in actions
defmodule Raxol.Svelte.Actions.Builtin do
  @moduledoc """
  Built-in actions for common use cases.
  """

  @doc """
  Tooltip action - shows tooltip on hover.
  """
  def tooltip(element, text) do
    element
    |> Map.put(:on_mouse_enter, fn ->
      Raxol.Terminal.Tooltip.show(text)
    end)
    |> Map.put(:on_mouse_leave, fn ->
      Raxol.Terminal.Tooltip.hide()
    end)
  end

  @doc """
  Click outside action - triggers callback when clicking outside element.
  """
  def click_outside(element, callback) do
    # Register global click handler
    Raxol.Terminal.Events.register_global_click(fn click_pos ->
      unless point_in_element?(click_pos, element) do
        callback.()
      end
    end)

    element
  end

  @doc """
  Focus trap action - keeps focus within element.
  """
  def focus_trap(element, _params \\ nil) do
    element
    |> Map.put(:on_key, fn key ->
      case key do
        {:tab, []} -> focus_next_in_element(element)
        {:tab, [:shift]} -> focus_prev_in_element(element)
        _ -> :ignore
      end
    end)
  end

  @doc """
  Draggable action - makes element draggable.
  """
  def draggable(element, options \\ %{}) do
    element
    |> Map.put(:on_mouse_down, fn pos ->
      start_drag(element, pos, options)
    end)
    |> Map.put(:draggable, true)
  end

  @doc """
  Auto-resize action - automatically resizes element based on content.
  """
  def auto_resize(element, _params \\ nil) do
    element
    |> Map.put(:auto_resize, true)
    |> Map.put(:on_content_change, fn ->
      recalculate_size(element)
    end)
  end

  @doc """
  Lazy load action - only renders when element comes into view.
  """
  def lazy_load(element, threshold \\ 0.1) do
    element
    |> Map.put(:lazy_load, true)
    |> Map.put(:lazy_threshold, threshold)
    |> Map.put(:render_when_visible, true)
  end

  # Helper functions
  defp point_in_element?({x, y}, element) do
    x >= element.x && x < element.x + element.width &&
      y >= element.y && y < element.y + element.height
  end

  defp focus_next_in_element(element) do
    # Implementation for focusing next focusable element
    :ok
  end

  defp focus_prev_in_element(element) do
    # Implementation for focusing previous focusable element
    :ok
  end

  defp start_drag(element, start_pos, options) do
    # Implementation for drag behavior
    :ok
  end

  defp recalculate_size(element) do
    # Implementation for auto-resize
    :ok
  end
end
