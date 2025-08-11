defmodule Raxol.UI.Universal do
  @moduledoc """
  Universal features available across all UI frameworks in Raxol.

  These features work regardless of whether you're using React-style,
  Svelte-style, LiveView, HEEx, or raw terminal access.
  """

  @doc """
  Universal action system - works across all frameworks.
  """
  defmacro use_action(element, action, params \\ []) do
    quote do
      Raxol.Actions.apply_action(
        unquote(element),
        unquote(action),
        unquote(params)
      )
    end
  end

  @doc """
  Universal transition system.
  """
  defmacro transition(element, type, opts \\ []) do
    quote do
      Raxol.Transitions.apply_transition(
        unquote(element),
        unquote(type),
        unquote(opts)
      )
    end
  end

  @doc """
  Universal context - works like React Context or Svelte Context.
  """
  def provide_context(key, value) do
    Process.put({:raxol_context, key}, value)
  end

  def use_context(key, default \\ nil) do
    Process.get({:raxol_context, key}, default)
  end

  @doc """
  Universal theming system.
  """
  def use_theme do
    use_context(:theme, default_theme())
  end

  def with_theme(theme_overrides, do: block) do
    current_theme = use_theme()
    new_theme = Map.merge(current_theme, theme_overrides)

    provide_context(:theme, new_theme)
    result = block
    provide_context(:theme, current_theme)

    result
  end

  defp default_theme do
    %{
      colors: %{
        primary: "#2563eb",
        secondary: "#6b7280",
        success: "#10b981",
        warning: "#f59e0b",
        error: "#ef4444",
        background: "#ffffff",
        surface: "#f9fafb",
        text: "#111827",
        text_muted: "#6b7280"
      },
      spacing: %{
        xs: 1,
        sm: 2,
        md: 4,
        lg: 6,
        xl: 8
      },
      fonts: %{
        mono: "Menlo, Consolas, monospace",
        sans: "Inter, sans-serif"
      }
    }
  end

  @doc """
  Universal slot system - works across frameworks.
  """
  defmacro render_universal_slot(name, fallback \\ nil) do
    quote do
      case Process.get({:raxol_slot, unquote(name)}) do
        nil -> unquote(fallback)
        slot_content when is_function(slot_content) -> slot_content.()
        slot_content -> slot_content
      end
    end
  end

  def provide_slot(name, content) do
    Process.put({:raxol_slot, name}, content)
  end

  @doc """
  Universal event handling.
  """
  def handle_universal_event(event, payload \\ %{}) do
    # Broadcast to all registered event handlers
    Registry.dispatch(Raxol.Events, event, fn entries ->
      for {pid, handler} <- entries do
        if is_function(handler) do
          handler.(payload)
        else
          send(pid, {event, payload})
        end
      end
    end)
  end

  def subscribe_to_events(event, handler) when is_function(handler) do
    Registry.register(Raxol.Events, event, handler)
  end

  def subscribe_to_events(event) do
    Registry.register(Raxol.Events, event, nil)
  end

  @doc """
  Universal animation utilities.
  """
  def animate(element, properties, duration \\ 300) do
    start_time = System.monotonic_time(:millisecond)

    Task.start(fn ->
      animate_loop(element, properties, duration, start_time)
    end)
  end

  defp animate_loop(element, properties, duration, start_time) do
    current_time = System.monotonic_time(:millisecond)
    elapsed = current_time - start_time
    progress = min(elapsed / duration, 1.0)

    # Apply easing function
    eased_progress = ease_in_out(progress)

    # Interpolate properties
    Enum.each(properties, fn {prop, {from, to}} ->
      current_value = interpolate(from, to, eased_progress)
      apply_property(element, prop, current_value)
    end)

    if progress < 1.0 do
      # Continue animation
      # ~60 FPS
      Process.sleep(16)
      animate_loop(element, properties, duration, start_time)
    end
  end

  defp ease_in_out(t) do
    if t < 0.5 do
      2 * t * t
    else
      -1 + (4 - 2 * t) * t
    end
  end

  defp interpolate(from, to, progress) when is_number(from) and is_number(to) do
    from + (to - from) * progress
  end

  defp interpolate(from, to, _progress) when is_binary(from) and is_binary(to) do
    # Color interpolation or other string interpolation
    # TODO: Implement proper string/color interpolation using progress
    to
  end

  defp apply_property(element, property, value) do
    # Apply the animated property to the terminal element
    # This would integrate with the terminal buffer system
    send(element, {:animate_property, property, value})
  end
end
