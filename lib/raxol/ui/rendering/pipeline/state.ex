defmodule Raxol.UI.Rendering.Pipeline.State do
  @moduledoc """
  Maintains state for the rendering pipeline.
  """

  defstruct [
    :current_tree,
    :previous_tree,
    :renderer,
    :options,
    :frame_count,
    :last_render_time
  ]

  @type t :: %__MODULE__{
    current_tree: map(),
    previous_tree: map() | nil,
    renderer: module() | nil,
    options: keyword(),
    frame_count: non_neg_integer(),
    last_render_time: integer() | nil
  }

  @doc """
  Creates a new pipeline state.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      current_tree: Keyword.get(opts, :initial_tree, %{}),
      previous_tree: nil,
      renderer: Keyword.get(opts, :renderer),
      options: opts,
      frame_count: 0,
      last_render_time: nil
    }
  end

  @doc """
  Updates the tree in the state.
  """
  @spec update_tree(t(), map()) :: t()
  def update_tree(state, new_tree) do
    %{state |
      previous_tree: state.current_tree,
      current_tree: new_tree,
      frame_count: state.frame_count + 1,
      last_render_time: System.monotonic_time()
    }
  end
end