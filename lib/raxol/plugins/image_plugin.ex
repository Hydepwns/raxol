defmodule Raxol.Plugins.ImagePlugin do
  @moduledoc """
  Plugin that enables displaying images in the terminal using the iTerm2 image protocol.
  Supports various image formats and provides options for image display.
  """

  @behaviour Raxol.Plugins.Plugin

  defstruct [:name, :enabled, :config]

  @impl true
  def init(config \\ %{}) do
    {:ok, %__MODULE__{
      name: "image",
      enabled: true,
      config: config
    }}
  end

  @impl true
  def handle_output(plugin, output) when is_binary(output) do
    # Check if the output contains an image marker
    if String.contains?(output, "<<IMAGE:") do
      # Extract image data and parameters
      case extract_image_data(output) do
        {:ok, image_data, params} ->
          # Generate iTerm2 image escape sequence
          escape_sequence = generate_image_escape_sequence(image_data, params)
          {:ok, plugin, escape_sequence}
        {:error, reason} ->
          {:error, "Failed to process image: #{reason}"}
      end
    else
      {:ok, plugin}
    end
  end

  @impl true
  def handle_input(plugin, input) do
    # Process input for image-related commands
    case input do
      "img " <> path ->
        case process_image(path) do
          {:ok, _} -> {:ok, plugin}
          {:error, reason} -> {:error, reason}
        end
      _ -> {:ok, plugin}
    end
  end

  @impl true
  def handle_mouse(plugin, event) do
    # Handle mouse events for image interaction
    case event do
      {:click, x, y} ->
        # Check if click is within any displayed image bounds
        case find_image_at_position(plugin, x, y) do
          nil -> {:ok, plugin}
          image -> handle_image_click(plugin, image, x, y)
        end
      _ -> {:ok, plugin}
    end
  end

  @impl true
  def get_name(plugin) do
    plugin.name
  end

  @impl true
  def is_enabled?(plugin) do
    plugin.enabled
  end

  @impl true
  def enable(plugin) do
    %{plugin | enabled: true}
  end

  @impl true
  def disable(plugin) do
    %{plugin | enabled: false}
  end

  # Private functions

  defp extract_image_data(output) do
    # Match pattern: <<IMAGE:base64_data:width:height:preserve_aspect>>
    case Regex.run(~r/<<IMAGE:([^:]+):(\d+):(\d+):(\d+)>>/, output) do
      [_, base64_data, width, height, preserve_aspect] ->
        {:ok, base64_data, %{
          width: String.to_integer(width),
          height: String.to_integer(height),
          preserve_aspect: String.to_integer(preserve_aspect) == 1
        }}
      _ ->
        {:error, "Invalid image format"}
    end
  end

  defp generate_image_escape_sequence(base64_data, params) do
    # iTerm2 image escape sequence format:
    # \e]1337;File=inline=1;width=auto;height=auto;preserveAspectRatio=1;size=12345;name=image.png;base64,<base64_data>\a
    
    width = if params.preserve_aspect, do: "auto", else: params.width
    height = if params.preserve_aspect, do: "auto", else: params.height
    
    "\e]1337;File=inline=1;width=#{width};height=#{height};preserveAspectRatio=#{if params.preserve_aspect, do: "1", else: "0"};size=#{byte_size(Base.decode64!(base64_data))};name=image.png;base64,#{base64_data}\a"
  end

  defp process_image(path) do
    case File.read(path) do
      {:ok, content} ->
        # Convert image to base64
        base64 = Base.encode64(content)
        {:ok, base64}
      {:error, reason} ->
        {:error, "Failed to read image: #{reason}"}
    end
  end

  defp find_image_at_position(_plugin, _x, _y) do
    # TODO: Implement image position tracking
    # For now, return nil to indicate no image found at position
    nil
  end

  defp handle_image_click(plugin, _image, _x, _y) do
    # TODO: Implement image click handling
    # For now, just return the plugin unchanged
    {:ok, plugin}
  end
end 