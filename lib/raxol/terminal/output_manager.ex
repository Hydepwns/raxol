defmodule Raxol.Terminal.OutputManager do
  @moduledoc """
  Manages terminal output buffering, control sequences, and formatting.
  Provides functionality for:
  - Output buffering with size limits
  - Control sequence handling
  - Output formatting and styling
  - Performance metrics tracking
  - Batch processing
  """

  defstruct output_buffer: "",
            control_sequence_buffer: "",
            format_rules: [],
            style_map: %{},
            metrics: %{
              processed_bytes: 0,
              control_sequences: 0,
              format_applications: 0,
              style_applications: 0,
              buffer_overflows: 0
            },
            # 1MB default
            max_buffer_size: 1024 * 1024,
            batch_size: 100

  @type t :: %__MODULE__{
          output_buffer: String.t(),
          control_sequence_buffer: String.t(),
          format_rules: [function()],
          style_map: %{String.t() => map()},
          metrics: %{
            processed_bytes: integer(),
            control_sequences: integer(),
            format_applications: integer(),
            style_applications: integer(),
            buffer_overflows: integer()
          },
          max_buffer_size: integer(),
          batch_size: integer()
        }

  @control_char_map %{
    "\x00" => "^@",
    "\x01" => "^A",
    "\x02" => "^B",
    "\x03" => "^C",
    "\x04" => "^D",
    "\x05" => "^E",
    "\x06" => "^F",
    "\x07" => "^G",
    "\x08" => "^H",
    "\x09" => "^I",
    "\x0A" => "^J",
    "\x0B" => "^K",
    "\x0C" => "^L",
    "\x0D" => "^M",
    "\x0E" => "^N",
    "\x0F" => "^O",
    "\x10" => "^P",
    "\x11" => "^Q",
    "\x12" => "^R",
    "\x13" => "^S",
    "\x14" => "^T",
    "\x15" => "^U",
    "\x16" => "^V",
    "\x17" => "^W",
    "\x18" => "^X",
    "\x19" => "^Y",
    "\x1A" => "^Z",
    "\x1B" => "^[",
    "\x1C" => "^\\",
    "\x1D" => "^]",
    "\x1E" => "^^",
    "\x1F" => "^_",
    "\x7F" => "^?"
  }

  @doc """
  Creates a new OutputManager with default settings.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    %__MODULE__{
      max_buffer_size: Keyword.get(opts, :max_buffer_size, 1024 * 1024),
      batch_size: Keyword.get(opts, :batch_size, 100),
      format_rules: [
        &format_ansi_sequences/1,
        &format_control_chars/1,
        &format_unicode/1
      ],
      style_map: %{
        "default" => %{
          foreground: :white,
          background: :black,
          attributes: []
        }
      }
    }
  end

  @doc """
  Enqueues output to the buffer.
  Returns {:ok, updated_manager} or {:error, :buffer_overflow}
  """
  @spec enqueue_output(t(), String.t()) ::
          {:ok, t()} | {:error, :buffer_overflow}
  def enqueue_output(%__MODULE__{} = manager, output) do
    # Apply formatting rules
    formatted_output = Enum.reduce(manager.format_rules, output, & &1.(&2))

    # Check for buffer overflow
    new_size =
      String.length(manager.output_buffer) + String.length(formatted_output)

    if new_size > manager.max_buffer_size do
      {:error, :buffer_overflow}
    else
      # Update metrics
      metrics =
        update_metric(
          manager.metrics,
          :processed_bytes,
          String.length(formatted_output)
        )

      metrics = update_metric(metrics, :format_applications)

      # Update buffer
      {:ok,
       %{
         manager
         | output_buffer: manager.output_buffer <> formatted_output,
           metrics: metrics
       }}
    end
  end

  @doc """
  Flushes the output buffer and returns its contents.
  Returns {output, updated_manager}
  """
  @spec flush_output(t()) :: {String.t(), t()}
  def flush_output(%__MODULE__{} = manager) do
    {manager.output_buffer, %{manager | output_buffer: ""}}
  end

  @doc """
  Clears the output buffer.
  """
  @spec clear_output_buffer(t()) :: t()
  def clear_output_buffer(%__MODULE__{} = manager) do
    %{manager | output_buffer: ""}
  end

  @doc """
  Gets the current output buffer contents.
  """
  @spec get_output_buffer(t()) :: String.t()
  def get_output_buffer(%__MODULE__{} = manager) do
    manager.output_buffer
  end

  @doc """
  Enqueues a control sequence to the buffer.
  Returns {:ok, updated_manager} or {:error, :buffer_overflow}
  """
  @spec enqueue_control_sequence(t(), String.t()) ::
          {:ok, t()} | {:error, :buffer_overflow}
  def enqueue_control_sequence(%__MODULE__{} = manager, sequence) do
    # Check for buffer overflow
    new_size =
      String.length(manager.control_sequence_buffer) + String.length(sequence)

    if new_size > manager.max_buffer_size do
      {:error, :buffer_overflow}
    else
      # Update metrics
      metrics = update_metric(manager.metrics, :control_sequences)

      metrics =
        update_metric(metrics, :processed_bytes, String.length(sequence))

      # Update buffer
      {:ok,
       %{
         manager
         | control_sequence_buffer: manager.control_sequence_buffer <> sequence,
           metrics: metrics
       }}
    end
  end

  @doc """
  Flushes the control sequence buffer and returns its contents.
  Returns {sequences, updated_manager}
  """
  @spec flush_control_sequence_buffer(t()) :: {String.t(), t()}
  def flush_control_sequence_buffer(%__MODULE__{} = manager) do
    {manager.control_sequence_buffer, %{manager | control_sequence_buffer: ""}}
  end

  @doc """
  Clears the control sequence buffer.
  """
  @spec clear_control_sequence_buffer(t()) :: t()
  def clear_control_sequence_buffer(%__MODULE__{} = manager) do
    %{manager | control_sequence_buffer: ""}
  end

  @doc """
  Gets the current control sequence buffer contents.
  """
  @spec get_control_sequence_buffer(t()) :: String.t()
  def get_control_sequence_buffer(%__MODULE__{} = manager) do
    manager.control_sequence_buffer
  end

  @doc """
  Adds a custom formatting rule to the manager.
  """
  @spec add_format_rule(t(), function()) :: t()
  def add_format_rule(%__MODULE__{} = manager, rule)
      when is_function(rule, 1) do
    %{manager | format_rules: [rule | manager.format_rules]}
  end

  @doc """
  Gets the current metrics.
  """
  @spec get_metrics(t()) :: map()
  def get_metrics(%__MODULE__{} = manager) do
    manager.metrics
  end

  # Private helper functions

  defp update_metric(metrics, key, increment \\ 1) do
    Map.update(metrics, key, increment, &(&1 + increment))
  end

  # Formats ANSI escape sequences in the text.
  # Handles:
  # - Cursor movement sequences
  # - Color and text attribute sequences
  # - Screen manipulation sequences
  # - Mode setting sequences
  # - Device status report sequences
  # - Character set sequences
  # - OSC sequences
  defp format_ansi_sequences(text) do
    # Pattern to match ANSI escape sequences
    pattern = ~r/\e\[[^\x40-\x7E]*[\x40-\x7E]|\e[\(\)][A-Z0-9]|\e][^\a]*\a/

    # Split the input into a list of tokens
    Regex.split(pattern, text, include_captures: true, trim: true)
    |> Enum.map_join("", fn
      # If the token starts with an escape character, parse it as an ANSI sequence
      "\e" <> _ = sequence -> parse_ansi_sequence(sequence)
      # Otherwise, keep it as plain text
      text -> text
    end)
  end

  # Formats control characters in the text.
  # Handles:
  # - C0 control characters (0x00-0x1F)
  # - C1 control characters (0x80-0x9F)
  # - Special control characters (DEL, etc.)
  defp format_control_chars(text) do
    pattern = ~r/[\x00-\x1F\x7F\x80-\x9F]/

    Regex.replace(pattern, text, fn char ->
      Map.get(@control_char_map, char, char)
    end)
  end

  # Formats Unicode characters in the text.
  # Handles:
  # - Basic Unicode characters
  # - Combining characters
  # - Emoji and other special characters
  # - Zero-width characters
  defp format_unicode(text) do
    Enum.map_join(text, "", fn grapheme ->
      [codepoint | _] = String.to_charlist(grapheme)

      if codepoint > 0xFFFF do
        "U+" <> String.upcase(Integer.to_string(codepoint, 16))
      else
        grapheme
      end
    end)
  end

  # Parses an ANSI escape sequence and returns its formatted representation.
  defp parse_ansi_sequence(sequence) do
    cond do
      String.match?(sequence, ~r/^\e\[\d*[ABCDHFST]/) ->
        parse_cursor_sequence(sequence)

      String.match?(sequence, ~r/^\e\[\d*(;\d+)*m/) ->
        parse_sgr_sequence(sequence)

      String.match?(sequence, ~r/^\e\[\d*[JKL]/) ->
        parse_screen_sequence(sequence)

      String.match?(sequence, ~r/^\e\[\?(\d+)(h|l)/) ->
        parse_mode_sequence(sequence)

      String.match?(sequence, ~r/^\e\[(\d*)n/) ->
        parse_device_status_sequence(sequence)

      String.match?(sequence, ~r/^\e[\(\)][A-Z0-9]/) ->
        parse_charset_sequence(sequence)

      String.starts_with?(sequence, "\e]") ->
        parse_osc_sequence(sequence)

      true ->
        sequence
    end
  end

  defp parse_cursor_sequence(sequence) do
    case Regex.run(~r/^\e\[(\d*)(A|B|C|D|H|F|S|T)/, sequence,
           capture: :all_but_first
         ) do
      [n, dir] when dir in ["A", "B", "C", "D"] -> format_cursor_move(dir, n)
      [coords, "H"] -> format_cursor_position(coords)
      [coords, "F"] -> format_cursor_position(coords)
      ["", "H"] -> "CURSOR_HOME"
      [_, "S"] -> "CURSOR_SAVE"
      [_, "T"] -> "CURSOR_RESTORE"
      _ -> sequence
    end
  end

  defp format_cursor_move(dir, n) do
    direction =
      case dir do
        "A" -> "UP"
        "B" -> "DOWN"
        "C" -> "FORWARD"
        "D" -> "BACKWARD"
      end

    format_cursor_move(direction, n)
  end

  defp format_cursor_move(direction, ""), do: "CURSOR_#{direction}(1)"
  defp format_cursor_move(direction, n), do: "CURSOR_#{direction}(#{n})"

  defp format_cursor_position(""), do: "CURSOR_HOME"
  defp format_cursor_position(coords), do: "CURSOR_POSITION(#{coords})"

  defp parse_sgr_sequence(sequence) do
    case Regex.run(~r/^\e\[([\d;]*)m/, sequence, capture: :all_but_first) do
      [""] -> "RESET_ATTRIBUTES"
      [params] -> "SGR(#{params})"
      _ -> sequence
    end
  end

  defp parse_screen_sequence(sequence) do
    case Regex.run(~r/^\e\[(\d*)(J|K|L)/, sequence, capture: :all_but_first) do
      [n, "J"] -> "CLEAR_SCREEN(#{n})"
      [n, "K"] -> "CLEAR_LINE(#{n})"
      [n, "L"] -> "INSERT_LINE(#{n})"
      _ -> sequence
    end
  end

  defp parse_mode_sequence(sequence) do
    case Regex.run(~r/^\e\[\?(\d+)(h|l)/, sequence, capture: :all_but_first) do
      [code, "h"] -> "SET_MODE(#{code})"
      [code, "l"] -> "RESET_MODE(#{code})"
      _ -> sequence
    end
  end

  defp parse_device_status_sequence(sequence) do
    case Regex.run(~r/^\e\[(\d*)n/, sequence, capture: :all_but_first) do
      [report_type] -> "DEVICE_STATUS(#{report_type})"
      _ -> sequence
    end
  end

  defp parse_charset_sequence(sequence) do
    case Regex.run(~r/^\e([\(\)])([A-Z0-9])/, sequence, capture: :all_but_first) do
      ["(", charset] -> "DESIGNATE_CHARSET(G0,#{charset})"
      [")", charset] -> "DESIGNATE_CHARSET(G1,#{charset})"
      _ -> sequence
    end
  end

  defp parse_osc_sequence(sequence) do
    case Regex.run(~r/^\e\](\d+);(.*?)\a/, sequence, capture: :all_but_first) do
      [cmd, param] -> "OSC(#{cmd},#{param})"
      _ -> sequence
    end
  end
end
