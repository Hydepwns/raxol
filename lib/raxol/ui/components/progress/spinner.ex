defmodule Raxol.UI.Components.Progress.Spinner do
  @moduledoc """
  Animated spinner component for terminal UIs.

  Provides various spinner animations for loading states.
  """

  @type state :: %{
          style: atom(),
          frames: list(String.t()),
          frame_index: non_neg_integer(),
          color_index: non_neg_integer(),
          colors: list(atom()),
          speed: non_neg_integer(),
          text: String.t() | nil,
          text_position: atom(),
          last_update: integer()
        }

  @spinner_frames %{
    dots: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
    line: ["|", "/", "-", "\\"],
    circle: ["( )", "(.)", "(o)", "(O)", "(o)", "(.)"],
    arrow: ["v  ", "<  ", "^  ", ">  "],
    bounce: ["⠁", "⠂", "⠄", "⠂"],
    pulse: [
      "[    ]",
      "[=   ]",
      "[==  ]",
      "[=== ]",
      "[====]",
      "[=== ]",
      "[==  ]",
      "[=   ]"
    ],
    wave: ["~   ", " ~  ", "  ~ ", "   ~", "  ~ ", " ~  "],
    dots3: [".  ", ".. ", "...", " ..", "  .", "   "],
    square: ["[ ]", "[.]", "[o]", "[O]", "[o]", "[.]"],
    flip: ["_", "_", "_", "-", "`", "`", "'", "'", "-", "_"]
  }

  @doc """
  Creates an animated spinner.

  ## Parameters
  - `message` - Optional message to display next to spinner
  - `frame` - Current animation frame number
  - `opts` - Options including :type for spinner style
  """
  @spec spinner(binary() | nil, integer(), keyword()) :: binary()
  def spinner(message \\ nil, frame, opts \\ [])

  def spinner(nil, frame, opts) do
    type = Keyword.get(opts, :type, :dots)
    frames = Map.get(@spinner_frames, type, @spinner_frames.dots)
    frame_index = rem(frame, length(frames))

    Enum.at(frames, frame_index)
  end

  def spinner(message, frame, opts) when is_binary(message) do
    spinner_char = spinner(nil, frame, opts)
    "#{spinner_char} #{message}"
  end

  def spinner(_, frame, opts), do: spinner(nil, frame, opts)

  @doc """
  Returns available spinner types.
  """
  @spec types() :: list(atom())
  def types do
    Map.keys(@spinner_frames)
  end

  @doc """
  Gets the frames for a specific spinner type.
  """
  @spec frames(atom()) :: list(binary())
  def frames(type) when is_atom(type) do
    Map.get(@spinner_frames, type, @spinner_frames.dots)
  end

  @doc """
  Initializes spinner state.
  """
  @spec init(map()) :: state()
  def init(props) do
    style = Map.get(props, :style, :dots)
    custom_frames = Map.get(props, :frames)

    frames =
      if custom_frames do
        custom_frames
      else
        Map.get(@spinner_frames, style, @spinner_frames.dots)
      end

    %{
      style: style,
      frames: frames,
      frame_index: 0,
      color_index: 0,
      colors: Map.get(props, :colors, [:white]),
      speed: Map.get(props, :speed, 80),
      text: Map.get(props, :text, nil),
      text_position: Map.get(props, :text_position, :right),
      last_update: System.monotonic_time(:millisecond)
    }
  end

  @doc """
  Updates spinner state.
  """
  @spec update(atom(), state()) :: state()
  def update(:tick, state) do
    current_time = System.monotonic_time(:millisecond)
    elapsed = current_time - state.last_update

    if elapsed >= state.speed do
      new_frame_index = rem(state.frame_index + 1, length(state.frames))

      new_color_index =
        if length(state.colors) > 0 do
          rem(state.color_index + 1, length(state.colors))
        else
          0
        end

      %{
        state
        | frame_index: new_frame_index,
          color_index: new_color_index,
          last_update: current_time
      }
    else
      state
    end
  end

  def update({:set_style, style}, state) do
    new_frames = Map.get(@spinner_frames, style, @spinner_frames.dots)
    %{state | style: style, frames: new_frames, frame_index: 0}
  end

  def update({:set_speed, speed}, state) do
    %{state | speed: speed}
  end

  def update({:set_colors, colors}, state) do
    %{state | colors: colors, color_index: 0}
  end

  def update({:set_text, text}, state) do
    %{state | text: text}
  end

  def update({:set_custom_frames, frames}, state) do
    %{state | style: :custom, frames: frames, frame_index: 0}
  end

  def update(:reset, state) do
    %{state | frame_index: 0, color_index: 0}
  end

  def update(_message, state), do: state

  @doc """
  Convenience function for creating a saving spinner.
  """
  @spec saving() :: state()
  def saving do
    init(%{
      style: :pulse,
      text: "Saving",
      colors: [:yellow, :green],
      speed: 500
    })
  end

  @doc """
  Convenience function for creating a loading spinner.
  """
  @spec loading() :: state()
  def loading do
    init(%{style: :dots, text: "Loading", colors: [:white], speed: 150})
  end

  @doc """
  Convenience function for creating a processing spinner.
  """
  @spec processing(String.t()) :: state()
  def processing(message) do
    init(%{
      style: :dots,
      text: message,
      colors: [:blue, :cyan, :green],
      speed: 100
    })
  end

  @doc """
  Convenience function for creating an error spinner.
  """
  @spec error(String.t()) :: state()
  def error(message) do
    init(%{style: :pulse, text: message, colors: [:red], speed: 1000})
  end

  @doc """
  Handles frame events (for compatibility with some tests).
  """
  @spec handle_event(any(), map(), state()) :: {state(), list()}
  def handle_event(%{type: :timer}, _context, state) do
    {update(:tick, state), []}
  end

  def handle_event(:frame, _context, state) do
    {update(:tick, state), []}
  end

  def handle_event(_event, _context, state), do: {state, []}
end
