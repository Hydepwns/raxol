defmodule Raxol.UI.Rendering.Pipeline.State do
  @moduledoc """
  State management for the rendering pipeline.
  Defines the state structure and initialization.
  """

  @default_renderer Raxol.UI.Rendering.Renderer

  defstruct current_tree: nil,
            previous_tree: nil,
            previous_composed_tree: nil,
            previous_painted_output: nil,
            renderer_module: nil,
            animation_frame_requests: :queue.new(),
            render_scheduled_for_next_frame: false,
            last_render_time: nil,
            render_timer_ref: nil,
            animation_ticker_ref: nil

  @type t :: %__MODULE__{
          current_tree: map() | nil,
          previous_tree: map() | nil,
          previous_composed_tree: map() | nil,
          previous_painted_output: term(),
          renderer_module: module() | nil,
          animation_frame_requests: :queue.queue(),
          render_scheduled_for_next_frame: boolean(),
          last_render_time: float() | nil,
          render_timer_ref: reference() | nil,
          animation_ticker_ref: reference() | nil
        }

  @doc """
  Initializes a new pipeline state with the given options.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      renderer_module: Keyword.get(opts, :renderer, @default_renderer)
    }
  end

  @doc """
  Updates the current tree and moves the old one to previous.
  """
  @spec update_tree(t(), map()) :: t()
  def update_tree(state, new_tree) do
    %{state | previous_tree: state.current_tree, current_tree: new_tree}
  end

  @doc """
  Adds an animation frame request to the queue.
  """
  @spec add_animation_request(t(), pid(), reference()) :: t()
  def add_animation_request(state, pid, ref) do
    updated_requests = :queue.in({pid, ref}, state.animation_frame_requests)
    %{state | animation_frame_requests: updated_requests}
  end

  @doc """
  Clears all timers in the state.
  """
  @spec clear_timers(t()) :: t()
  def clear_timers(state) do
    # Cancel render timer if exists
    _ = case state.render_timer_ref do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    # Cancel animation ticker if exists
    _ = case state.animation_ticker_ref do
      nil -> :ok
      ref -> Process.cancel_timer(ref)
    end

    %{state | render_timer_ref: nil, animation_ticker_ref: nil}
  end

  @doc """
  Checks if the pipeline has a current tree to render.
  """
  @spec has_tree?(t()) :: boolean()
  def has_tree?(state), do: not is_nil(state.current_tree)

  @doc """
  Checks if a render is currently scheduled.
  """
  @spec render_scheduled?(t()) :: boolean()
  def render_scheduled?(state) do
    state.render_scheduled_for_next_frame or not is_nil(state.render_timer_ref)
  end

  @doc """
  Gets the renderer module, defaulting if not set.
  """
  @spec get_renderer(t()) :: module()
  def get_renderer(state) do
    state.renderer_module || @default_renderer
  end
end
