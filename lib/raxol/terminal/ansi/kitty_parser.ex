defmodule Raxol.Terminal.ANSI.KittyParser do
  @moduledoc """
  Handles the parsing logic for Kitty graphics protocol sequences.

  The Kitty graphics protocol uses APC (Application Program Command) sequences
  with the format: `<ESC>_G<control-data>;<payload><ESC>\\`

  ## Control Data Format

  Control data consists of key=value pairs separated by commas:
  - `a` - Action: t (transmit), T (transmit+display), d (delete), etc.
  - `f` - Format: 24 (RGB), 32 (RGBA), 100 (PNG)
  - `o` - Compression: z (zlib)
  - `t` - Transmission: d (direct), f (file), t (temp file), s (shared memory)
  - `i` - Image ID
  - `p` - Placement ID
  - `q` - Quiet mode (0, 1, or 2)
  - `s` - Width in pixels
  - `v` - Height in pixels
  - `m` - More data follows (0 or 1)

  ## Example

      iex> state = KittyParser.ParserState.new()
      iex> {:ok, state} = KittyParser.parse("a=t,f=32,s=100,v=100;base64data", state)
  """

  alias Raxol.Core.Runtime.Log

  defmodule ParserState do
    @moduledoc """
    Represents the state during parsing of a Kitty graphics data stream.
    Tracks control parameters, chunked data, and image buffers.
    """

    @type action ::
            :transmit | :transmit_display | :display | :delete | :query | :frame
    @type format :: :rgb | :rgba | :png | :unknown
    @type compression :: :none | :zlib
    @type transmission :: :direct | :file | :temp_file | :shared_memory

    @type t :: %__MODULE__{
            action: action(),
            format: format(),
            compression: compression(),
            transmission: transmission(),
            image_id: non_neg_integer() | nil,
            placement_id: non_neg_integer() | nil,
            width: non_neg_integer() | nil,
            height: non_neg_integer() | nil,
            x_offset: non_neg_integer(),
            y_offset: non_neg_integer(),
            cell_x: non_neg_integer() | nil,
            cell_y: non_neg_integer() | nil,
            z_index: integer(),
            quiet: 0 | 1 | 2,
            more_data: boolean(),
            chunk_data: binary(),
            pixel_buffer: binary(),
            errors: [term()],
            raw_control: binary()
          }

    defstruct action: :transmit,
              format: :rgba,
              compression: :none,
              transmission: :direct,
              image_id: nil,
              placement_id: nil,
              width: nil,
              height: nil,
              x_offset: 0,
              y_offset: 0,
              cell_x: nil,
              cell_y: nil,
              z_index: 0,
              quiet: 0,
              more_data: false,
              chunk_data: <<>>,
              pixel_buffer: <<>>,
              errors: [],
              raw_control: <<>>

    @doc """
    Create a new parser state with default values.
    """
    @spec new() :: %__MODULE__{
            action: :transmit,
            format: :rgba,
            compression: :none,
            transmission: :direct,
            image_id: nil,
            placement_id: nil,
            width: nil,
            height: nil,
            x_offset: 0,
            y_offset: 0,
            cell_x: nil,
            cell_y: nil,
            z_index: 0,
            quiet: 0,
            more_data: false,
            chunk_data: <<>>,
            pixel_buffer: <<>>,
            errors: [],
            raw_control: <<>>
          }
    def new, do: %__MODULE__{}

    @doc """
    Create a new parser state with initial dimensions.
    """
    @spec new(pos_integer(), pos_integer()) :: t()
    def new(width, height) do
      %__MODULE__{width: width, height: height}
    end

    @doc """
    Reset the parser state for a new image while preserving accumulated data.
    """
    @spec reset(t()) :: t()
    def reset(%__MODULE__{} = state) do
      %{
        state
        | action: :transmit,
          format: :rgba,
          compression: :none,
          more_data: false,
          errors: [],
          raw_control: <<>>
      }
    end
  end

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Parse a Kitty graphics sequence.

  Expects data in the format: `<control-data>;<payload>` (without the APC wrapper).

  ## Examples

      iex> state = KittyParser.ParserState.new()
      iex> {:ok, state} = KittyParser.parse("a=t,f=32,s=100,v=100;base64data", state)
      iex> state.action
      :transmit
  """
  @spec parse(binary(), ParserState.t()) ::
          {:ok, ParserState.t()} | {:error, atom(), ParserState.t()}
  def parse(<<>>, state), do: {:ok, state}

  def parse(data, state) when is_binary(data) do
    case split_control_payload(data) do
      {control_data, payload} ->
        state = %{state | raw_control: control_data}

        case parse_control_data(control_data, state) do
          {:ok, parsed_state} ->
            handle_payload(payload, parsed_state)
        end

      :error ->
        {:error, :invalid_format, add_error(state, :invalid_format)}
    end
  end

  @doc """
  Parse only the control data portion of a Kitty sequence.

  ## Examples

      iex> {:ok, state} = KittyParser.parse_control_data("a=t,f=32,s=100,v=100", %ParserState{})
      iex> state.action
      :transmit
  """
  @spec parse_control_data(binary(), ParserState.t()) ::
          {:ok, ParserState.t()} | {:error, atom(), ParserState.t()}
  def parse_control_data(<<>>, state), do: {:ok, state}

  def parse_control_data(data, state) do
    pairs = String.split(data, ",", trim: true)
    parse_key_value_pairs(pairs, state)
  end

  @doc """
  Decode a base64-encoded payload.

  ## Examples

      iex> {:ok, decoded} = KittyParser.decode_base64_payload("SGVsbG8=")
      iex> decoded
      "Hello"
  """
  @spec decode_base64_payload(binary()) ::
          {:ok, binary()} | {:error, :invalid_base64}
  def decode_base64_payload(payload) when is_binary(payload) do
    case Base.decode64(payload) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, :invalid_base64}
    end
  end

  @doc """
  Handle chunked data accumulation for multi-part transmissions.

  When `m=1` is set, data is accumulated. When `m=0`, the complete
  data is finalized.

  ## Examples

      iex> state = %ParserState{more_data: true, chunk_data: "part1"}
      iex> state = KittyParser.handle_chunked_data("part2", state)
      iex> state.chunk_data
      "part1part2"
  """
  @spec handle_chunked_data(binary(), ParserState.t()) :: ParserState.t()
  def handle_chunked_data(new_data, %ParserState{more_data: true} = state) do
    %{state | chunk_data: state.chunk_data <> new_data}
  end

  def handle_chunked_data(new_data, %ParserState{more_data: false} = state) do
    complete_data = state.chunk_data <> new_data
    %{state | chunk_data: <<>>, pixel_buffer: complete_data}
  end

  @doc """
  Decompress data if compression is enabled.

  ## Examples

      iex> compressed = :zlib.compress("test data")
      iex> {:ok, decompressed} = KittyParser.decompress(compressed, :zlib)
      iex> decompressed
      "test data"
  """
  @spec decompress(binary(), ParserState.compression()) ::
          {:ok, binary()} | {:error, term()}
  def decompress(data, :none), do: {:ok, data}

  def decompress(data, :zlib) do
    {:ok, :zlib.uncompress(data)}
  rescue
    e -> {:error, {:decompression_failed, e}}
  end

  @doc """
  Extract image dimensions from PNG data.

  PNG header format: 8-byte signature + IHDR chunk with width/height.
  """
  @spec extract_png_dimensions(binary()) ::
          {:ok, {pos_integer(), pos_integer()}} | {:error, :invalid_png}
  def extract_png_dimensions(
        <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _length::32, "IHDR",
          width::32, height::32, _rest::binary>>
      ) do
    {:ok, {width, height}}
  end

  def extract_png_dimensions(_), do: {:error, :invalid_png}

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp split_control_payload(data) do
    case :binary.split(data, ";") do
      [control, payload] -> {control, payload}
      [control] -> {control, <<>>}
      _ -> :error
    end
  end

  defp parse_key_value_pairs([], state), do: {:ok, state}

  defp parse_key_value_pairs([pair | rest], state) do
    case parse_single_pair(pair, state) do
      {:ok, new_state} ->
        parse_key_value_pairs(rest, new_state)

      {:error, reason} ->
        Log.warning(
          "[KittyParser] Invalid key-value pair: #{pair} - #{inspect(reason)}"
        )

        # Continue parsing but record the error
        parse_key_value_pairs(rest, add_error(state, {:invalid_pair, pair}))
    end
  end

  defp parse_single_pair(pair, state) do
    case String.split(pair, "=", parts: 2) do
      [key, value] -> apply_key_value(key, value, state)
      _ -> {:error, :malformed_pair}
    end
  end

  defp apply_key_value("a", value, state) do
    action = parse_action(value)
    {:ok, %{state | action: action}}
  end

  defp apply_key_value("f", value, state) do
    format = parse_format(value)
    {:ok, %{state | format: format}}
  end

  defp apply_key_value("o", value, state) do
    compression = parse_compression(value)
    {:ok, %{state | compression: compression}}
  end

  defp apply_key_value("t", value, state) do
    transmission = parse_transmission(value)
    {:ok, %{state | transmission: transmission}}
  end

  defp apply_key_value("i", value, state) do
    case Integer.parse(value) do
      {id, ""} when id >= 0 -> {:ok, %{state | image_id: id}}
      _ -> {:error, :invalid_image_id}
    end
  end

  defp apply_key_value("p", value, state) do
    case Integer.parse(value) do
      {id, ""} when id >= 0 -> {:ok, %{state | placement_id: id}}
      _ -> {:error, :invalid_placement_id}
    end
  end

  defp apply_key_value("s", value, state) do
    case Integer.parse(value) do
      {width, ""} when width > 0 -> {:ok, %{state | width: width}}
      _ -> {:error, :invalid_width}
    end
  end

  defp apply_key_value("v", value, state) do
    case Integer.parse(value) do
      {height, ""} when height > 0 -> {:ok, %{state | height: height}}
      _ -> {:error, :invalid_height}
    end
  end

  defp apply_key_value("x", value, state) do
    case Integer.parse(value) do
      {x, ""} when x >= 0 -> {:ok, %{state | x_offset: x}}
      _ -> {:error, :invalid_x_offset}
    end
  end

  defp apply_key_value("y", value, state) do
    case Integer.parse(value) do
      {y, ""} when y >= 0 -> {:ok, %{state | y_offset: y}}
      _ -> {:error, :invalid_y_offset}
    end
  end

  defp apply_key_value("X", value, state) do
    case Integer.parse(value) do
      {x, ""} when x >= 0 -> {:ok, %{state | cell_x: x}}
      _ -> {:error, :invalid_cell_x}
    end
  end

  defp apply_key_value("Y", value, state) do
    case Integer.parse(value) do
      {y, ""} when y >= 0 -> {:ok, %{state | cell_y: y}}
      _ -> {:error, :invalid_cell_y}
    end
  end

  defp apply_key_value("z", value, state) do
    case Integer.parse(value) do
      {z, ""} -> {:ok, %{state | z_index: z}}
      _ -> {:error, :invalid_z_index}
    end
  end

  defp apply_key_value("q", value, state) do
    case Integer.parse(value) do
      {q, ""} when q in [0, 1, 2] -> {:ok, %{state | quiet: q}}
      _ -> {:error, :invalid_quiet}
    end
  end

  defp apply_key_value("m", value, state) do
    more_data = value in ["1", "true"]
    {:ok, %{state | more_data: more_data}}
  end

  # Ignore unknown keys (forward compatibility)
  defp apply_key_value(_key, _value, state) do
    {:ok, state}
  end

  defp parse_action("t"), do: :transmit
  defp parse_action("T"), do: :transmit_display
  defp parse_action("p"), do: :display
  defp parse_action("d"), do: :delete
  defp parse_action("q"), do: :query
  defp parse_action("f"), do: :frame
  defp parse_action("a"), do: :frame
  defp parse_action("c"), do: :frame
  defp parse_action("s"), do: :frame
  defp parse_action(_), do: :transmit

  defp parse_format("24"), do: :rgb
  defp parse_format("32"), do: :rgba
  defp parse_format("100"), do: :png
  defp parse_format(_), do: :unknown

  defp parse_compression("z"), do: :zlib
  defp parse_compression(_), do: :none

  defp parse_transmission("d"), do: :direct
  defp parse_transmission("f"), do: :file
  defp parse_transmission("t"), do: :temp_file
  defp parse_transmission("s"), do: :shared_memory
  defp parse_transmission(_), do: :direct

  defp handle_payload(<<>>, state), do: {:ok, state}

  defp handle_payload(payload, state) do
    case decode_base64_payload(payload) do
      {:ok, decoded} ->
        decompressed_result = decompress(decoded, state.compression)
        handle_decompressed_payload(decompressed_result, state)

      {:error, :invalid_base64} ->
        {:error, :invalid_base64, add_error(state, :invalid_base64)}
    end
  end

  defp handle_decompressed_payload({:ok, data}, state) do
    updated_state = handle_chunked_data(data, state)
    {:ok, updated_state}
  end

  defp handle_decompressed_payload({:error, reason}, state) do
    {:error, :decompression_failed,
     add_error(state, {:decompression_failed, reason})}
  end

  defp add_error(state, error) do
    %{state | errors: [error | state.errors]}
  end
end
