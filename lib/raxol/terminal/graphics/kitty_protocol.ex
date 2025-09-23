defmodule Raxol.Terminal.Graphics.KittyProtocol do
  @moduledoc """
  Kitty Graphics Protocol implementation for advanced terminal graphics.

  Provides support for efficient image transmission, transparency, animations,
  and high-performance graphics rendering using the Kitty graphics protocol.

  ## Features

  - Direct binary image transmission
  - Transparency and alpha channel support
  - Animation frame management
  - Chunked transmission for large images
  - Format detection and conversion
  - Error handling and fallback mechanisms

  ## Supported Formats

  - PNG (with transparency)
  - JPEG 
  - WebP
  - GIF (animation support)
  - Raw RGB/RGBA data

  ## Protocol Specification

  The Kitty graphics protocol uses OSC escape sequences with the format:
  ```
  \033_G<control_data>;<payload>\033\\
  ```

  Where control_data contains comma-separated key=value pairs controlling
  the image transmission and display properties.
  """

  require Logger

  @type image_id :: non_neg_integer()
  @type placement_id :: non_neg_integer()
  @type transmission_id :: non_neg_integer()
  @type format :: :rgb | :rgba | :png | :jpeg | :webp | :gif
  @type action :: :transmit | :display | :delete | :query | :animate
  @type compression :: :none | :zlib
  @type transmission_medium :: :direct | :file | :temp_file | :shared_memory

  @type kitty_image :: %{
          id: image_id(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          format: format(),
          data: binary(),
          metadata: map()
        }

  @type display_options :: %{
          optional(:x) => non_neg_integer(),
          optional(:y) => non_neg_integer(),
          optional(:width) => non_neg_integer(),
          optional(:height) => non_neg_integer(),
          optional(:x_offset) => non_neg_integer(),
          optional(:y_offset) => non_neg_integer(),
          optional(:columns) => non_neg_integer(),
          optional(:rows) => non_neg_integer(),
          optional(:z_index) => integer(),
          optional(:alpha) => float()
        }

  @type transmission_options :: %{
          optional(:compression) => compression(),
          optional(:medium) => transmission_medium(),
          optional(:chunked) => boolean(),
          optional(:chunk_size) => non_neg_integer(),
          optional(:more_chunks) => boolean()
        }

  # Protocol constants
  @chunk_size 4096
  # 2^32 - 1
  @max_image_id 4_294_967_295

  @doc """
  Creates a new Kitty graphics protocol handler.
  """
  defstruct next_image_id: 1, images: %{}

  @spec new() :: %__MODULE__{}
  def new do
    %__MODULE__{}
  end

  @doc """
  Transmits an image using the Kitty graphics protocol.

  ## Parameters

  - `image_data` - Binary image data or file path
  - `options` - Transmission and display options

  ## Returns

  - `{:ok, escape_sequence}` - Success with ANSI escape sequence
  - `{:error, reason}` - Error with reason

  ## Examples

      iex> KittyProtocol.transmit_image(png_data, %{format: :png, width: 100, height: 100})
      {:ok, "\\033_Ga=T,f=100,s=100,v=100,C=1,i=1;base64_data\\033\\\\"}
  """
  @spec transmit_image(binary() | String.t(), map()) ::
          {:ok, binary()} | {:error, term()}
  def transmit_image(image_data, options \\ %{}) do
    with {:ok, validated_options} <- validate_transmission_options(options),
         {:ok, processed_data} <-
           process_image_data(image_data, validated_options),
         {:ok, image_id} <- generate_image_id(validated_options) do
      case Map.get(validated_options, :chunked, false) do
        true ->
          transmit_chunked_image(processed_data, image_id, validated_options)

        false ->
          transmit_single_image(processed_data, image_id, validated_options)
      end
    end
  end

  @doc """
  Displays a previously transmitted image.

  ## Parameters

  - `image_id` - ID of previously transmitted image
  - `options` - Display positioning and sizing options

  ## Returns

  - `{:ok, escape_sequence}` - Success with display command
  - `{:error, reason}` - Error with reason
  """
  @spec display_image(image_id(), display_options()) ::
          {:ok, binary()} | {:error, term()}
  def display_image(image_id, options \\ %{}) do
    with {:ok, validated_options} <- validate_display_options(options) do
      control_data = build_display_control_data(image_id, validated_options)
      escape_sequence = build_escape_sequence("p", control_data, "")
      {:ok, escape_sequence}
    end
  end

  @doc """
  Deletes a transmitted image from terminal memory.

  ## Parameters

  - `image_id` - ID of image to delete, or :all to delete all images

  ## Returns

  - `{:ok, escape_sequence}` - Success with delete command
  - `{:error, reason}` - Error with reason
  """
  @spec delete_image(image_id() | :all) :: {:ok, binary()} | {:error, term()}
  def delete_image(:all) do
    control_data = "a=d,d=A"
    escape_sequence = build_escape_sequence("d", control_data, "")
    {:ok, escape_sequence}
  end

  def delete_image(image_id)
      when is_integer(image_id) and image_id > 0 and image_id <= @max_image_id do
    control_data = "a=d,d=I,i=#{image_id}"
    escape_sequence = build_escape_sequence("d", control_data, "")
    {:ok, escape_sequence}
  end

  def delete_image(_), do: {:error, :invalid_image_id}

  @doc """
  Queries terminal capabilities for Kitty graphics protocol.

  ## Returns

  - `{:ok, escape_sequence}` - Query command to send to terminal
  - `{:error, reason}` - Error with reason
  """
  @spec query_capabilities() :: {:ok, binary()} | {:error, term()}
  def query_capabilities do
    # Query graphics support and maximum transmission size
    control_data = "a=q,s=1,v=1,f=24,t=d,o=z"
    escape_sequence = build_escape_sequence("q", control_data, "")
    {:ok, escape_sequence}
  end

  @doc """
  Creates an animation from multiple image frames.

  ## Parameters

  - `frames` - List of image data for animation frames
  - `options` - Animation options (frame_delay, loop, etc.)

  ## Returns

  - `{:ok, commands}` - List of commands to create animation
  - `{:error, reason}` - Error with reason
  """
  @spec create_animation([binary()], map()) ::
          {:ok, [binary()]} | {:error, term()}
  def create_animation(frames, options \\ %{}) when is_list(frames) do
    # milliseconds
    frame_delay = Map.get(options, :frame_delay, 100)
    # -1 for infinite
    loop_count = Map.get(options, :loop_count, -1)

    case transmit_animation_frames(frames, options) do
      {:ok, frame_ids} ->
        animation_commands =
          create_animation_commands(frame_ids, frame_delay, loop_count)

        {:ok, animation_commands}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Detects if the current terminal supports Kitty graphics protocol.

  Uses environment variables and capability queries to determine support.

  ## Returns

  - `{:ok, :supported}` - Terminal supports Kitty protocol
  - `{:ok, :unsupported}` - Terminal does not support Kitty protocol  
  - `{:error, :unknown}` - Cannot determine terminal capabilities
  """
  @spec detect_support() ::
          {:ok, :supported | :unsupported} | {:error, :unknown}
  def detect_support do
    case detect_terminal_type() do
      :kitty -> {:ok, :supported}
      :wezterm -> {:ok, :supported}
      :iterm2 -> check_iterm2_kitty_support()
      # Changed from {:error, :unknown}
      :unknown -> {:ok, :unsupported}
      _ -> {:ok, :unsupported}
    end
  end

  # Private Functions

  defp validate_transmission_options(options) do
    # Validate required and optional transmission parameters
    validated = %{
      format: Map.get(options, :format, :png),
      compression: Map.get(options, :compression, :none),
      medium: Map.get(options, :medium, :direct),
      chunked: Map.get(options, :chunked, false),
      chunk_size: Map.get(options, :chunk_size, @chunk_size)
    }

    case validate_format(validated.format) do
      :ok -> {:ok, Map.merge(options, validated)}
      error -> error
    end
  end

  defp validate_display_options(options) do
    # Validate display positioning and sizing options
    validated_options =
      Enum.reduce(options, %{}, fn {key, value}, acc ->
        case validate_display_option(key, value) do
          {:ok, validated_value} -> Map.put(acc, key, validated_value)
          # Skip invalid options
          {:error, _} -> acc
        end
      end)

    {:ok, validated_options}
  end

  defp validate_format(format)
       when format in [:rgb, :rgba, :png, :jpeg, :webp, :gif],
       do: :ok

  defp validate_format(_), do: {:error, :invalid_format}

  defp validate_display_option(key, value)
       when key in [
              :x,
              :y,
              :width,
              :height,
              :x_offset,
              :y_offset,
              :columns,
              :rows
            ] and
              is_integer(value) and value >= 0 do
    {:ok, value}
  end

  defp validate_display_option(:z_index, value) when is_integer(value),
    do: {:ok, value}

  defp validate_display_option(:alpha, value)
       when is_float(value) and value >= 0.0 and value <= 1.0 do
    {:ok, value}
  end

  defp validate_display_option(_, _), do: {:error, :invalid_option}

  defp process_image_data(file_path, options) when is_binary(file_path) do
    # Check if this looks like a file path (contains '/' or '\' or common extensions)
    case String.contains?(file_path, [
           "/",
           "\\",
           ".png",
           ".jpg",
           ".jpeg",
           ".gif",
           ".webp"
         ]) do
      true ->
        case File.read(file_path) do
          {:ok, data} -> process_image_data(data, options)
          {:error, reason} -> {:error, {:file_read_error, reason}}
        end

      false ->
        # Treat as raw binary data
        process_raw_binary_data(file_path, options)
    end
  end

  defp process_raw_binary_data(data, options) do
    case Map.get(options, :format) do
      :png -> {:ok, data}
      :jpeg -> {:ok, data}
      :webp -> {:ok, data}
      :gif -> {:ok, data}
      :rgb -> encode_raw_rgb(data, options)
      :rgba -> encode_raw_rgba(data, options)
      _ -> {:error, :unsupported_format}
    end
  end

  defp encode_raw_rgb(data, options) do
    width = Map.get(options, :width, 0)
    height = Map.get(options, :height, 0)

    case byte_size(data) == width * height * 3 do
      true -> {:ok, data}
      false -> {:error, :invalid_rgb_data_size}
    end
  end

  defp encode_raw_rgba(data, options) do
    width = Map.get(options, :width, 0)
    height = Map.get(options, :height, 0)

    case byte_size(data) == width * height * 4 do
      true -> {:ok, data}
      false -> {:error, :invalid_rgba_data_size}
    end
  end

  defp generate_image_id(options) do
    case Map.get(options, :image_id) do
      nil -> {:ok, :rand.uniform(@max_image_id)}
      id when is_integer(id) and id > 0 and id <= @max_image_id -> {:ok, id}
      _ -> {:error, :invalid_image_id}
    end
  end

  defp transmit_single_image(data, image_id, options) do
    control_data = build_transmission_control_data(image_id, options, false)
    encoded_data = Base.encode64(data)
    escape_sequence = build_escape_sequence("T", control_data, encoded_data)
    {:ok, escape_sequence}
  end

  defp transmit_chunked_image(data, image_id, options) do
    chunk_size = Map.get(options, :chunk_size, @chunk_size)
    chunks = chunk_binary_data(data, chunk_size)

    commands =
      Enum.with_index(chunks)
      |> Enum.map_join(fn {chunk, index} ->
        is_last_chunk = index == length(chunks) - 1

        control_data =
          build_transmission_control_data(image_id, options, not is_last_chunk)

        encoded_chunk = Base.encode64(chunk)
        build_escape_sequence("T", control_data, encoded_chunk)
      end)

    {:ok, Enum.join(commands, "")}
  end

  defp chunk_binary_data(data, chunk_size) do
    data
    |> :binary.bin_to_list()
    |> Enum.chunk_every(chunk_size)
    |> Enum.map(&:binary.list_to_bin/1)
  end

  defp build_transmission_control_data(image_id, options, more_chunks) do
    base_params = [
      # Action: transmit
      "a=T",
      "i=#{image_id}",
      format_param(options),
      compression_param(options)
    ]

    chunk_param =
      case more_chunks do
        # More chunks coming
        true -> ["m=1"]
        # Last chunk
        false -> ["m=0"]
      end

    size_params = build_size_params(options)

    (base_params ++ chunk_param ++ size_params)
    |> Enum.filter(&(&1 != nil))
    |> Enum.join(",")
  end

  defp build_display_control_data(image_id, options) do
    base_params = [
      # Action: put/display
      "a=p",
      "i=#{image_id}"
    ]

    position_params = build_position_params(options)
    size_params = build_size_params(options)
    style_params = build_style_params(options)

    (base_params ++ position_params ++ size_params ++ style_params)
    |> Enum.filter(&(&1 != nil))
  end

  defp format_param(%{format: :png}), do: "f=100"
  defp format_param(%{format: :jpeg}), do: "f=100"
  defp format_param(%{format: :webp}), do: "f=100"
  defp format_param(%{format: :gif}), do: "f=100"
  defp format_param(%{format: :rgb}), do: "f=24"
  defp format_param(%{format: :rgba}), do: "f=32"
  defp format_param(_), do: "f=100"

  defp compression_param(%{compression: :zlib}), do: "o=z"
  defp compression_param(_), do: nil

  defp build_size_params(options) do
    [
      case Map.get(options, :width) do
        nil -> nil
        w -> "s=#{w}"
      end,
      case Map.get(options, :height) do
        nil -> nil
        h -> "v=#{h}"
      end
    ]
  end

  defp build_position_params(options) do
    [
      case Map.get(options, :x) do
        nil -> nil
        x -> "x=#{x}"
      end,
      case Map.get(options, :y) do
        nil -> nil
        y -> "y=#{y}"
      end,
      case Map.get(options, :columns) do
        nil -> nil
        c -> "c=#{c}"
      end,
      case Map.get(options, :rows) do
        nil -> nil
        r -> "r=#{r}"
      end
    ]
  end

  defp build_style_params(options) do
    [
      case Map.get(options, :z_index) do
        nil -> nil
        z -> "z=#{z}"
      end
    ]
  end

  defp build_escape_sequence(_action, control_data, payload) do
    "\033_G#{control_data};#{payload}\033\\"
  end

  defp detect_terminal_type do
    case {System.get_env("TERM"), System.get_env("TERM_PROGRAM"),
          System.get_env("KITTY_WINDOW_ID"),
          System.get_env("WEZTERM_EXECUTABLE")} do
      {"xterm-kitty", _, _, _} -> :kitty
      {_, _, kitty_id, _} when kitty_id != nil -> :kitty
      {_, _, _, wezterm} when wezterm != nil -> :wezterm
      {"wezterm", _, _, _} -> :wezterm
      {_, "iTerm.app", _, _} -> :iterm2
      {_, "vscode", _, _} -> :vscode
      _ -> :unknown
    end
  end

  defp check_iterm2_kitty_support do
    # iTerm2 3.1+ supports some Kitty graphics protocol features
    # This would require capability query in practice
    # Conservative default
    {:ok, :unsupported}
  end

  defp transmit_animation_frames(frames, options) do
    # Transmit each frame and collect image IDs
    results =
      Enum.with_index(frames)
      |> Enum.map(fn {frame_data, index} ->
        # Offset for animation frames
        frame_options = Map.put(options, :image_id, index + 1000)

        case transmit_image(frame_data, frame_options) do
          {:ok, _command} -> {:ok, index + 1000}
          {:error, reason} -> {:error, reason}
        end
      end)

    case Enum.find(results, fn result -> match?({:error, _}, result) end) do
      nil ->
        frame_ids = Enum.map(results, fn {:ok, id} -> id end)
        {:ok, frame_ids}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_animation_commands(frame_ids, _frame_delay, _loop_count) do
    # Create animation control commands
    # This is a simplified implementation - full animation support would be more complex
    Enum.map(frame_ids, fn frame_id ->
      display_image(frame_id, %{})
    end)
    |> Enum.map(fn {:ok, command} -> command end)
  end
end
