defmodule Raxol.Components.Progress do
  @moduledoc """
  Provides components for displaying progress, like progress bars and spinners.
  """
  # Use standard component behaviour
  use Raxol.UI.Components.Base.Component
  require Logger

  # Require view macros
  require Raxol.View.Elements

  # Define state struct (example - might need merging/refactoring existing logic)
  defstruct id: nil,
            type: :bar, # :bar, :spinner, :indeterminate, :circular
            value: 0,
            max: 100,
            label: nil,
            style: %{},
            # State for spinner
            frames: [],
            frame_index: 0,
            interval: 100 # ms
            # Add other fields as needed (width, height, etc.)

  # --- Component Behaviour Callbacks ---

  @impl Raxol.UI.Components.Base.Component
  def init(props) do
    # Initialize state based on type and props
    type = Map.get(props, :type, :bar)
    base_state = struct!(__MODULE__, props)
    # TODO: Set up frames/interval based on type (:spinner, etc.)
    # Potentially start timer if needed
    %{base_state | type: type}
  end

  @impl Raxol.UI.Components.Base.Component
  def update(msg, state) do
    # Handle messages to update value, change type, etc.
    Logger.debug("Progress #{state.id} received message: #{inspect msg}")
    # Placeholder
    case msg do
      {:set_value, value} when is_number(value) ->
        {%{state | value: clamp(value, 0, state.max)}, []}
      :tick when state.type == :spinner ->
        next_frame = rem(state.frame_index + 1, length(state.frames))
        {%{state | frame_index: next_frame}, []}
      _ -> {state, []}
    end
  end

  @impl Raxol.UI.Components.Base.Component
  def handle_event(event, %{} = _props, state) do
    # Handle events if needed
    Logger.debug("Progress #{state.id} received event: #{inspect event}")
    {state, []}
  end

  # --- Render Logic ---

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

    bar_content = String.duplicate("█", filled_width) <> String.duplicate("░", empty_width)

    content = [
      Raxol.View.Elements.label(content: bar_content)
    ]

    content = if state.label do
      [Raxol.View.Elements.label(content: state.label) | content]
    else
      content
    end

    # Use row or column based on desired layout
    Raxol.View.Elements.row id: state.id, style: state.style do
       content
    end
  end

  defp render_spinner(state) do
     # Based on original spinner logic
     frame = Enum.at(state.frames, state.frame_index, "?")
     Raxol.View.Elements.row id: state.id, style: state.style do
        Raxol.View.Elements.label(content: frame)
        if state.label do
          Raxol.View.Elements.label(content: state.label, style: %{margin_left: 1})
        end
     end
  end

  defp render_indeterminate(state) do
    # Based on original indeterminate logic - needs state tracking for animation
    Raxol.View.Elements.label(content: "[ <=> ]", id: state.id, style: state.style)
  end

  defp render_circular(state) do
    # Based on original circular logic - complex, needs state + drawing
    Raxol.View.Elements.label(content: "( O )", id: state.id, style: state.style)
  end

  # --- Original Helper Functions (May need removal/refactoring) ---
  # Functions like bar/2, bar_with_label/3, spinner/3, etc.
  # should be adapted into the render helpers above or removed.

  defp clamp(value, min, max) do
    value |> Kernel.max(min) |> Kernel.min(max)
  end

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
        elements = []

        elements =
          if filled_width > 0 do
            filled_text = Raxol.View.Elements.label(content: filled_portion, style: filled_style)
            [filled_text | elements]
          else
            elements
          end

        elements =
          if empty_width > 0 do
            empty_text = Raxol.View.Elements.label(content: empty_portion, style: empty_style)
            [empty_text | elements]
          else
            elements
          end

        # Return elements in correct order (reverse accumulation)
        Enum.reverse(elements)
      end
    )
  end

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

    # Generate percentage text
    percentage_text =
      if show_percentage do
        "#{round(value * 100)}%"
      else
        nil
      end

    # Container ID
    id = Keyword.get(opts, :id, "progress_bar_with_label")

    # Create the progress bar with label based on position
    case position do
      :above ->
        Raxol.View.Elements.column id: id do
          header_row =
            Raxol.View.Elements.row style: %{justify: :space_between} do
              label_text = Raxol.View.Elements.label(content: label, style: label_style)

              percentage_element =
                if percentage_text do
                  Raxol.View.Elements.label(content: percentage_text, style: percentage_style)
                else
                  nil
                end

              # Make sure to return the elements
              elements = [label_text]

              elements =
                if percentage_element,
                  do: elements ++ [percentage_element],
                  else: elements

              elements
            end

          progress_bar = bar(value, opts)

          [header_row, progress_bar]
        end

      :below ->
        Raxol.View.Elements.column id: id do
          progress_bar = bar(value, opts)

          footer_row =
            Raxol.View.Elements.row style: %{justify: :space_between} do
              label_text = Raxol.View.Elements.label(content: label, style: label_style)

              percentage_element =
                if percentage_text do
                  Raxol.View.Elements.label(content: percentage_text, style: percentage_style)
                else
                  nil
                end

              # Make sure to return the elements
              elements = [label_text]

              elements =
                if percentage_element,
                  do: elements ++ [percentage_element],
                  else: elements

              elements
            end

          [progress_bar, footer_row]
        end

      :right ->
        Raxol.View.Elements.row id: id do
          # Adjust width for right-aligned label and percentage
          adjusted_width =
            Keyword.get(opts, :width, 20) -
              String.length(label) -
              if(percentage_text,
                do: String.length(percentage_text) + 1,
                else: 0
              )

          progress_bar =
            bar(
              value,
              Keyword.put(opts, :width, adjusted_width)
            )

          label_text = Raxol.View.Elements.label(content: " #{label}", style: label_style)

          percentage_element =
            if percentage_text do
              Raxol.View.Elements.label(content: " #{percentage_text}", style: percentage_style)
            else
              nil
            end

          # Make sure to return the elements
          elements = [progress_bar, label_text]

          elements =
            if percentage_element,
              do: elements ++ [percentage_element],
              else: elements

          elements
        end

      _ ->
        # Default to above if invalid position
        bar_with_label(value, label, Keyword.put(opts, :position, :above))
    end
  end

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
        spinner_element = Raxol.View.Elements.label(content: current_frame, style: spinner_style)

        # Create message element if provided
        message_element =
          if message do
            Raxol.View.Elements.label(content: " #{message}", style: message_style)
          else
            nil
          end

        # Return elements, filtering nil
        [spinner_element, message_element]
        |> Enum.reject(&is_nil/1)
      end
    )
  end

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
    # First move right for width steps, then move left back
    total_frames = width * 2 - segment_size * 2

    current_position =
      frame
      |> rem(total_frames)
      |> (fn pos ->
            if pos < width - segment_size do
              # Moving right
              pos
            else
              # Moving left
              total_frames - pos
            end
          end).()

    # Left part (before the bar)
    left_width = current_position
    # Animated bar part
    bar_width = segment_size
    # Right part (after the bar)
    right_width = width - bar_width - left_width

    # Create the indeterminate progress bar
    Raxol.View.Elements.row([id: id, style: style],
      do: fn ->
        elements = []

        # Add left part if there is space
        elements =
          if left_width > 0 do
            left_element =
              Raxol.View.Elements.label(content: String.duplicate(" ", left_width),
                style: background_style
              )

            [left_element | elements]
          else
            elements
          end

        # Add animated bar segment
        bar_element =
          Raxol.View.Elements.label(content: String.duplicate(" ", bar_width), style: bar_style)

        elements = [bar_element | elements]

        # Add right part if there is space
        elements =
          if right_width > 0 do
            right_element =
              Raxol.View.Elements.label(content: String.duplicate(" ", right_width),
                style: background_style
              )

            [right_element | elements]
          else
            elements
          end

        # Return elements in correct order
        Enum.reverse(elements)
      end
    )
  end

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
        char_element = Raxol.View.Elements.label(content: progress_char, style: style)

        # Create percentage element if needed
        elements = [char_element]

        elements =
          if show_percentage do
            percentage_element =
              Raxol.View.Elements.label(content: percentage_text, style: percentage_style)

            elements ++ [percentage_element]
          else
            elements
          end

        # Return the elements
        elements
      end
    )
  end
end
