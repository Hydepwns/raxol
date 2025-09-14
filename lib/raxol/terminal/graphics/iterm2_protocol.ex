defmodule Raxol.Terminal.Graphics.ITerm2Protocol do
  @moduledoc """
  iTerm2 inline images protocol implementation.

  iTerm2 supports displaying images directly in the terminal using OSC escape sequences.
  This protocol allows embedding images inline with terminal text, making it perfect
  for rich terminal applications.

  ## Features

  - Direct image embedding with OSC 1337 sequences
  - Multiple image formats (PNG, JPEG, GIF, BMP)
  - Base64 encoding for image data transmission
  - Image positioning and sizing controls
  - Preservation of aspect ratio
  - Image metadata and naming
  - Progress indicators for large images

  ## Usage

      # Display an image from file
      ITerm2Protocol.display_image_file("/path/to/image.png")
      
      # Display image with options
      ITerm2Protocol.display_image_data(image_data, format: :png, 
                                        width: 200, height: 100)
      
      # Check if terminal supports iTerm2 protocol
      ITerm2Protocol.supported?()

  ## OSC 1337 Format

  The iTerm2 protocol uses OSC 1337 sequences with the format:
  `\\033]1337;File=[arguments]:base64_data\\007`

  Where arguments can include:
  - name: filename
  - size: file size in bytes  
  - width: display width
  - height: display height
  - preserveAspectRatio: 0 or 1
  - inline: 0 or 1 for inline display
  """

  require Logger

  @type image_format :: :png | :jpeg | :gif | :bmp | :tiff | :webp
  @type display_options :: %{
          optional(:width) => pos_integer(),
          optional(:height) => pos_integer(),
          optional(:name) => String.t(),
          optional(:preserve_aspect_ratio) => boolean(),
          optional(:inline) => boolean(),
          optional(:format) => image_format()
        }

  # iTerm2 OSC sequence constants
  @osc_start "\e]1337;File="
  # BEL terminator
  @osc_end "\a"
  # 50MB limit for safety
  @max_image_size 50_000_000
  @default_width 200
  @default_height 200

  @doc """
  Checks if the terminal supports iTerm2 inline images.

  ## Returns

  - `true` if iTerm2 protocol is supported
  - `false` if not supported or unknown
  """
  @spec supported?() :: boolean()
  def supported? do
    detect_iterm2_support() == :supported
  end

  @doc """
  Displays an image file using iTerm2 inline image protocol.

  ## Parameters

  - `file_path` - Path to the image file
  - `options` - Display options (width, height, etc.)

  ## Returns

  - `{:ok, sequence}` - OSC sequence to display the image
  - `{:error, reason}` - Error if file cannot be read or processed

  ## Examples

      iex> ITerm2Protocol.display_image_file("/tmp/image.png")
      {:ok, "\\e]1337;File=name=aW1hZ2UucG5n;size=1024:base64data...\\a"}
  """
  @spec display_image_file(String.t(), display_options()) ::
          {:ok, binary()} | {:error, term()}
  def display_image_file(file_path, options \\ %{}) when is_binary(file_path) do
    case File.read(file_path) do
      {:ok, data} ->
        # Get file size and format
        file_size = byte_size(data)

        format =
          detect_image_format(data) || guess_format_from_extension(file_path)

        filename = Path.basename(file_path)

        # Merge file info into options
        enhanced_options =
          Map.merge(options, %{
            format: format,
            name: filename,
            size: file_size
          })

        display_image_data(data, enhanced_options)

      {:error, reason} ->
        {:error, {:file_read_error, reason}}
    end
  end

  @doc """
  Displays image data using iTerm2 inline image protocol.

  ## Parameters

  - `image_data` - Binary image data
  - `options` - Display options map

  ## Returns

  - `{:ok, sequence}` - OSC sequence to display the image
  - `{:error, reason}` - Error if image cannot be processed

  ## Examples

      iex> ITerm2Protocol.display_image_data(png_data, format: :png, width: 300)
      {:ok, "\\e]1337;File=width=300;inline=1:base64data...\\a"}
  """
  @spec display_image_data(binary(), display_options()) ::
          {:ok, binary()} | {:error, term()}
  def display_image_data(data, options \\ %{}) when is_binary(data) do
    cond do
      byte_size(data) == 0 ->
        {:error, :empty_image_data}

      byte_size(data) > @max_image_size ->
        {:error, {:image_too_large, byte_size(data), @max_image_size}}

      true ->
        case build_osc_sequence(data, options) do
          {:ok, sequence} ->
            Logger.debug(
              "Generated iTerm2 image sequence: #{String.length(sequence)} bytes"
            )

            {:ok, sequence}

          error ->
            error
        end
    end
  end

  @doc """
  Creates a progress indicator for large image transfers.

  Useful for showing upload progress when sending large images to the terminal.

  ## Parameters

  - `bytes_sent` - Number of bytes already transmitted
  - `total_bytes` - Total size of the image
  - `options` - Progress display options

  ## Returns

  - `binary()` - Progress display sequence
  """
  @spec create_progress_indicator(non_neg_integer(), pos_integer(), map()) ::
          binary()
  def create_progress_indicator(bytes_sent, total_bytes, options \\ %{}) do
    percentage =
      if total_bytes > 0, do: round(bytes_sent / total_bytes * 100), else: 0

    width = Map.get(options, :width, 40)

    filled = round(width * percentage / 100)
    empty = width - filled

    bar = String.duplicate("█", filled) <> String.duplicate("░", empty)

    "Image transfer: [#{bar}] #{percentage}%\r"
  end

  @doc """
  Generates an iTerm2 image placeholder sequence.

  Creates a placeholder that can be later replaced with actual image data.
  Useful for progressive image loading or streaming scenarios.

  ## Parameters

  - `identifier` - Unique identifier for the placeholder
  - `options` - Placeholder options

  ## Returns

  - `{:ok, sequence}` - Placeholder sequence
  - `{:error, reason}` - Error if invalid parameters
  """
  @spec create_placeholder(String.t(), display_options()) ::
          {:ok, binary()} | {:error, term()}
  def create_placeholder(identifier, options \\ %{})
      when is_binary(identifier) do
    if String.length(identifier) == 0 do
      {:error, :empty_identifier}
    else
      # Create a minimal placeholder sequence
      encoded_id = Base.encode64(identifier)
      width = Map.get(options, :width, @default_width)
      height = Map.get(options, :height, @default_height)

      args =
        "name=#{encoded_id};width=#{width};height=#{height};inline=1;placeholder=1"

      sequence = @osc_start <> args <> ":" <> @osc_end

      {:ok, sequence}
    end
  end

  # Private helper functions

  defp build_osc_sequence(data, options) do
    case encode_image_data(data) do
      {:ok, encoded_data} ->
        args = build_arguments(options)
        sequence = @osc_start <> args <> ":" <> encoded_data <> @osc_end
        {:ok, sequence}

      error ->
        error
    end
  end

  defp encode_image_data(data) do
    try do
      # No line breaks
      encoded = Base.encode64(data, line_length: 0)
      {:ok, encoded}
    rescue
      error ->
        {:error, {:base64_encoding_error, error}}
    end
  end

  defp build_arguments(options) do
    args = []

    # Add name if provided
    args =
      case Map.get(options, :name) do
        nil ->
          args

        name ->
          encoded_name = Base.encode64(name)
          ["name=#{encoded_name}" | args]
      end

    # Add size if provided
    args =
      case Map.get(options, :size) do
        nil ->
          args

        size when is_integer(size) and size > 0 ->
          ["size=#{size}" | args]

        _ ->
          args
      end

    # Add width if provided
    args =
      case Map.get(options, :width) do
        nil ->
          args

        width when is_integer(width) and width > 0 ->
          ["width=#{width}" | args]

        _ ->
          args
      end

    # Add height if provided
    args =
      case Map.get(options, :height) do
        nil ->
          args

        height when is_integer(height) and height > 0 ->
          ["height=#{height}" | args]

        _ ->
          args
      end

    # Add preserve aspect ratio
    args =
      case Map.get(options, :preserve_aspect_ratio, true) do
        true -> ["preserveAspectRatio=1" | args]
        false -> ["preserveAspectRatio=0" | args]
      end

    # Add inline flag (default true for terminal display)
    args =
      case Map.get(options, :inline, true) do
        true -> ["inline=1" | args]
        false -> ["inline=0" | args]
      end

    # Join arguments with semicolons
    args |> Enum.reverse() |> Enum.join(";")
  end

  defp detect_image_format(data) when byte_size(data) >= 8 do
    # Check magic bytes to determine image format
    case data do
      <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, _::binary>> -> :png
      <<0xFF, 0xD8, 0xFF, _::binary>> -> :jpeg
      <<"GIF87a", _::binary>> -> :gif
      <<"GIF89a", _::binary>> -> :gif
      <<"BM", _::binary>> -> :bmp
      <<"RIFF", _::4-binary, "WEBP", _::binary>> -> :webp
      # Big-endian TIFF
      <<"MM", 0x00, 0x2A, _::binary>> -> :tiff
      # Little-endian TIFF
      <<"II", 0x2A, 0x00, _::binary>> -> :tiff
      _ -> nil
    end
  end

  defp detect_image_format(_), do: nil

  defp guess_format_from_extension(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".png" -> :png
      ".jpg" -> :jpeg
      ".jpeg" -> :jpeg
      ".gif" -> :gif
      ".bmp" -> :bmp
      ".webp" -> :webp
      ".tiff" -> :tiff
      ".tif" -> :tiff
      # Default fallback
      _ -> :png
    end
  end

  defp detect_iterm2_support do
    # Check environment variables for iTerm2
    term_program = System.get_env("TERM_PROGRAM", "")
    term_program_version = System.get_env("TERM_PROGRAM_VERSION", "")
    iterm_session_id = System.get_env("ITERM_SESSION_ID")

    cond do
      # Direct iTerm2 detection
      term_program == "iTerm.app" ->
        :supported

      iterm_session_id != nil ->
        :supported

      # iTerm2 version detection
      String.starts_with?(term_program_version, "3.") ->
        :supported

      # Other terminals that might support iTerm2 protocol
      term_program in ["WezTerm", "Hyper"] ->
        :maybe_supported

      # Terminals that definitely don't support it
      term_program in ["Terminal.app", "xterm", "gnome-terminal"] ->
        :unsupported

      # Unknown
      true ->
        :unknown
    end
  end

  @doc """
  Gets the maximum recommended image size for the current terminal.

  Different terminals have different limits for inline images.
  This function returns a safe maximum size.

  ## Returns

  - `pos_integer()` - Maximum image size in bytes
  """
  @spec get_max_image_size() :: pos_integer()
  def get_max_image_size do
    case detect_iterm2_support() do
      :supported -> @max_image_size
      # Be more conservative
      :maybe_supported -> div(@max_image_size, 2)
      # Very conservative for unknown terminals
      _ -> div(@max_image_size, 10)
    end
  end

  @doc """
  Clears all inline images from the terminal.

  Sends a sequence to clear any displayed inline images.
  Useful for cleaning up the display.

  ## Returns

  - `binary()` - Sequence to clear images
  """
  @spec clear_images() :: binary()
  def clear_images do
    # iTerm2 doesn't have a direct "clear all images" command
    # This sends a form feed to clear the screen
    "\f"
  end

  @doc """
  Validates image data before transmission.

  Checks if the image data is valid and suitable for terminal display.

  ## Parameters

  - `data` - Binary image data
  - `options` - Validation options

  ## Returns

  - `:ok` - Image data is valid
  - `{:error, reason}` - Image data has issues
  """
  @spec validate_image_data(binary(), map()) :: :ok | {:error, term()}
  def validate_image_data(data, _options \\ %{}) do
    cond do
      byte_size(data) == 0 ->
        {:error, :empty_image_data}

      byte_size(data) > get_max_image_size() ->
        {:error, {:image_too_large, byte_size(data)}}

      detect_image_format(data) == nil ->
        Logger.warning("Could not detect image format from data")
        # Continue anyway, might still work
        :ok

      true ->
        :ok
    end
  end
end
