defmodule Raxol.Plugins.ImagePlugin do
  import Raxol.Guards

  @moduledoc """
  Plugin that enables displaying images in the terminal using the iTerm2 image protocol.
  Supports various image formats and provides options for image display.
  """

  @behaviour Raxol.Plugins.Plugin
  @behaviour Raxol.Plugins.LifecycleBehaviour
  alias Raxol.Plugins.Plugin

  require Raxol.Core.Runtime.Log

  # Suppress Dialyzer warning about argument type mismatch for handle_cells/3
  @dialyzer {:nowarn_function, handle_cells: 3}

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

  @impl Raxol.Plugins.Plugin
  def init(config \\ %{}) do
    # Initialize the plugin struct, merging provided config
    plugin_state = struct(__MODULE__, config)
    {:ok, plugin_state}
  end

  # @impl Raxol.Plugins.Plugin
  # def handle_output(%__MODULE__{} = plugin, output) when binary?(output) do
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

  @impl Raxol.Plugins.Plugin
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
  def handle_resize(%__MODULE__{} = plugin, width, height) do
    {:ok,
     %{
       plugin
       | config:
           Map.put(plugin.config, :dimensions, %{width: width, height: height})
     }}
  end

  @impl Raxol.Plugins.Plugin
  def cleanup(%__MODULE__{} = _plugin) do
    :ok
  end

  @impl Raxol.Plugins.Plugin
  def get_dependencies do
    []
  end

  @impl Raxol.Plugins.Plugin
  def get_api_version do
    "1.0.0"
  end

  @impl Plugin
  def handle_cells(placeholder_cell, _emulator_state, %__MODULE__{} = plugin) do
    Raxol.Core.Runtime.Log.debug(
      "[ImagePlugin.handle_cells START] Received placeholder: #{inspect(placeholder_cell)}, plugin state: #{inspect(plugin)}"
    )

    case placeholder_cell do
      %{type: :placeholder, value: :image} = _cell ->
        handle_image_placeholder(plugin)

      _ ->
        {:cont, plugin}
    end
  end

  defp handle_image_placeholder(plugin) do
    if plugin.sequence_just_generated do
      Raxol.Core.Runtime.Log.debug(
        "[ImagePlugin.handle_cells] sequence_just_generated=true. Resetting flag and declining."
      )

      {:cont, %{plugin | sequence_just_generated: false}}
    else
      generate_and_return_sequence(plugin)
    end
  end

  defp generate_and_return_sequence(plugin) do
    Raxol.Core.Runtime.Log.debug(
      "[ImagePlugin.handle_cells] sequence_just_generated=false. BEFORE generate_sequence_from_path for path: @static/static/images/logo.png"
    )

    case generate_sequence_from_path("@static/static/images/logo.png") do
      {:ok, sequence} ->
        Raxol.Core.Runtime.Log.debug(
          "[ImagePlugin.handle_cells] Sequence generated successfully."
        )

        {:ok, %{plugin | sequence_just_generated: true}, [],
         [{:direct_output, sequence}]}

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "[ImagePlugin.handle_cells] Failed to generate sequence for @static/static/images/logo.png: #{inspect(reason)}"
        )

        {:cont, plugin}
    end
  end

  defp generate_sequence_from_path(image_path) do
    with {:ok, content} <- File.read(image_path),
         base64_data = Base.encode64(content),
         sequence =
           generate_image_escape_sequence(base64_data, default_params()),
         true <- sequence != "" do
      {:ok, sequence}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :base64_decode_failed}
    end
  end

  defp default_params, do: %{width: 0, height: 0, preserve_aspect: true}

  defp generate_image_escape_sequence(base64_data, params) do
    width = get_dimension(params, :width)
    height = get_dimension(params, :height)
    width_param = if width == 0, do: "auto", else: "#{width}"
    height_param = if height == 0, do: "auto", else: "#{height}"
    preserve_aspect_flag = get_preserve_aspect_flag(params)

    case Base.decode64(base64_data) do
      {:ok, decoded_data} ->
        size = byte_size(decoded_data)

        "\e]1337;File=inline=1;width=#{width_param};height=#{height_param};preserveAspectRatio=#{preserve_aspect_flag};size=#{size};name=image.png;base64,#{base64_data}\a"

      :error ->
        ""
    end
  end

  defp get_dimension(params, dimension) do
    cond do
      map?(params) -> Map.get(params, dimension, 0)
      tuple?(params) -> elem(params, if(dimension == :width, do: 0, else: 1))
      true -> 0
    end
  end

  defp get_preserve_aspect_flag(params) do
    case Map.get(params, :preserve_aspect) do
      nil -> "1"
      true -> "1"
      false -> "0"
    end
  end
end
