defmodule Raxol.UI.Charts.BrailleCanvas do
  @moduledoc """
  A dot-addressable canvas that renders to Unicode braille characters.

  Each terminal character maps to a 2x4 dot region, giving 2x horizontal
  and 4x vertical resolution compared to character-grid rendering.

  Supports multiple named layers for multicolor output: each layer's dots
  are independently tracked, then merged into braille codepoints at render
  time. The foreground color of each character cell goes to the layer with
  the most dots in that cell's 2x4 region.
  """

  @type t :: %__MODULE__{
          width: pos_integer(),
          height: pos_integer(),
          layers: %{term() => MapSet.t({non_neg_integer(), non_neg_integer()})}
        }

  @type cell :: Raxol.UI.Charts.ChartUtils.cell()

  defstruct [:width, :height, layers: %{}]

  # Braille dot positions within a character cell:
  # (0,0) (1,0)    bits: 0x01 0x08
  # (0,1) (1,1)          0x02 0x10
  # (0,2) (1,2)          0x04 0x20
  # (0,3) (1,3)          0x40 0x80
  @braille_base 0x2800

  @braille_offsets %{
    {0, 0} => 0x01,
    {0, 1} => 0x02,
    {0, 2} => 0x04,
    {0, 3} => 0x40,
    {1, 0} => 0x08,
    {1, 1} => 0x10,
    {1, 2} => 0x20,
    {1, 3} => 0x80
  }

  @doc """
  Creates a new canvas sized in terminal characters.
  Dot resolution is `{width * 2, height * 4}`.
  """
  @spec new(pos_integer(), pos_integer()) :: t()
  def new(width_chars, height_chars) do
    %__MODULE__{width: width_chars, height: height_chars}
  end

  @doc """
  Returns the dot-resolution dimensions `{dot_width, dot_height}`.
  """
  @spec get_dimensions(t()) :: {pos_integer(), pos_integer()}
  def get_dimensions(%__MODULE__{width: w, height: h}), do: {w * 2, h * 4}

  @doc """
  Places a dot at `{dot_x, dot_y}` on the given layer.
  Out-of-bounds dots are silently ignored.
  """
  @spec put_dot(t(), non_neg_integer(), non_neg_integer(), term()) :: t()
  def put_dot(%__MODULE__{width: w, height: h} = canvas, dot_x, dot_y, layer_id) do
    if dot_x >= 0 and dot_x < w * 2 and dot_y >= 0 and dot_y < h * 4 do
      layer = Map.get(canvas.layers, layer_id, MapSet.new())
      updated = MapSet.put(layer, {dot_x, dot_y})
      %{canvas | layers: Map.put(canvas.layers, layer_id, updated)}
    else
      canvas
    end
  end

  @doc """
  Converts the canvas to cell tuples with a single foreground color.
  All layers' dots contribute to the braille codepoint.
  """
  @spec to_cells(t(), {non_neg_integer(), non_neg_integer()}, atom()) :: [
          cell()
        ]
  def to_cells(%__MODULE__{} = canvas, {origin_x, origin_y}, color) do
    all_dots = merge_all_layers(canvas)

    for cy <- 0..(canvas.height - 1),
        cx <- 0..(canvas.width - 1) do
      codepoint = compute_codepoint(all_dots, cx * 2, cy * 4)
      {origin_x + cx, origin_y + cy, <<codepoint::utf8>>, color, :default, %{}}
    end
  end

  @doc """
  Converts the canvas to cell tuples with per-layer colors.

  `color_map` maps `layer_id => color_atom`. Each character cell's fg color
  is assigned to whichever layer has the most dots in that cell's 2x4 region.
  Ties are broken by the order of layers in the color_map (earlier wins).
  The braille codepoint is the bitwise OR of all layers' dots.
  """
  @spec to_cells_multicolor(
          t(),
          {non_neg_integer(), non_neg_integer()},
          %{term() => atom()}
        ) :: [cell()]
  def to_cells_multicolor(
        %__MODULE__{} = canvas,
        {origin_x, origin_y},
        color_map
      ) do
    for cy <- 0..(canvas.height - 1),
        cx <- 0..(canvas.width - 1) do
      char_x = cx * 2
      char_y = cy * 4

      {codepoint, winning_color} =
        compute_multicolor_cell(canvas.layers, color_map, char_x, char_y)

      {origin_x + cx, origin_y + cy, <<codepoint::utf8>>, winning_color,
       :default, %{}}
    end
  end

  # -- Private --

  defp merge_all_layers(%__MODULE__{layers: layers}) do
    layers
    |> Map.values()
    |> Enum.reduce(MapSet.new(), &MapSet.union/2)
  end

  defp compute_codepoint(dots, base_x, base_y) do
    Enum.reduce(@braille_offsets, @braille_base, fn {{dx, dy}, bit}, acc ->
      if MapSet.member?(dots, {base_x + dx, base_y + dy}) do
        Bitwise.bor(acc, bit)
      else
        acc
      end
    end)
  end

  defp compute_multicolor_cell(layers, color_map, char_x, char_y) do
    dot_positions =
      for {dx, dy} <- Map.keys(@braille_offsets), do: {char_x + dx, char_y + dy}

    # Count dots per layer and compute combined codepoint
    {codepoint, counts} =
      Enum.reduce(layers, {@braille_base, %{}}, fn {layer_id, dot_set},
                                                   {cp_acc, count_acc} ->
        layer_count =
          Enum.count(dot_positions, fn pos -> MapSet.member?(dot_set, pos) end)

        layer_cp =
          Enum.reduce(@braille_offsets, 0, fn {{dx, dy}, bit}, acc ->
            if MapSet.member?(dot_set, {char_x + dx, char_y + dy}) do
              Bitwise.bor(acc, bit)
            else
              acc
            end
          end)

        {Bitwise.bor(cp_acc, layer_cp),
         if(layer_count > 0,
           do: Map.put(count_acc, layer_id, layer_count),
           else: count_acc
         )}
      end)

    # Pick the winning color: most dots, then first in color_map order
    winning_color =
      if map_size(counts) == 0 do
        color_map |> Map.values() |> List.first(:default)
      else
        color_map
        |> Enum.filter(fn {lid, _} -> Map.has_key?(counts, lid) end)
        |> Enum.max_by(fn {lid, _} -> Map.get(counts, lid, 0) end)
        |> elem(1)
      end

    {codepoint, winning_color}
  end
end
