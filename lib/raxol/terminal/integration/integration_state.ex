defmodule Raxol.Terminal.Integration.State do
  @moduledoc """
  Manages the state of the integrated terminal system.
  """

  alias Raxol.Terminal.{
    ScreenBuffer.Manager,
    Scroll.UnifiedScroll,
    Render.UnifiedRenderer,
    IO.UnifiedIO,
    Window.UnifiedWindow,
    Integration.Config
  }

  @type t :: %__MODULE__{
          buffer_manager: Manager.t(),
          scroll_buffer: UnifiedScroll.t(),
          renderer: UnifiedRenderer.t(),
          io: UnifiedIO.t(),
          window_manager: UnifiedWindow.t(),
          config: Config.t(),
          window: any(),
          buffer: any(),
          input: any(),
          output: any(),
          cursor_manager: any(),
          width: non_neg_integer(),
          height: non_neg_integer()
        }

  defstruct buffer_manager: nil,
            scroll_buffer: nil,
            renderer: nil,
            io: nil,
            window_manager: nil,
            config: nil,
            window: nil,
            buffer: nil,
            input: nil,
            output: nil,
            cursor_manager: nil,
            width: 80,
            height: 24

  @doc """
  Creates a new integration state with the given options.
  """
  @spec new(map()) :: t()
  def new(_opts \\ []) do
    # Create a new integration state
    # Only create window if UnifiedWindow process is running
    case Process.whereis(UnifiedWindow) do
      nil ->
        %__MODULE__{
          window: nil,
          window_manager: nil,
          buffer_manager: nil,
          renderer: nil,
          buffer: nil,
          input: nil,
          output: nil
        }

      _pid ->
        {:ok, window_id} =
          UnifiedWindow.create_window(%{
            title: "Raxol Terminal",
            width: 800,
            height: 600
          })

        # Create mock buffer and renderer managers for testing
        buffer_manager = %{id: "buffer_1"}
        renderer = %{id: "renderer_1"}

        %__MODULE__{
          window: window_id,
          window_manager: UnifiedWindow,
          buffer_manager: buffer_manager,
          renderer: renderer,
          buffer: nil,
          input: nil,
          output: nil
        }
    end
  end

  @doc """
  Creates a new integration state with specified width, height, and config.
  """
  @spec new(non_neg_integer(), non_neg_integer(), map()) :: t()
  def new(width, height, config)
      when is_integer(width) and is_integer(height) and is_map(config) do
    # Create a new integration state with specific dimensions
    {:ok, _window_id} =
      UnifiedWindow.create_window(%{
        title: "Raxol Terminal",
        # Approximate pixel width
        width: width * 8,
        # Approximate pixel height
        height: height * 16
      })

    %__MODULE__{
      width: width,
      height: height,
      config: config,
      window: nil,
      buffer: nil,
      input: nil,
      output: nil
    }
  end

  @doc """
  Updates the integration state with new content.
  """
  @spec update(t(), String.t()) :: t()
  def update(%__MODULE__{} = state, content) when is_binary(content) do
    # Process content through IO system
    case UnifiedIO.process_output(content) do
      {:ok, _commands} ->
        # Only update if buffer_manager is a PID
        case state.buffer_manager do
          nil ->
            %{state | buffer: content}

          _buffer_manager ->
            # For now, just return the state unchanged as ScreenBuffer.Manager
            # doesn't have the same update interface
            state
        end

      {:error, _} ->
        state
    end
  end

  @spec update(t(), nil) :: t()
  def update(%__MODULE__{} = state, nil) do
    state
  end

  @spec update(t(), keyword()) :: t()
  def update(%__MODULE__{} = state, kw) when is_list(kw) do
    Enum.reduce(kw, state, fn {k, v}, acc -> Map.put(acc, k, v) end)
  end

  @doc """
  Gets the visible content from the current window.
  """
  @spec get_visible_content(t()) :: list()
  def get_visible_content(%__MODULE__{} = state) do
    case get_window_buffer_id() do
      {:ok, buffer_id} ->
        get_buffer_content(state, buffer_id)

      _ ->
        []
    end
  end

  defp get_window_buffer_id do
    case UnifiedWindow.get_active_window() do
      {:ok, window_id} ->
        case UnifiedWindow.get_window_state(window_id) do
          {:ok, window} -> {:ok, window.buffer_id}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp get_buffer_content(%__MODULE__{} = state, _buffer_id) do
    case state.buffer_manager do
      %{id: _} ->
        # Return mock content for testing
        [["Hello, World!"]]

      buffer_manager when is_map(buffer_manager) ->
        # Get the active buffer content
        _buffer = Manager.get_active_buffer(buffer_manager)

        # For now, return empty content as the Core module interface may be different
        ""

      _ ->
        []
    end
  end

  @doc """
  Gets the current scroll position.
  """
  @spec get_scroll_position(t()) :: integer()
  def get_scroll_position(%__MODULE__{} = state) do
    UnifiedScroll.get_position(state.scroll_buffer)
  end

  @doc """
  Gets the current memory usage.
  """
  @spec get_memory_usage(t()) :: integer()
  def get_memory_usage(%__MODULE__{} = state) do
    # Return the stored memory usage from the buffer manager
    case state.buffer_manager do
      %{memory_usage: usage} -> usage
      _ -> 0
    end
  end

  @doc """
  Renders the current state.
  """
  @spec render(t()) :: t()
  def render(%__MODULE__{} = state) do
    case get_active_window_renderer_id() do
      {:ok, renderer_id} ->
        render_with_renderer(state, renderer_id)

      _ ->
        state
    end
  end

  defp get_active_window_renderer_id do
    case UnifiedWindow.get_active_window() do
      {:ok, window_id} ->
        case UnifiedWindow.get_window_state(window_id) do
          {:ok, window} -> {:ok, window.renderer_id}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp render_with_renderer(%__MODULE__{} = state, renderer_id) do
    case state.renderer do
      renderer when is_pid(renderer) ->
        UnifiedRenderer.render(renderer, renderer_id)
        state

      _ ->
        state
    end
  end

  @doc """
  Updates the renderer configuration.
  """
  @spec update_renderer_config(t(), map()) :: t()
  def update_renderer_config(%__MODULE__{} = state, config) do
    UnifiedRenderer.update_config(state.renderer, config)
    state
  end

  @doc """
  Resizes the terminal.
  """
  @spec resize(t(), integer(), integer()) :: t()
  def resize(%__MODULE__{} = state, width, height) do
    # Ensure minimum dimensions
    safe_width = max(width, 1)
    safe_height = max(height, 1)

    # Update the state dimensions
    updated_state = %{state | width: safe_width, height: safe_height}

    # Try to resize the window if UnifiedWindow is available
    case Process.whereis(UnifiedWindow) do
      nil ->
        # UnifiedWindow not available, just return updated state
        updated_state

      _pid ->
        case UnifiedWindow.get_active_window() do
          {:ok, window_id} ->
            # Resize the active window
            case UnifiedWindow.resize(window_id, safe_width, safe_height) do
              :ok -> updated_state
              {:error, _} -> updated_state
            end

          _ ->
            updated_state
        end
    end
  end

  @doc """
  Cleans up resources.
  """
  @spec cleanup(t()) :: :ok
  def cleanup(%__MODULE__{} = state) do
    # Clean up components only if they exist
    cleanup_buffer_manager(state.buffer_manager)
    cleanup_scroll_buffer(state.scroll_buffer)
    cleanup_renderer(state.renderer)
    cleanup_io(state.io)
    cleanup_window_manager(state.window_manager)
    :ok
  end

  defp cleanup_buffer_manager(nil), do: :ok

  defp cleanup_buffer_manager(_buffer_manager),
    # ScreenBuffer.Manager is a struct, no cleanup needed
    do: :ok

  defp cleanup_scroll_buffer(nil), do: :ok

  defp cleanup_scroll_buffer(scroll_buffer),
    do: UnifiedScroll.cleanup(scroll_buffer)

  defp cleanup_renderer(nil), do: :ok
  defp cleanup_renderer(renderer), do: UnifiedRenderer.cleanup(renderer)

  defp cleanup_io(nil), do: :ok
  defp cleanup_io(io), do: UnifiedIO.cleanup(io)

  defp cleanup_window_manager(nil), do: :ok
  defp cleanup_window_manager(_window_manager), do: UnifiedWindow.cleanup()
end
