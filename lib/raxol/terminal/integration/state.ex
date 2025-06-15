defmodule Raxol.Terminal.Integration.State do
  @moduledoc """
  Manages the state of the integrated terminal system.
  """

  alias Raxol.Terminal.{
    Buffer.UnifiedManager,
    Scroll.UnifiedScroll,
    Render.UnifiedRenderer,
    IO.UnifiedIO,
    Window.UnifiedWindow,
    Integration.Config
  }

  @type t :: %__MODULE__{
          buffer_manager: UnifiedManager.t(),
          scroll_buffer: UnifiedScroll.t(),
          renderer: UnifiedRenderer.t(),
          io: UnifiedIO.t(),
          window_manager: UnifiedWindow.t(),
          config: Config.t(),
          window: any(),
          buffer: any(),
          input: any(),
          output: any()
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
            output: nil

  @doc """
  Creates a new integration state with the given options.
  """
  @spec new(map()) :: t()
  def new(_opts \\ []) do
    # Create a new integration state
    {:ok, _window_id} =
      UnifiedWindow.create_window(%{
        title: "Raxol Terminal",
        width: 800,
        height: 600
      })

    %__MODULE__{
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
  def update(%__MODULE__{} = state, content) do
    # Process content through IO system
    {:ok, commands} = UnifiedIO.process_output(content)

    # Update buffer with processed content
    updated_buffer = UnifiedManager.update(state.buffer_manager, commands)

    # Update scroll buffer
    updated_scroll = UnifiedScroll.update(state.scroll_buffer, commands)

    %{state | buffer_manager: updated_buffer, scroll_buffer: updated_scroll}
  end

  @doc """
  Gets the visible content from the current window.
  """
  @spec get_visible_content(t()) :: list()
  def get_visible_content(%__MODULE__{} = state) do
    case UnifiedWindow.get_active_window() do
      nil ->
        []

      window_id ->
        case UnifiedWindow.get_window_state(window_id) do
          {:ok, window} ->
            UnifiedManager.get_visible_content(
              state.buffer_manager,
              window.buffer_id
            )

          _ ->
            []
        end
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
    UnifiedManager.get_memory_usage(state.buffer_manager)
  end

  @doc """
  Renders the current state.
  """
  @spec render(t()) :: t()
  def render(%__MODULE__{} = state) do
    case UnifiedWindow.get_active_window() do
      nil ->
        state

      window_id ->
        case UnifiedWindow.get_window_state(window_id) do
          {:ok, window} ->
            # Render the active window
            UnifiedRenderer.render(state.renderer, window.renderer_id)
            state

          _ ->
            state
        end
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
  @spec resize(t(), non_neg_integer(), non_neg_integer()) :: t()
  def resize(%__MODULE__{} = state, width, height) do
    case UnifiedWindow.get_active_window() do
      nil ->
        state

      window_id ->
        # Resize the active window
        :ok = UnifiedWindow.resize(window_id, width, height)
        state
    end
  end

  @doc """
  Cleans up resources.
  """
  @spec cleanup(t()) :: :ok
  def cleanup(%__MODULE__{} = state) do
    UnifiedManager.cleanup(state.buffer_manager)
    UnifiedScroll.cleanup(state.scroll_buffer)
    UnifiedRenderer.cleanup(state.renderer)
    UnifiedIO.cleanup(state.io)
    UnifiedWindow.cleanup(state.window_manager)
    :ok
  end
end
