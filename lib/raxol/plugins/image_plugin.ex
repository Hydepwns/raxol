defmodule Raxol.Plugins.ImagePlugin do
  @moduledoc """
  Plugin that enables displaying images in the terminal using the iTerm2 image protocol.
  Supports various image formats and provides options for image display.
  """

  @behaviour Raxol.Plugins.Plugin
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
  def handle_cells(placeholder_cell, _emulator_state, %__MODULE__{} = plugin) do
    Raxol.Core.Runtime.Log.debug(
      "[ImagePlugin.handle_cells START] Received placeholder: #{inspect(placeholder_cell)}, plugin state: #{inspect(plugin)}"
    )

    case placeholder_cell do
      %{type: :placeholder, value: :image} = cell
      when is_map_key(cell, :type) and is_map_key(cell, :value) ->
        Raxol.Core.Runtime.Log.debug(
          "[ImagePlugin.handle_cells] Matched :image placeholder. sequence_just_generated: #{inspect(plugin.sequence_just_generated)}"
        )

        # If we just generated the sequence in the *last* call for *this same placeholder*,
        # reset the flag and return {:cont, state} to avoid re-generating/re-sending.
        if plugin.sequence_just_generated do
          Raxol.Core.Runtime.Log.debug(
            "[ImagePlugin.handle_cells] sequence_just_generated=true. Resetting flag and declining."
          )

          {:cont, %{plugin | sequence_just_generated: false}}
        else
          # Attempt to generate the sequence
          Raxol.Core.Runtime.Log.debug(
            "[ImagePlugin.handle_cells] sequence_just_generated=false. BEFORE generate_sequence_from_path for path: @static/static/images/logo.png"
          )

          case generate_sequence_from_path("@static/static/images/logo.png") do
            {:ok, sequence} ->
              Raxol.Core.Runtime.Log.debug(
                "[ImagePlugin.handle_cells] Sequence generated successfully."
              )

              # Return {:ok, state_with_flag_set, cells_to_render, command_to_send}
              # Cells to render is empty because the command handles the display.
              # Mark sequence_just_generated as true for the *next* call.
              # Wrap command in a list as expected by plugin manager
              {:ok, %{plugin | sequence_just_generated: true}, [],
               [{:direct_output, sequence}]}

            {:error, reason} ->
              Raxol.Core.Runtime.Log.error(
                "[ImagePlugin.handle_cells] Failed to generate sequence for @static/static/images/logo.png: #{inspect(reason)}"
              )

              # Failed to generate, decline to handle the placeholder
              # Return original state
              {:cont, plugin}
          end
        end

      _ ->
        # Not an image placeholder, decline
        {:cont, plugin}
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
    width =
      if is_map(params),
        do: Map.get(params, :width, 0),
        else: if(is_tuple(params), do: elem(params, 0), else: 0)

    height =
      if is_map(params),
        do: Map.get(params, :height, 0),
        else: if(is_tuple(params), do: elem(params, 1), else: 0)

    width_param = if width == 0, do: "auto", else: "#{width}"
    height_param = if height == 0, do: "auto", else: "#{height}"

    # Fix: Use a conditional instead of Map.get with a default that might trigger guard failures
    preserve_aspect_flag =
      case Map.get(params, :preserve_aspect) do
        # Default to true when nil
        nil -> "1"
        true -> "1"
        false -> "0"
      end

    decoded_result = Base.decode64(base64_data)

    case decoded_result do
      {:ok, decoded_data} ->
        size = byte_size(decoded_data)

        "\e]1337;File=inline=1;width=#{width_param};height=#{height_param};preserveAspectRatio=#{preserve_aspect_flag};size=#{size};name=image.png;base64,#{base64_data}\a"

      :error ->
        ""
    end
  end

  # Comment out unused helpers
  # defp find_image_at_position(_plugin, _x, _y) do ... end
  # defp handle_image_click(%__MODULE__{} = plugin, _image, _x, _y) do ... end
end
