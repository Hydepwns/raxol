defmodule Raxol.MyApp do
  @moduledoc """
  A simple example Raxol application that displays typed text and an image on keypress.
  """
  use Raxol.App
  alias Raxol.View

  require Logger

  # Bring in View DSL functions
  import Raxol.View

  @impl Raxol.App
  def init(_opts) do
    # Initial state: empty text, no image sequence yet, not showing image
    initial_state = %{text: "", image_escape_sequence: nil, show_image: false}

    # Attempt to load and encode a sample image to generate the escape sequence
    image_path = "logo.png"

    case File.read(image_path) do
      {:ok, content} ->
        base64_data = Base.encode64(content)
        # Using 0 for width/height and 1 for preserve_aspect for auto-sizing
        params = %{width: 0, height: 0, preserve_aspect: true}
        # Directly generate the sequence (mimicking ImagePlugin logic)
        escape_sequence = generate_iterm_image_sequence(base64_data, params)
        Logger.info("[MyApp.init] Successfully loaded image and generated sequence.")
        %{initial_state | image_escape_sequence: escape_sequence}

      {:error, reason} ->
        Logger.warning("[MyApp.init] Could not load sample image '#{image_path}': #{reason}. Image sequence will be nil.")
        initial_state
    end
  end

  @impl Raxol.App
  def update(model, msg) do
    case msg do
      # Handle 'i' key to display image
      %{type: :key, modifiers: [], key: ?i} ->
        # Check if an image path/identifier is available (using escape_sequence presence as proxy)
        if model.image_escape_sequence do
          # Set flag to render the placeholder MARKER in the next frame
          Logger.info("[MyApp] Set show_image flag to true.")
          %{model | show_image: true}
        else
          Logger.info("[MyApp] No image available to display.")
          model # Return model unchanged
        end

      # Handle key events: append character if modifiers list is empty and key is an integer (char code)
      %{type: :key, modifiers: [], key: char} when is_integer(char) ->
        %{model | text: model.text <> <<char::utf8>>}

      # Handle backspace key (typically no modifiers)
      %{type: :key, modifiers: [], key: :backspace} ->
        new_text =
          if String.length(model.text) > 0 do
            String.slice(model.text, 0..-2//-1)
          else
            ""
          end

        %{model | text: new_text}

      # Handle 'q' key to quit
      %{type: :key, key: :q} ->
        {:stop, :normal, model}

      # Handle message from ImagePlugin after rendering
      {:image_rendered, :ok} ->
        Logger.debug("[MyApp] Received :image_rendered message. Resetting show_image.")
        %{model | show_image: false}

      # Log other messages for debugging (Restore original catch-all)
      unhandled_msg ->
        Logger.debug(
          "[MyApp] Received unhandled message: #{inspect(unhandled_msg)}"
        )
        model
    end
  end

  @impl Raxol.App
  @dialyzer {:nowarn_function, render: 1}
  def render(model) do
    # Construct the list of elements
    elements = [
      # Conditionally include the image placeholder
      if model.show_image do
        # Use the placeholder element again
        placeholder(:image)
      else
        nil # Represent absence with nil, let Runtime filter it
      end,
      text("Type 'i' to attempt image display (via Plugin)."),
      text("Type something:"),
      text("> #{model.text}")
    ]
    |> Enum.reject(&is_nil/1) # Filter out the nil if image isn't shown

    # Log the elements list right before wrapping
    # Logger.debug("[MyApp.render] Elements list BEFORE View.view wrap: #{inspect(elements)}")

    # Wrap the list in a root View element
    View.view do
      elements
    end
  end

  # Private helper to mimic ImagePlugin's sequence generation
  # Copied and adapted from ImagePlugin
  defp generate_iterm_image_sequence(base64_data, params) do
    width = if params.preserve_aspect, do: "auto", else: params.width
    height = if params.preserve_aspect, do: "auto", else: params.height
    preserve_aspect_flag = if params.preserve_aspect, do: "1", else: "0"

    decoded_result = Base.decode64(base64_data)

    case decoded_result do
      {:ok, decoded_data} ->
        size = byte_size(decoded_data)
        # Use IO.iodata_to_binary to handle potential escape sequences correctly
        # Construct sequence parts
        prefix = "\e]1337;File=inline=1"
        opts = "width=#{width};height=#{height};preserveAspectRatio=#{preserve_aspect_flag};size=#{size};name=logo.png"
        body = ";base64,#{base64_data}"
        suffix = "\a"
        # Concatenate parts
        prefix <> ";" <> opts <> body <> suffix

      :error ->
        Logger.error("[MyApp] Failed to decode base64 data for image sequence.")
        nil
    end
  end
end
