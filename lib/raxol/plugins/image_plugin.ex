defmodule Raxol.Plugins.ImagePlugin do
  @moduledoc """
  Plugin that enables displaying images in the terminal using the iTerm2 image protocol.
  Supports various image formats and provides options for image display.
  """

  @behaviour Raxol.Plugins.Plugin
  alias Raxol.Plugins.Plugin

  require Logger

  # Define the struct type matching the Plugin behaviour
  @type t :: %__MODULE__{
          name: String.t(),
          version: String.t(),
          description: String.t(),
          enabled: boolean(),
          config: map(),
          dependencies: list(map()),
          api_version: String.t(),
          image_escape_sequence: String.t() | nil,
          sequence_just_generated: boolean()
        }

  # Update defstruct to match the Plugin behaviour fields
  defstruct name: "image",
            version: "0.1.0",
            description:
              "Displays images in the terminal using iTerm2 protocol.",
            enabled: true,
            config: %{},
            dependencies: [],
            api_version: "1.0.0",
            image_escape_sequence: nil,
            sequence_just_generated: false

  @impl true
  def init(config \\ %{}) do
    # Initialize the plugin struct, merging provided config
    plugin_state = struct(__MODULE__, config)
    {:ok, plugin_state}
  end

  # @impl true
  # def handle_output(%__MODULE__{} = plugin, output) when is_binary(output) do
  #   # Check if the output contains an image marker
  #   if String.contains?(output, "<<IMAGE:") do
  #     # Extract image data and parameters
  #     case extract_image_data(output) do
  #       {:ok, image_data, params} ->
  #         # Generate iTerm2 image escape sequence
  #         escape_sequence = generate_image_escape_sequence(image_data, params)
  #         # Return updated plugin state and the escape sequence as output
  #         {:ok, plugin, escape_sequence}
  #
  #       {:error, reason} ->
  #         {:error, "Failed to process image: #{reason}"}
  #     end
  #   else
  #     {:ok, plugin}
  #   end
  # end

  @impl true
  def handle_input(%__MODULE__{} = plugin, _input) do
    # Input is not handled directly by this plugin for generating images.
    # Image display is triggered by specific markers in the output stream
    # processed by handle_output.
    {:ok, plugin}
  end

  @impl Raxol.Plugins.Plugin
  def handle_mouse(state, _event, _emulator_state) do
    {:ok, state}
  end

  @impl Raxol.Plugins.Plugin
  def handle_resize(%__MODULE__{} = plugin, _width, _height) do
    # TODO: Potentially adjust image display based on new dimensions
    {:ok, plugin}
  end

  @impl true
  def cleanup(%__MODULE__{} = _plugin) do
    # No cleanup needed for this plugin
    :ok
  end

  @impl true
  def get_dependencies do
    # This plugin has no dependencies
    []
  end

  @impl true
  def get_api_version do
    "1.0.0"
  end

  @impl Plugin
  # Restore the actual implementation using the flag and message
  def handle_cells(%__MODULE__{sequence_just_generated: just_generated} = state, cells) do
    # Use debug level for normal operation
    Logger.debug("[ImagePlugin.handle_cells] Received cells. Count: #{length(cells)}, Just generated: #{just_generated}")

    placeholder_cell = Enum.find(cells, fn
      {:placeholder, :image} -> true
      _ -> false
    end)

    if placeholder_cell do
      if just_generated do
        Logger.debug("[ImagePlugin.handle_cells] Placeholder found, but sequence generated last frame. Resetting flag.")
        { %{state | sequence_just_generated: false}, cells, [], nil }
      else
        image_path = "logo.png"
        Logger.debug("[ImagePlugin.handle_cells] Found placeholder: #{inspect(placeholder_cell)} for path: #{image_path}")

        case generate_sequence_from_path(image_path) do
          {:ok, sequence} ->
            Logger.debug("[ImagePlugin.handle_cells] Generated sequence successfully. Setting flag and sending message.")
            { %{state | sequence_just_generated: true}, cells, [sequence], {:image_rendered, :ok} }

          {:error, reason} ->
            Logger.error("[ImagePlugin.handle_cells] Failed to generate sequence for #{image_path}: #{reason}")
            { %{state | sequence_just_generated: false}, cells, [], nil }
        end
      end
    else
      Logger.debug("[ImagePlugin.handle_cells] No :image placeholder found. Ensuring flag is false.")
      { %{state | sequence_just_generated: false}, cells, [], nil }
    end
  end

  # Restore helper functions
  defp generate_sequence_from_path(image_path) do
    case File.read(image_path) do
      {:ok, content} ->
        base64_data = Base.encode64(content)
        params = %{width: 0, height: 0, preserve_aspect: true}
        sequence = generate_image_escape_sequence(base64_data, params)
        if sequence != "" do
          {:ok, sequence}
        else
          {:error, :base64_decode_failed}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp generate_image_escape_sequence(base64_data, params) do
    width = if params.preserve_aspect, do: "auto", else: params.width
    height = if params.preserve_aspect, do: "auto", else: params.height
    preserve_aspect_flag = if params.preserve_aspect, do: "1", else: "0"
    decoded_result = Base.decode64(base64_data)
    case decoded_result do
      {:ok, decoded_data} ->
        size = byte_size(decoded_data)
        "\\e]1337;File=inline=1;width=#{width};height=#{height};preserveAspectRatio=#{preserve_aspect_flag};size=#{size};name=image.png;base64,#{base64_data}\\a"
      :error ->
        ""
    end
  end

  # Comment out unused helpers
  # defp find_image_at_position(_plugin, _x, _y) do ... end
  # defp handle_image_click(%__MODULE__{} = plugin, _image, _x, _y) do ... end

end
