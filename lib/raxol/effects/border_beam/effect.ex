defmodule Raxol.Effects.BorderBeam.Effect do
  @moduledoc """
  Contract + shared helpers for border-effect implementations.

  Each effect (`Stroke`, `Pulse`, `Flames`, `Electric`, `Clouds`) implements
  `apply/4`, taking a cell map, the box bounds, the hint opts, and the
  current monotonic time in milliseconds. Effects return a new cell map
  with style and/or character mutations applied.

  ## Cell representation

  A `cell_map` is `%{{x, y} => {x, y, char, fg, bg, attrs}}` -- the same
  six-tuple shape produced by `Raxol.UI.Renderer`, indexed by coordinate
  for O(1) modification. `Raxol.Effects.BorderBeam.CellApplier` builds the
  index, dispatches to the effect by `:type`, and unrolls back to a list.

  ## Time-based determinism

  Animation progress is derived from `now_ms` only. No effect maintains
  state between calls; the same `now_ms` always produces the same output
  for a given hint+bounds. For random-looking effects (flames, electric),
  use `time_bucket/2` + `bucket_hash/3` to produce reproducible-per-tick
  noise.
  """

  @type cell ::
          {non_neg_integer(), non_neg_integer(), String.t(), any(), any(),
           list()}
  @type cell_map :: %{{non_neg_integer(), non_neg_integer()} => cell()}
  @type bounds :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: pos_integer(),
          height: pos_integer()
        }

  @doc """
  Apply the effect to the cell map.

  - `cells` is the keyed cell index produced by `CellApplier`.
  - `bounds` are the positioned box dimensions.
  - `opts` is the raw hint map (`:variant`, `:strength`, plus per-effect keys).
  - `now_ms` is the monotonic millisecond clock at frame time.
  """
  @callback apply(
              cells :: cell_map(),
              bounds :: bounds(),
              opts :: map(),
              now_ms :: integer()
            ) ::
              cell_map()

  @doc """
  Returns the perimeter as a tuple for O(1) `elem/2` access. Order is
  clockwise from the top-left corner: top edge, right edge, bottom edge
  (right-to-left), left edge (bottom-to-top).
  """
  @spec perimeter(bounds()) :: {tuple(), pos_integer()}
  def perimeter(%{x: bx, y: by, width: w, height: h}) do
    right = bx + w - 1
    bottom = by + h - 1

    top_row = for x <- bx..right, do: {x, by}
    right_col = for y <- (by + 1)..(bottom - 1)//1, do: {right, y}
    bottom_row = for x <- right..bx//-1, do: {x, bottom}
    left_col = for y <- (bottom - 1)..(by + 1)//-1, do: {bx, y}

    list = top_row ++ right_col ++ bottom_row ++ left_col
    {List.to_tuple(list), length(list)}
  end

  @doc """
  Replace the foreground color and intensity attrs of a cell.

  Returns the cell map unchanged if no cell exists at `{x, y}`.
  """
  @spec restyle_fg(cell_map(), integer(), integer(), atom(), float()) ::
          cell_map()
  def restyle_fg(cells, x, y, color, intensity) do
    case Map.get(cells, {x, y}) do
      nil ->
        cells

      {cx, cy, char, _fg, bg, attrs} ->
        Map.put(
          cells,
          {x, y},
          {cx, cy, char, color, bg, intensity_attrs(attrs, intensity)}
        )
    end
  end

  @doc """
  Replace the character, foreground, and intensity attrs of a cell.

  Used by char-replacing effects (flames, electric). No-op if the cell
  does not exist.
  """
  @spec restyle_char(
          cell_map(),
          integer(),
          integer(),
          String.t(),
          atom(),
          float()
        ) ::
          cell_map()
  def restyle_char(cells, x, y, char, color, intensity) do
    case Map.get(cells, {x, y}) do
      nil ->
        cells

      {cx, cy, _old_char, _fg, bg, attrs} ->
        Map.put(
          cells,
          {x, y},
          {cx, cy, char, color, bg, intensity_attrs(attrs, intensity)}
        )
    end
  end

  @doc """
  Maps an intensity (0.0-1.0) to terminal style attrs. `:bold` for bright,
  plain for mid-range, `:dim` for low. Strips any pre-existing intensity
  attrs so re-applying is idempotent.

  Empty-attrs fast path skips the `Enum.reject` allocation, which is the
  vast majority of cells in a freshly rendered border.
  """
  @spec intensity_attrs(list(), float()) :: list()
  def intensity_attrs([], intensity) do
    cond do
      intensity >= 0.65 -> [:bold]
      intensity >= 0.25 -> []
      true -> [:dim]
    end
  end

  def intensity_attrs(attrs, intensity) when is_list(attrs) do
    cleaned = Enum.reject(attrs, &(&1 in [:bold, :dim]))

    cond do
      intensity >= 0.65 -> [:bold | cleaned]
      intensity >= 0.25 -> cleaned
      true -> [:dim | cleaned]
    end
  end

  def intensity_attrs(_attrs, intensity), do: intensity_attrs([], intensity)

  @doc """
  Returns a discrete time bucket for the given millisecond clock and
  bucket size. Used to keep random-but-deterministic effects stable for
  ~`bucket_ms` between changes.
  """
  @spec time_bucket(integer(), pos_integer()) :: integer()
  def time_bucket(now_ms, bucket_ms), do: div(now_ms, bucket_ms)

  @doc """
  Reproducible non-negative integer hash from a `{bucket, x, y}` triple.
  Use to drive char/color choices that should be stable within a bucket
  but vary across cells and time.
  """
  @spec bucket_hash(integer(), integer(), integer()) :: non_neg_integer()
  def bucket_hash(bucket, x, y), do: :erlang.phash2({bucket, x, y})
end
