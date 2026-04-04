defmodule Raxol.UI.Layout.CSSGrid.TrackParser do
  @moduledoc """
  Parses CSS Grid track definitions (grid-template-columns / grid-template-rows).

  Handles fr, px, percent, minmax, auto, min-content, max-content, and
  repeat() notation.
  """

  @default_auto_repeat_count 5

  alias Raxol.UI.Layout.CSSGrid.Track

  @doc "Parse a track-list string into a list of Track structs."
  def parse_grid_tracks("none", _available_size), do: []

  def parse_grid_tracks(tracks_str, available_size)
      when is_binary(tracks_str) do
    tracks_str
    |> String.split(~r/\s+/)
    |> Enum.filter(&(&1 != ""))
    |> expand_repeat_notation()
    |> Enum.map(&parse_track(&1, available_size))
  end

  def parse_grid_tracks(tracks, _available_size) when is_list(tracks) do
    Enum.map(tracks, &parse_track(&1, 0))
  end

  def parse_grid_tracks(_, _available_size), do: []

  # ---------------------------------------------------------------------------
  # repeat() expansion
  # ---------------------------------------------------------------------------

  def expand_repeat_notation(tracks) do
    Enum.flat_map(tracks, &expand_track_notation/1)
  end

  def expand_track_notation("repeat(" <> _ = track), do: expand_repeat(track)
  def expand_track_notation(track), do: [track]

  def expand_repeat(repeat_str) do
    content =
      repeat_str
      |> String.trim_leading("repeat(")
      |> String.trim_trailing(")")

    case String.split(content, ",", parts: 2) do
      [count_str, pattern] ->
        expand_by_count_type(
          String.trim(count_str),
          String.trim(pattern),
          repeat_str
        )

      _ ->
        [repeat_str]
    end
  end

  def expand_by_count_type("auto-fit", pattern, _repeat_str),
    do: List.duplicate(pattern, @default_auto_repeat_count)

  def expand_by_count_type("auto-fill", pattern, _repeat_str),
    do: List.duplicate(pattern, @default_auto_repeat_count)

  def expand_by_count_type(count_str, pattern, repeat_str) do
    case Integer.parse(count_str) do
      {count, ""} -> List.duplicate(pattern, count)
      _ -> [repeat_str]
    end
  end

  # ---------------------------------------------------------------------------
  # Individual track parsing
  # ---------------------------------------------------------------------------

  def parse_track(track_str, available_size) do
    parse_track_by_type(track_str, available_size)
  end

  def parse_track_by_type(track_str, available_size)
      when is_binary(track_str) do
    case track_str do
      "auto" -> Track.new(:auto, 0)
      "min-content" -> Track.new(:min_content, 0)
      "max-content" -> Track.new(:max_content, 0)
      _ -> parse_track_by_suffix(track_str, available_size)
    end
  end

  def parse_track_by_type(_track_str, _available_size), do: Track.new(:auto, 0)

  def parse_track_by_suffix(track_str, available_size) do
    with :error <- try_parse_fr_track(track_str),
         :error <- try_parse_px_track(track_str),
         :error <- try_parse_percent_track(track_str, available_size),
         :error <- try_parse_minmax_track(track_str, available_size) do
      parse_fallback_track(track_str)
    else
      {:ok, result} -> result
    end
  end

  def try_parse_fr_track(track_str) do
    if String.ends_with?(track_str, "fr"),
      do: {:ok, parse_fr_track(track_str)},
      else: :error
  end

  def try_parse_px_track(track_str) do
    if String.ends_with?(track_str, "px"),
      do: {:ok, parse_px_track(track_str)},
      else: :error
  end

  def try_parse_percent_track(track_str, available_size) do
    if String.ends_with?(track_str, "%"),
      do: {:ok, parse_percent_track(track_str, available_size)},
      else: :error
  end

  def try_parse_minmax_track(track_str, available_size) do
    if String.starts_with?(track_str, "minmax("),
      do: {:ok, parse_minmax_track(track_str, available_size)},
      else: :error
  end

  def parse_fr_track(track_str) do
    {value, "fr"} = Float.parse(track_str)
    Track.new(:fr, value)
  end

  def parse_px_track(track_str) do
    {value, "px"} = Integer.parse(track_str)
    Track.new(:fixed, value)
  end

  def parse_percent_track(track_str, available_size) do
    {value, "%"} = Float.parse(track_str)
    Track.new(:fixed, div(available_size * trunc(value), 100))
  end

  def parse_fallback_track(track_str) do
    case Integer.parse(track_str) do
      {value, ""} -> Track.new(:fixed, value)
      _ -> Track.new(:auto, 0)
    end
  end

  def parse_minmax_track(minmax_str, available_size) do
    content =
      minmax_str
      |> String.trim_leading("minmax(")
      |> String.trim_trailing(")")

    case String.split(content, ",") do
      [min_str, max_str] ->
        min_track = parse_track(String.trim(min_str), available_size)
        max_track = parse_track(String.trim(max_str), available_size)
        Track.new(:minmax, %{min: min_track, max: max_track})

      _ ->
        Track.new(:auto, 0)
    end
  end
end
