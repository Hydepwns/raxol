defmodule Raxol.Plugins.Visualization.ImageRenderer do
  @moduledoc """
  Handles rendering logic for image visualization within the VisualizationPlugin.
  Supports both sixel and kitty protocols for terminal image rendering.
  """

  require Raxol.Core.Runtime.Log
  alias Raxol.Terminal.Cell
  alias Raxol.Plugins.Visualization.DrawingUtils

  @doc """
  Public entry point for rendering image content.
  Handles bounds checking and calls the internal drawing logic.
  Expects bounds map: %{width: w, height: h}.
  """
  def render_image_content(
        data,
        opts,
        %{width: width, height: height} = bounds,
        state
      ) do
    title = Map.get(opts, :title, "Image")
    protocol = Map.get(opts, :protocol, detect_protocol(state))

    case width < 1 or height < 1 do
      true ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "[ImageRenderer] Bounds too small for image rendering: #{inspect(bounds)}",
          %{}
        )

        []

      false ->
        case Raxol.Core.ErrorHandling.safe_call(fn ->
               case protocol do
                 :sixel -> render_sixel(data, bounds, opts)
                 :kitty -> render_kitty(data, bounds, opts)
                 _ -> draw_placeholder(data, title, bounds)
               end
             end) do
          {:ok, result} ->
            result

          {:error, e} ->
            Raxol.Core.Runtime.Log.error(
              "[ImageRenderer] Error rendering image: #{inspect(e)}"
            )

            DrawingUtils.draw_box_with_text("[Render Error]", bounds)
        end
    end
  end

  defp detect_protocol(state) do
    case {supports_kitty?(state), supports_sixel?(state)} do
      {true, _} -> :kitty
      {_, true} -> :sixel
      {false, false} -> :placeholder
    end
  end

  defp supports_kitty?(state) do
    # Check for kitty protocol support
    term_program = get_in(state, [:terminal, :program])
    term_program == "kitty" or String.contains?(term_program || "", "kitty")
  end

  defp supports_sixel?(state) do
    # Check for sixel support
    _term_program = get_in(state, [:terminal, :program])
    term_features = get_in(state, [:terminal, :features]) || []
    "sixel" in term_features
  end

  defp render_sixel(data, bounds, opts) do
    case load_image_data(data) do
      {:ok, image_data} ->
        # Convert image to sixel format
        sixel_data = convert_to_sixel(image_data, bounds)
        # Create cells with sixel escape sequence
        create_sixel_cells(sixel_data, bounds)

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "[ImageRenderer] Failed to load image: #{inspect(reason)}"
        )

        draw_placeholder(data, Map.get(opts, :title, "Image"), bounds)
    end
  end

  defp render_kitty(data, bounds, opts) do
    case load_image_data(data) do
      {:ok, image_data} ->
        # Convert image to kitty format
        kitty_data = convert_to_kitty(image_data, bounds)
        # Create cells with kitty escape sequence
        create_kitty_cells(kitty_data, bounds)

      {:error, reason} ->
        Raxol.Core.Runtime.Log.error(
          "[ImageRenderer] Failed to load image: #{inspect(reason)}"
        )

        draw_placeholder(data, Map.get(opts, :title, "Image"), bounds)
    end
  end

  defp load_image_data(data) when is_binary(data) do
    # First try as file path, then as raw data
    case File.read(data) do
      {:ok, content} -> {:ok, content}
      # Assume it's raw image data
      {:error, _reason} -> {:ok, data}
    end
  end

  defp load_image_data(_), do: {:error, :invalid_data}

  defp convert_to_sixel(image_data, bounds) do
    # Decode and resize image to fit bounds
    with {:ok, image} <- decode_image(image_data),
         resized_image <- resize_image(image, bounds),
         sixel_data <- encode_sixel(resized_image) do
      sixel_data
    else
      _ -> "Failed to convert image to sixel format"
    end
  end

  defp decode_image(data) do
    # Use Mogrify to decode image data
    case Raxol.Core.ErrorHandling.safe_call(fn ->
           Mogrify.open(data)
         end) do
      {:ok, image} -> {:ok, image}
      {:error, e} -> {:error, Exception.message(e)}
    end
  end

  defp resize_image(image, %{width: width, height: height}) do
    # Resize image to fit terminal bounds
    image
    |> Mogrify.resize("#{width}x#{height}")
    |> Mogrify.format("png")
    |> Mogrify.save()
  end

  defp encode_sixel(_image) do
    # Convert image to sixel format using sixel encoder
    # This is a placeholder - you'll need to implement or use a sixel encoder library
    # For now, return a basic sixel pattern
    "\x1bPq\"1;1;1;1#0;2;0;0;0#1;2;100;100;100#2;2;0;100;0#1~~@@\x1b\\"
  end

  defp convert_to_kitty(image_data, bounds) do
    with {:ok, image} <- decode_image(image_data),
         resized_image <- resize_image(image, bounds) do
      # Convert to base64 and create kitty escape sequence
      base64_data = Base.encode64(resized_image.path)

      "\x1b_Ga=T,f=100,s=#{bounds.width},v=#{bounds.height},m=1;#{base64_data}\x1b\\"
    else
      _ -> "Failed to convert image to kitty format"
    end
  end

  defp create_sixel_cells(sixel_data, %{width: width, height: height}) do
    # For now, create placeholder cells until sixel is properly implemented
    # TODO: Implement proper sixel cell creation
    _ = sixel_data
    List.duplicate(List.duplicate(Cell.new(" "), width), height)
  end

  defp create_kitty_cells(kitty_data, %{width: width, height: height}) do
    # For now, create placeholder cells until kitty graphics is properly implemented
    # TODO: Implement proper kitty graphics cell creation
    _ = kitty_data
    List.duplicate(List.duplicate(Cell.new(" "), width), height)
  end

  # --- Private Image Drawing Logic ---

  @doc false
  # Draws a placeholder box indicating where the image would be.
  defp draw_placeholder(_data, title, bounds) do
    DrawingUtils.draw_box_with_text(title, bounds)
  end
end
