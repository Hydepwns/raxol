defmodule Raxol.Terminal.Graphics.Manager do
  @moduledoc """
  Manages terminal graphics operations including:
  - Image rendering to sixel format
  - Sixel data processing
  - Graphics pipeline optimization
  - Metrics tracking
  """

  defstruct [
    :images,
    :sixel_cache,
    :pipeline,
    :metrics
  ]

  @type t :: %__MODULE__{
          images: %{String.t() => map()},
          sixel_cache: %{String.t() => map()},
          pipeline: [function()],
          metrics: %{
            images_rendered: integer(),
            sixels_processed: integer(),
            cache_hits: integer(),
            cache_misses: integer(),
            pipeline_optimizations: integer()
          }
        }

  @doc """
  Creates a new graphics manager with default state.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{
      images: %{},
      sixel_cache: %{},
      pipeline: [
        &optimize_colors/1,
        &apply_dithering/1,
        &scale_image/1,
        &convert_to_sixel/1
      ],
      metrics: %{
        images_rendered: 0,
        sixels_processed: 0,
        cache_hits: 0,
        cache_misses: 0,
        pipeline_optimizations: 0
      }
    }
  end

  @doc """
  Renders an image to sixel format with the given options.
  """
  @spec render_image(t(), map(), map()) :: {:ok, map(), t()} | {:error, term()}
  def render_image(manager, image, opts) do
    with :ok <- validate_image(image),
         :ok <- validate_opts(opts) do
      cache_key = generate_cache_key(image, opts)

      case Map.get(manager.sixel_cache, cache_key) do
        nil ->
          # Cache miss - render image
          {:ok, sixel_data} = process_image(image, opts, manager.pipeline)

          updated_manager = %{
            manager
            | sixel_cache: Map.put(manager.sixel_cache, cache_key, sixel_data),
              metrics:
                update_metrics(manager.metrics, [
                  :images_rendered,
                  :cache_misses
                ])
          }

          {:ok, sixel_data, updated_manager}

        cached_data ->
          # Cache hit
          updated_manager = %{
            manager
            | metrics: update_metrics(manager.metrics, [:cache_hits])
          }

          {:ok, cached_data, updated_manager}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Processes sixel data into an image.
  """
  @spec process_sixel(t(), map()) :: {:ok, map(), t()} | {:error, term()}
  def process_sixel(manager, sixel_data) do
    case validate_sixel_data(sixel_data) do
      :ok ->
        image = %{
          width: sixel_data.width,
          height: sixel_data.height,
          pixels: convert_sixel_to_pixels(sixel_data),
          format: :sixel,
          metadata: %{}
        }

        updated_manager = %{
          manager
          | metrics: update_metrics(manager.metrics, [:sixels_processed])
        }

        {:ok, image, updated_manager}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Optimizes the graphics pipeline.
  """
  @spec optimize_pipeline(t()) :: {:ok, t()}
  def optimize_pipeline(manager) do
    # For now, just increment the optimization counter
    updated_manager = %{
      manager
      | metrics: update_metrics(manager.metrics, [:pipeline_optimizations])
    }

    {:ok, updated_manager}
  end

  @doc """
  Gets the current metrics.
  """
  @spec get_metrics(t()) :: map()
  def get_metrics(manager) do
    manager.metrics
  end

  # Private helper functions

  defp validate_image(image) do
    required_fields = [:width, :height, :pixels, :format]

    if Enum.all?(required_fields, &Map.has_key?(image, &1)) do
      :ok
    else
      {:error, :invalid_image}
    end
  end

  defp validate_opts(opts) do
    required_fields = [:scale, :dither, :optimize, :cache]

    if Enum.all?(required_fields, &Map.has_key?(opts, &1)) do
      :ok
    else
      {:error, :invalid_opts}
    end
  end

  defp validate_sixel_data(sixel_data) do
    required_fields = [:width, :height, :colors, :data]

    if Enum.all?(required_fields, &Map.has_key?(sixel_data, &1)) do
      :ok
    else
      {:error, :invalid_sixel_data}
    end
  end

  defp generate_cache_key(image, opts) do
    :crypto.hash(:sha256, :erlang.term_to_binary({image, opts}))
    |> Base.encode16()
  end

  defp process_image(image, opts, pipeline) do
    # Apply pipeline transformations to the image
    processed_image =
      Enum.reduce(pipeline, image, fn transform, acc ->
        transform.(acc)
      end)

    # Convert processed image to sixel format
    sixel_data = %{
      width: processed_image.width,
      height: processed_image.height,
      colors: extract_colors(processed_image.pixels),
      data: encode_sixel_data(processed_image.pixels)
    }

    {:ok, sixel_data}
  end

  defp extract_colors(pixels) do
    # Extract unique colors from pixels and create color palette
    pixels
    |> Enum.uniq_by(fn pixel -> {pixel.r, pixel.g, pixel.b} end)
    # Limit to 256 colors for sixel
    |> Enum.take(256)
    |> Enum.with_index()
    |> Enum.map(fn {pixel, index} ->
      %{r: pixel.r, g: pixel.g, b: pixel.b, a: pixel.a || 1.0, index: index}
    end)
  end

  defp encode_sixel_data(pixels) do
    # Encode pixels to sixel format
    pixels
    |> Enum.map(fn pixel ->
      # Convert RGB to color index (simplified mapping)
      color_index = trunc((pixel.r + pixel.g + pixel.b) / 3 / 255 * 255)
      max(0, min(255, color_index))
    end)
    |> :binary.list_to_bin()
  end

  defp optimize_colors(image) do
    # Optimize colors for terminal display by reducing color depth
    optimized_pixels =
      Enum.map(image.pixels, fn pixel ->
        %{
          # Reduce to 6 levels (0, 51, 102, 153, 204, 255)
          r: trunc(pixel.r / 51) * 51,
          g: trunc(pixel.g / 51) * 51,
          b: trunc(pixel.b / 51) * 51,
          a: pixel.a
        }
      end)

    %{image | pixels: optimized_pixels}
  end

  defp apply_dithering(image) do
    dithered_pixels =
      process_dithering_pixels(image.pixels, image.width, image.height)

    %{image | pixels: dithered_pixels}
  end

  defp process_dithering_pixels(pixels, width, height) do
    for y <- 0..(height - 1) do
      for x <- 0..(width - 1) do
        process_pixel_dithering(pixels, x, y, width, height)
      end
    end
    |> List.flatten()
  end

  defp process_pixel_dithering(pixels, x, y, width, height) do
    index = y * width + x
    pixel = Enum.at(pixels, index) || %{r: 0, g: 0, b: 0, a: 1.0}
    quantized = quantize_color(pixel)
    error = calculate_error(pixel, quantized)

    distribute_error(pixels, x, y, width, height, error)
    quantized
  end

  defp quantize_color(pixel) do
    # Quantize to 256 colors (8-bit per channel)
    %{
      r: trunc(pixel.r / 255 * 255),
      g: trunc(pixel.g / 255 * 255),
      b: trunc(pixel.b / 255 * 255),
      a: pixel.a
    }
  end

  defp calculate_error(original, quantized) do
    %{
      r: original.r - quantized.r,
      g: original.g - quantized.g,
      b: original.b - quantized.b
    }
  end

  defp distribute_error(pixels, x, y, width, height, error) do
    # Floyd-Steinberg error distribution to neighboring pixels
    distribute_to_pixel(pixels, x + 1, y, width, height, error, 7 / 16)
    distribute_to_pixel(pixels, x - 1, y + 1, width, height, error, 3 / 16)
    distribute_to_pixel(pixels, x, y + 1, width, height, error, 5 / 16)
    distribute_to_pixel(pixels, x + 1, y + 1, width, height, error, 1 / 16)
    pixels
  end

  defp distribute_to_pixel(pixels, x, y, width, height, error, factor) do
    if x >= 0 and x < width and y < height do
      index = y * width + x

      if index < length(pixels) do
        pixel = Enum.at(pixels, index)

        updated_pixel = %{
          pixel
          | r: max(0, min(255, pixel.r + error.r * factor)),
            g: max(0, min(255, pixel.g + error.g * factor)),
            b: max(0, min(255, pixel.b + error.b * factor))
        }

        List.replace_at(pixels, index, updated_pixel)
      else
        pixels
      end
    else
      pixels
    end
  end

  defp scale_image(image) do
    # Scale image based on terminal constraints
    max_width = 80
    max_height = 24

    scale_x = min(1.0, max_width / image.width)
    scale_y = min(1.0, max_height / image.height)
    scale = min(scale_x, scale_y)

    if scale < 1.0 do
      %{
        image
        | width: trunc(image.width * scale),
          height: trunc(image.height * scale),
          pixels: scale_pixels(image.pixels, image.width, image.height, scale)
      }
    else
      image
    end
  end

  defp scale_pixels(pixels, original_width, original_height, scale) do
    new_width = trunc(original_width * scale)
    new_height = trunc(original_height * scale)

    # Simple nearest neighbor scaling
    for y <- 0..(new_height - 1) do
      for x <- 0..(new_width - 1) do
        src_x = trunc(x / scale)
        src_y = trunc(y / scale)
        index = src_y * original_width + src_x
        Enum.at(pixels, index) || %{r: 0, g: 0, b: 0, a: 1.0}
      end
    end
    |> List.flatten()
  end

  defp convert_to_sixel(image) do
    # Convert image to sixel format
    %{
      width: image.width,
      height: image.height,
      colors: extract_colors(image.pixels),
      data: encode_sixel_data(image.pixels)
    }
  end

  defp convert_sixel_to_pixels(sixel_data) do
    # Convert sixel data to pixel array
    sixel_data.data
    |> :binary.bin_to_list()
    |> Enum.map(fn color_index ->
      color =
        Enum.at(sixel_data.colors, color_index) || %{r: 0, g: 0, b: 0, a: 1.0}

      %{r: color.r, g: color.g, b: color.b, a: color.a}
    end)
  end

  defp update_metrics(metrics, keys) do
    Enum.reduce(keys, metrics, fn key, acc ->
      update_in(acc[key], &(&1 + 1))
    end)
  end
end
