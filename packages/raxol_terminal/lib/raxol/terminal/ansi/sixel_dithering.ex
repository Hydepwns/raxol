defmodule Raxol.Terminal.ANSI.SixelDithering do
  @moduledoc """
  Dithering algorithms for Sixel image color quantization.

  Operates on a `SixelGraphics` struct that has a populated `pixel_buffer`
  (palette indices) and `palette` (index -> {r,g,b} map). Reconstructs the
  RGB color grid, applies the chosen dithering algorithm, and re-maps pixels
  to palette indices.

  Supported algorithms:
  - `:floyd_steinberg` -- error diffusion (best quality, serial scan)
  - `:ordered` -- Bayer 4x4 threshold matrix (fast, deterministic pattern)
  - `:random` -- random noise perturbation (fast, non-deterministic)
  """

  alias Raxol.Terminal.ANSI.SixelGraphics

  @doc """
  Applies the specified dithering algorithm to the image.

  Returns the image with an updated `pixel_buffer` and `dithering_algorithm` flag.
  Images with empty pixel_buffer or palette are returned with only the flag set.
  """
  @spec apply(SixelGraphics.t(), SixelGraphics.dithering_algorithm()) ::
          SixelGraphics.t()
  def apply(image, :none), do: image
  def apply(image, :floyd_steinberg), do: floyd_steinberg(image)
  def apply(image, :ordered), do: ordered(image)
  def apply(image, :random), do: random(image)
  def apply(image, _), do: image

  # -- Floyd-Steinberg error diffusion --

  defp floyd_steinberg(%SixelGraphics{} = image) do
    if empty?(image) do
      %{image | dithering_algorithm: :floyd_steinberg}
    else
      {w, h} = dimensions(image.pixel_buffer)
      palette_list = Map.to_list(image.palette)
      color_grid = build_color_grid(image.pixel_buffer, image.palette, w, h)

      {new_buffer, _} =
        Enum.reduce(0..(h - 1), {%{}, color_grid}, fn y, {buf, grid} ->
          Enum.reduce(0..(w - 1), {buf, grid}, fn x, {b, g} ->
            {r, gv, bl} = Map.get(g, {x, y}, {0, 0, 0})
            {idx, {pr, pg, pb}} = nearest_color({r, gv, bl}, palette_list)

            er = r - pr
            eg = gv - pg
            eb = bl - pb

            g2 =
              g
              |> diffuse({x + 1, y}, er, eg, eb, 7, w, h)
              |> diffuse({x - 1, y + 1}, er, eg, eb, 3, w, h)
              |> diffuse({x, y + 1}, er, eg, eb, 5, w, h)
              |> diffuse({x + 1, y + 1}, er, eg, eb, 1, w, h)

            {Map.put(b, {x, y}, idx), g2}
          end)
        end)

      %{image | pixel_buffer: new_buffer, dithering_algorithm: :floyd_steinberg}
    end
  end

  defp diffuse(grid, {x, y}, er, eg, eb, weight, w, h) do
    if x >= 0 and x < w and y >= 0 and y < h do
      {r, g, b} = Map.get(grid, {x, y}, {0, 0, 0})
      f = weight / 16.0

      Map.put(grid, {x, y}, {
        clamp(round(r + er * f)),
        clamp(round(g + eg * f)),
        clamp(round(b + eb * f))
      })
    else
      grid
    end
  end

  # -- Ordered (Bayer 4x4) dithering --

  # 4x4 Bayer threshold matrix (values 0-255)
  @bayer [
    [0, 128, 32, 160],
    [192, 64, 224, 96],
    [48, 176, 16, 144],
    [240, 112, 208, 80]
  ]

  defp ordered(%SixelGraphics{} = image) do
    if empty?(image) do
      %{image | dithering_algorithm: :ordered}
    else
      {w, h} = dimensions(image.pixel_buffer)
      palette_list = Map.to_list(image.palette)
      color_grid = build_color_grid(image.pixel_buffer, image.palette, w, h)

      new_buffer =
        for y <- 0..(h - 1), x <- 0..(w - 1), into: %{} do
          {r, g, b} = Map.get(color_grid, {x, y}, {0, 0, 0})

          threshold = @bayer |> Enum.at(rem(y, 4)) |> Enum.at(rem(x, 4))
          offset = (threshold - 128) * 64 / 255.0

          perturbed =
            {clamp(round(r + offset)), clamp(round(g + offset)), clamp(round(b + offset))}

          {idx, _} = nearest_color(perturbed, palette_list)
          {{x, y}, idx}
        end

      %{image | pixel_buffer: new_buffer, dithering_algorithm: :ordered}
    end
  end

  # -- Random noise dithering --

  defp random(%SixelGraphics{} = image) do
    if empty?(image) do
      %{image | dithering_algorithm: :random}
    else
      {w, h} = dimensions(image.pixel_buffer)
      palette_list = Map.to_list(image.palette)
      color_grid = build_color_grid(image.pixel_buffer, image.palette, w, h)

      new_buffer =
        for y <- 0..(h - 1), x <- 0..(w - 1), into: %{} do
          {r, g, b} = Map.get(color_grid, {x, y}, {0, 0, 0})

          nr = :rand.uniform(65) - 33
          ng = :rand.uniform(65) - 33
          nb = :rand.uniform(65) - 33

          perturbed = {clamp(r + nr), clamp(g + ng), clamp(b + nb)}

          {idx, _} = nearest_color(perturbed, palette_list)
          {{x, y}, idx}
        end

      %{image | pixel_buffer: new_buffer, dithering_algorithm: :random}
    end
  end

  # -- Shared helpers --

  defp empty?(%{pixel_buffer: pb, palette: p}),
    do: map_size(pb) == 0 or map_size(p) == 0

  defp dimensions(pixel_buffer) do
    keys = Map.keys(pixel_buffer)
    max_x = keys |> Enum.map(&elem(&1, 0)) |> Enum.max(fn -> 0 end)
    max_y = keys |> Enum.map(&elem(&1, 1)) |> Enum.max(fn -> 0 end)
    {max_x + 1, max_y + 1}
  end

  defp build_color_grid(pixel_buffer, palette, w, h) do
    for y <- 0..(h - 1), x <- 0..(w - 1), into: %{} do
      color =
        case Map.get(pixel_buffer, {x, y}) do
          nil -> {0, 0, 0}
          idx -> Map.get(palette, idx, {0, 0, 0})
        end

      {{x, y}, color}
    end
  end

  defp nearest_color(rgb, palette_list) do
    Raxol.Terminal.ANSI.SixelPalette.nearest_color(rgb, palette_list)
  end

  defp clamp(v) when v < 0, do: 0
  defp clamp(v) when v > 255, do: 255
  defp clamp(v), do: v
end
