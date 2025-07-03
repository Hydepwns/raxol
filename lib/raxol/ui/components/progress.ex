defmodule Raxol.UI.Components.Progress do
  @moduledoc """
  Provides components for displaying progress, like progress bars and spinners.
  """
  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Raxol.Core.Runtime.Log

  # Require view macros
  require Raxol.View.Elements

  # NOTE: This file must be saved as UTF-8 for Unicode characters to work correctly.
  @spinner_frames [
    "⠋",
    "⠙",
    "⠹",
    "⠸",
    "⠼",
    "⠴",
    "⠦",
    "⠧",
    "⠇",
    "⠏"
  ]

  # Define state struct (example - might need merging/refactoring existing logic)
  defstruct id: nil,
            # :bar, :spinner, :indeterminate, :circular
            type: :bar,
            value: 0,
            max: 100,
            label: nil,
            style: %{},
            # State for spinner
            frames: [],
            frame_index: 0,
            # ms
            interval: 100

  # Add other fields as needed (width, height, etc.)

  # --- Component Behaviour Callbacks ---

  @spec init(map()) :: map()
  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state based on type and props
    type = Map.get(props, :type, :bar)
    base_state = struct!(__MODULE__, props)

    # Set up frames and interval based on type
    state =
      case type do
        :spinner ->
          %{
            base_state
            | frames:
                Map.get(
                  spinner_types(),
                  Map.get(props, :spinner_type, :dots),
                  @spinner_frames
                ),
              interval: Map.get(props, :interval, 100)
          }

        :indeterminate ->
          %{base_state | interval: Map.get(props, :interval, 100)}

        _ ->
          base_state
      end

    %{state | type: type}
  end

  @spec update(term(), map()) :: {map(), list()}
  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to update value, change type, etc.
    Raxol.Core.Runtime.Log.debug(
      "Progress #{Map.get(state, :id, nil)} received message: #{inspect(msg)}"
    )

    # Placeholder
    case msg do
      {:set_value, value} when is_number(value) ->
        {%{state | value: clamp(value, 0, state.max)}, []}

      :tick when state.type == :spinner ->
        next_frame = rem(state.frame_index + 1, length(state.frames))
        {%{state | frame_index: next_frame}, []}

      _ ->
        {state, []}
    end
  end

  @spec handle_event(term(), map(), map()) :: {map(), list()}
  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    # Handle events if needed
    Raxol.Core.Runtime.Log.debug(
      "Progress #{Map.get(state, :id, nil)} received event: #{inspect(event)}"
    )

    {state, []}
  end

  # --- Render Logic ---

  @spec render(map(), map()) :: any()
  @impl Raxol.UI.Components.Base.Component
  def render(state, %{} = _props) do
    case state.type do
      :bar -> render_bar(state)
      :spinner -> render_spinner(state)
      :indeterminate -> render_indeterminate(state)
      :circular -> render_circular(state)
      _ -> Raxol.View.Elements.label(content: "Unknown progress type")
    end
  end

  # --- Internal Render Helpers (Using View Elements Macros) ---

  defp render_bar(state) do
    # Based on original bar/bar_with_label logic
    percentage = state.value / state.max
    filled_width = round(state.width * percentage)
    empty_width = state.width - filled_width

    bar_content =
      String.duplicate("█", filled_width) <> String.duplicate("░", empty_width)

    content = [
      Raxol.View.Elements.label(content: bar_content)
    ]

    content =
      if state.label do
        [Raxol.View.Elements.label(content: state.label) | content]
      else
        content
      end

    # Use row or column based on desired layout
    Raxol.View.Elements.row id: Map.get(state, :id, nil), style: state.style do
      content
    end
  end

  defp render_spinner(state) do
    # Based on original spinner logic
    frame =
      Enum.at(state.frames, state.frame_index, "?")

    Raxol.View.Elements.row id: Map.get(state, :id, nil), style: state.style do
      Raxol.View.Elements.label(content: frame)

      if state.label do
        Raxol.View.Elements.label(
          content: state.label,
          style: %{margin_left: 1}
        )
      end
    end
  end

  defp render_indeterminate(state) do
    indeterminate(
      state.frame_index,
      id: Map.get(state, :id),
      width: Map.get(state, :width, 20),
      style: state.style,
      bar_style: Map.get(state, :bar_style, %{bg: :blue}),
      background_style: Map.get(state, :background_style, %{bg: :black}),
      segment_size: Map.get(state, :segment_size, 5)
    )
  end

  defp render_circular(state) do
    # Based on original circular logic - complex, needs state + drawing
    Raxol.View.Elements.label(
      content: "( O )",
      id: Map.get(state, :id, nil),
      style: state.style
    )
  end

  defp render_label_and_percentage(
         label,
         label_style,
         percentage_text,
         percentage_style
       ) do
    label_text = Raxol.View.Elements.label(content: label, style: label_style)

    percentage_element =
      if percentage_text do
        Raxol.View.Elements.label(
          content: percentage_text,
          style: percentage_style
        )
      else
        nil
      end

    elements = [label_text]
    if percentage_element, do: elements ++ [percentage_element], else: elements
  end

  @spec bar_with_label(float(), String.t(), keyword()) :: any()
  @doc """
  Renders a progress bar with a label and optional percentage display.

  ## Parameters

  * `value` - Current progress value (0.0 to 1.0)
  * `label` - Text label to display
  * `opts` - Options for customizing the progress bar

  ## Options

  All options from `bar/2` plus:
  * `:show_percentage` - Whether to show percentage (default: true)
  * `:percentage_style` - Style for the percentage text (default: %{})
  * `:label_style` - Style for the label text (default: %{})
  * `:position` - Position of the label/percentage (:above, :below, :right, default: :above)

  ## Returns

  A view element representing the progress bar with label.

  ## Example

  ```elixir
  Progress.bar_with_label(
    0.35,
    "Loading assets...",
    show_percentage: true,
    position: :below,
    filled_style: %{bg: :cyan}
  )
  ```
  """
  def bar_with_label(value, label, opts \\ []) do
    # Extract additional options
    show_percentage = Keyword.get(opts, :show_percentage, true)
    percentage_style = Keyword.get(opts, :percentage_style, %{})
    label_style = Keyword.get(opts, :label_style, %{})
    position = Keyword.get(opts, :position, :above)
    id = Keyword.get(opts, :id, "progress_bar_with_label")

    # Generate percentage text
    percentage_text =
      if show_percentage, do: "#{round(value * 100)}%", else: nil

    # Create the progress bar with label based on position
    case position do
      :above ->
        render_above_position(
          id,
          label,
          label_style,
          percentage_text,
          percentage_style,
          value,
          opts
        )

      :below ->
        render_below_position(
          id,
          label,
          label_style,
          percentage_text,
          percentage_style,
          value,
          opts
        )

      :right ->
        render_right_position(
          id,
          label,
          label_style,
          percentage_text,
          percentage_style,
          value,
          opts
        )

      _ ->
        render_above_position(
          id,
          label,
          label_style,
          percentage_text,
          percentage_style,
          value,
          opts
        )
    end
  end

  defp render_above_position(
         id,
         label,
         label_style,
         percentage_text,
         percentage_style,
         value,
         opts
       ) do
    Raxol.View.Elements.column id: id do
      [
        Raxol.View.Elements.row style: %{justify: :space_between} do
          render_label_and_percentage(
            label,
            label_style,
            percentage_text,
            percentage_style
          )
        end,
        bar(value, opts)
      ]
    end
  end

  defp render_below_position(
         id,
         label,
         label_style,
         percentage_text,
         percentage_style,
         value,
         opts
       ) do
    Raxol.View.Elements.column id: id do
      [
        bar(value, opts),
        Raxol.View.Elements.row style: %{justify: :space_between} do
          render_label_and_percentage(
            label,
            label_style,
            percentage_text,
            percentage_style
          )
        end
      ]
    end
  end

  defp render_right_position(
         id,
         label,
         label_style,
         percentage_text,
         percentage_style,
         value,
         opts
       ) do
    adjusted_width =
      Keyword.get(opts, :width, 20) -
        String.length(label) -
        if(percentage_text, do: String.length(percentage_text) + 1, else: 0)

    Raxol.View.Elements.row id: id do
      [
        bar(value, Keyword.put(opts, :width, adjusted_width)),
        Raxol.View.Elements.label(content: " #{label}", style: label_style),
        if(percentage_text,
          do:
            Raxol.View.Elements.label(
              content: " #{percentage_text}",
              style: percentage_style
            )
        )
      ]
      |> Enum.reject(&is_nil/1)
    end
  end

  @spec spinner(String.t() | nil, integer(), keyword()) :: any()
  @doc """
  Renders a spinner animation for indicating loading or processing.

  ## Parameters

  * `message` - Optional message to display next to the spinner
  * `frame` - Current animation frame (integer, typically incremented on each render)
  * `opts` - Options for customizing the spinner

  ## Options

  * `:id` - Unique identifier for the spinner (default: "spinner")
  * `:style` - Style for the spinner container
  * `:spinner_style` - Style for the spinner character
  * `:message_style` - Style for the message text
  * `:type` - Type of spinner animation (default: :dots)

  ## Returns

  A view element representing the spinner.

  ## Example

  ```elixir
  # In your update function, increment the frame on each update
  def update(model, :tick) do
    %{model | spinner_frame: model.spinner_frame + 1}
  end

  # In your view function
  Progress.spinner(
    "Processing data...",
    model.spinner_frame,
    type: :braille,
    spinner_style: %{fg: :cyan}
  )
  ```
  """
  def spinner(message \\ nil, frame, opts \\ []) do
    # Extract options with defaults
    id = Keyword.get(opts, :id, "spinner")
    style = Keyword.get(opts, :style, %{})
    spinner_style = Keyword.get(opts, :spinner_style, %{fg: :blue})
    message_style = Keyword.get(opts, :message_style, %{})
    spinner_type = Keyword.get(opts, :type, :dots)

    # Get spinner frames
    frames = Map.get(spinner_types(), spinner_type, @spinner_frames)

    # Calculate current frame to display
    frame_index = rem(frame, length(frames))
    current_frame = Enum.at(frames, frame_index)

    # Create the spinner with optional message
    Raxol.View.Elements.row([id: id, style: style],
      do: fn ->
        # Create spinner character element
        spinner_element =
          Raxol.View.Elements.label(
            content: current_frame,
            style: spinner_style
          )

        # Create message element if provided
        message_element =
          if message do
            Raxol.View.Elements.label(
              content: " #{message}",
              style: message_style
            )
          else
            nil
          end

        # Return elements, filtering nil
        [spinner_element, message_element]
        |> Enum.reject(&is_nil/1)
      end
    )
  end

  @spec indeterminate(integer(), keyword()) :: any()
  @doc """
  Renders an indeterminate progress bar (animated).

  ## Parameters

  * `frame` - Current animation frame (integer, typically incremented on each render)
  * `opts` - Options for customizing the indeterminate progress bar

  ## Options

  * `:id` - Unique identifier for the progress bar (default: "indeterminate_progress")
  * `:width` - Width of the progress bar in characters (default: 20)
  * `:style` - Style for the progress bar container
  * `:bar_style` - Style for the animated bar (default: %{bg: :blue})
  * `:background_style` - Style for the background (default: %{bg: :black})
  * `:segment_size` - Size of the animated segment (default: 5)

  ## Returns

  A view element representing the indeterminate progress bar.

  ## Example

  ```elixir
  Progress.indeterminate(
    model.animation_frame,
    width: 30,
    bar_style: %{bg: :purple},
    segment_size: 8
  )
  ```
  """
  def indeterminate(frame, opts \\ []) do
    # Extract options with defaults
    id = Keyword.get(opts, :id, "indeterminate_progress")
    width = Keyword.get(opts, :width, 20)
    style = Keyword.get(opts, :style, %{})
    bar_style = Keyword.get(opts, :bar_style, %{bg: :blue})
    background_style = Keyword.get(opts, :background_style, %{bg: :black})
    segment_size = Keyword.get(opts, :segment_size, 5)

    # Ensure segment size is not larger than total width
    segment_size = min(segment_size, width)

    # Calculate position of the animated segment
    current_position = calculate_position(frame, width, segment_size)

    # Create the indeterminate progress bar
    Raxol.View.Elements.row([id: id, style: style],
      do: fn ->
        create_indeterminate_elements(
          current_position,
          segment_size,
          width,
          bar_style,
          background_style
        )
      end
    )
  end

  defp calculate_position(frame, width, segment_size) do
    total_frames = width * 2 - segment_size * 2
    pos = rem(frame, total_frames)

    if pos < width - segment_size do
      pos
    else
      total_frames - pos
    end
  end

  defp create_indeterminate_elements(
         current_position,
         segment_size,
         width,
         bar_style,
         background_style
       ) do
    left_width = current_position
    bar_width = segment_size
    right_width = width - bar_width - left_width

    elements = []

    elements =
      if left_width > 0 do
        [
          Raxol.View.Elements.label(
            content: String.duplicate(" ", left_width),
            style: background_style
          )
          | elements
        ]
      else
        elements
      end

    elements = [
      Raxol.View.Elements.label(
        content: String.duplicate(" ", bar_width),
        style: bar_style
      )
      | elements
    ]

    elements =
      if right_width > 0 do
        [
          Raxol.View.Elements.label(
            content: String.duplicate(" ", right_width),
            style: background_style
          )
          | elements
        ]
      else
        elements
      end

    Enum.reverse(elements)
  end

  @spec circular(float(), keyword()) :: any()
  @doc """
  Renders a circular progress indicator.

  ## Parameters

  * `value` - Current progress value (0.0 to 1.0)
  * `opts` - Options for customizing the progress indicator

  ## Options

  * `:id` - Unique identifier for the indicator (default: "circular_progress")
  * `:style` - Style for the indicator
  * `:show_percentage` - Whether to show percentage inside (default: true)
  * `:percentage_style` - Style for the percentage text

  ## Returns

  A view element representing the circular progress indicator.

  ## Example

  ```elixir
  Progress.circular(
    0.65,
    style: %{fg: :green}
  )
  ```
  """
  def circular(value, opts \\ []) do
    # Ensure value is within bounds
    value = max(0.0, min(1.0, value))

    # Extract options with defaults
    id = Keyword.get(opts, :id, "circular_progress")
    style = Keyword.get(opts, :style, %{fg: :blue})
    show_percentage = Keyword.get(opts, :show_percentage, true)
    percentage_style = Keyword.get(opts, :percentage_style, %{})

    # Calculate which character to show based on progress
    # Using quarter block characters to represent progress
    # ◴◵◶◷ or ◐◓◑◒ or ◔◕●○
    chars = ["○", "◔", "◑", "◕", "●"]
    char_index = round(value * (length(chars) - 1))
    progress_char = Enum.at(chars, char_index)

    # Generate percentage text
    percentage_text =
      if show_percentage do
        "#{round(value * 100)}%"
      else
        ""
      end

    # Create the circular progress indicator
    Raxol.View.Elements.row([id: id],
      do: fn ->
        # Create progress char element
        char_element =
          Raxol.View.Elements.label(content: progress_char, style: style)

        # Create percentage element if needed
        elements = [char_element]

        elements =
          if show_percentage do
            percentage_element =
              Raxol.View.Elements.label(
                content: percentage_text,
                style: percentage_style
              )

            elements ++ [percentage_element]
          else
            elements
          end

        # Return the elements
        elements
      end
    )
  end

  # --- Original Helper Functions (May need removal/refactoring) ---
  # Functions like bar/2, bar_with_label/3, spinner/3, etc.
  # should be adapted into the render helpers above or removed.

  defp clamp(value, min, max) do
    value |> Kernel.max(min) |> Kernel.min(max)
  end

  @spec spinner_types() :: map()
  @doc """
  Returns the available spinner types.

  ## Returns

  A map of spinner types to their frame sequences.

  ## Example

  ```elixir
  spinner_types = Progress.spinner_types()
  ```
  """
  def spinner_types do
    %{
      dots: @spinner_frames,
      line: ["|", "/", "-", "\\"],
      braille: ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
      pulse: ["█", "▓", "▒", "░"],
      circle: ["◐", "◓", "◑", "◒"]
    }
  end

  @spec bar(float(), keyword()) :: any()
  @doc """
  Renders a simple progress bar with configurable appearance.

  ## Parameters

  * `value` - Current progress value (0.0 to 1.0)
  * `opts` - Options for customizing the progress bar

  ## Options

  * `:id` - Unique identifier for the progress bar (default: "progress_bar")
  * `:width` - Width of the progress bar in characters (default: 20)
  * `:style` - Style for the progress bar container
  * `:filled_style` - Style for the filled portion of the bar (default: %{bg: :blue})
  * `:empty_style` - Style for the empty portion of the bar (default: %{bg: :black})
  * `:chars` - Characters to use for different parts of the bar
    * `:filled` - Character for filled sections (default: " ")
    * `:empty` - Character for empty sections (default: " ")

  ## Returns

  A view element representing the progress bar.

  ## Example

  ```elixir
  Progress.bar(
    0.75,
    width: 30,
    filled_style: %{bg: :green},
    chars: %{filled: "█", empty: "░"}
  )
  ```
  """
  def bar(value, opts \\ []) do
    # Ensure value is within bounds
    value = max(0.0, min(1.0, value))

    # Extract options with defaults
    id = Keyword.get(opts, :id, "progress_bar")
    width = Keyword.get(opts, :width, 20)
    style = Keyword.get(opts, :style, %{})
    filled_style = Keyword.get(opts, :filled_style, %{bg: :blue})
    empty_style = Keyword.get(opts, :empty_style, %{bg: :black})

    chars = Keyword.get(opts, :chars, %{})
    filled_char = Map.get(chars, :filled, " ")
    empty_char = Map.get(chars, :empty, " ")

    # Calculate filled and empty widths
    filled_width = round(value * width)
    empty_width = width - filled_width

    # Generate filled and empty portions
    filled_portion = String.duplicate(filled_char, filled_width)
    empty_portion = String.duplicate(empty_char, empty_width)

    # Create the progress bar
    Raxol.View.Elements.row([id: id, style: style],
      do: fn ->
        create_bar_elements(
          filled_width,
          filled_portion,
          filled_style,
          empty_width,
          empty_portion,
          empty_style
        )
      end
    )
  end

  defp create_bar_elements(
         filled_width,
         filled_portion,
         filled_style,
         empty_width,
         empty_portion,
         empty_style
       ) do
    elements = []

    elements =
      if filled_width > 0 do
        filled_text =
          Raxol.View.Elements.label(
            content: filled_portion,
            style: filled_style
          )

        [filled_text | elements]
      else
        elements
      end

    elements =
      if empty_width > 0 do
        empty_text =
          Raxol.View.Elements.label(
            content: empty_portion,
            style: empty_style
          )

        [empty_text | elements]
      else
        elements
      end

    # Return elements in correct order (reverse accumulation)
    Enum.reverse(elements)
  end
end
