defmodule Raxol.UI.Components.Input.TextWrappingCached do
  @moduledoc """
  Cached version of text wrapping utilities with performance optimizations.

  This module extends the basic TextWrapping functionality with caching
  for improved performance on repeated operations.
  """

  # Cache for visual widths to avoid recalculating
  @cache_name :text_wrapping_cache

  @doc """
  Initializes the cache if not already present.
  """
  def ensure_cache do
    unless :ets.whereis(@cache_name) != :undefined do
      :ets.new(@cache_name, [:set, :public, :named_table])
    end
  end

  @doc """
  Wraps text by visual width with caching.
  """
  def wrap_line_by_visual_width(text, width)
      when is_binary(text) and is_integer(width) and width > 0 do
    _ = ensure_cache()

    cache_key = {:visual_width_wrap, text, width}

    case :ets.lookup(@cache_name, cache_key) do
      [{^cache_key, result}] ->
        result

      [] ->
        # Use basic word wrapping as approximation for visual width
        result = wrap_by_visual_width_impl(text, width)
        :ets.insert(@cache_name, {cache_key, result})
        result
    end
  end

  def wrap_line_by_visual_width("", _width), do: []

  @doc """
  Wraps text by word boundaries with caching.
  """
  def wrap_line_by_word(text, width)
      when is_binary(text) and is_integer(width) and width > 0 do
    _ = ensure_cache()

    cache_key = {:word_wrap, text, width}

    case :ets.lookup(@cache_name, cache_key) do
      [{^cache_key, result}] ->
        result

      [] ->
        result = wrap_by_word_impl(text, width)
        :ets.insert(@cache_name, {cache_key, result})
        result
    end
  end

  def wrap_line_by_word("", _width), do: []

  @doc """
  Gets the visual width of text with caching.
  """
  def get_visual_width(text) when is_binary(text) do
    _ = ensure_cache()

    cache_key = {:visual_width, text}

    case :ets.lookup(@cache_name, cache_key) do
      [{^cache_key, width}] ->
        width

      [] ->
        width = calculate_visual_width(text)
        :ets.insert(@cache_name, {cache_key, width})
        width
    end
  end

  @doc """
  Warms up the cache with common strings.
  """
  def warmup_cache(strings) when is_list(strings) do
    _ = ensure_cache()

    Enum.each(strings, fn string ->
      # Pre-calculate and cache visual width
      get_visual_width(string)

      # Pre-calculate common wrap widths
      for width <- [20, 40, 60, 80] do
        wrap_line_by_word(string, width)
        wrap_line_by_visual_width(string, width)
      end
    end)

    :ok
  end

  @doc """
  Wraps text based on pixel width and font metrics.
  """
  def wrap_to_pixel_width(text, pixel_width, font_manager) do
    _ = ensure_cache()

    cache_key = {:pixel_wrap, text, pixel_width, font_manager}

    case :ets.lookup(@cache_name, cache_key) do
      [{^cache_key, result}] ->
        result

      [] ->
        # Estimate character width from pixel width and font
        char_width = estimate_char_width_from_pixels(pixel_width, font_manager)
        result = wrap_line_by_word(text, char_width)
        :ets.insert(@cache_name, {cache_key, result})
        result
    end
  end

  # Private implementation functions

  defp wrap_by_visual_width_impl("", _width), do: []

  defp wrap_by_visual_width_impl(text, width) do
    # Split text into words and wrap based on visual width
    words = String.split(text, " ")
    wrap_words_by_visual_width(words, width, [], [])
  end

  defp wrap_words_by_visual_width([], _width, [], lines) do
    Enum.reverse(lines)
  end

  defp wrap_words_by_visual_width([], _width, current_line, lines) do
    completed_line = Enum.join(Enum.reverse(current_line), " ")
    Enum.reverse([completed_line | lines])
  end

  defp wrap_words_by_visual_width([word | rest], width, current_line, lines) do
    current_text =
      if current_line == [],
        do: "",
        else: Enum.join(Enum.reverse(current_line), " ")

    new_text =
      if current_line == [], do: word, else: current_text <> " " <> word

    if calculate_visual_width(new_text) <= width do
      wrap_words_by_visual_width(rest, width, [word | current_line], lines)
    else
      # Check if we can fit just the word on current line
      if current_line == [] do
        # Word is too long, but we need to place it somewhere
        if calculate_visual_width(word) > width do
          # Break the word itself
          word_parts = break_word_by_visual_width(word, width)
          first_part = List.first(word_parts)
          remaining_parts = Enum.drop(word_parts, 1)
          # Add remaining parts back to processing queue
          updated_rest = Enum.map(remaining_parts, & &1) ++ rest

          wrap_words_by_visual_width(updated_rest, width, [], [
            first_part | lines
          ])
        else
          wrap_words_by_visual_width(rest, width, [word], lines)
        end
      else
        # Complete current line and start new line with current word
        completed_line = Enum.join(Enum.reverse(current_line), " ")

        wrap_words_by_visual_width([word | rest], width, [], [
          completed_line | lines
        ])
      end
    end
  end

  defp break_word_by_visual_width(word, width) do
    graphemes = String.graphemes(word)
    break_graphemes_by_visual_width(graphemes, width, [], [], 0)
  end

  defp break_graphemes_by_visual_width(
         [],
         _width,
         current_part,
         parts,
         _current_width
       ) do
    final_parts =
      if current_part != [],
        do: [Enum.join(Enum.reverse(current_part), "") | parts],
        else: parts

    Enum.reverse(final_parts)
  end

  defp break_graphemes_by_visual_width(
         [char | rest],
         width,
         current_part,
         parts,
         current_width
       ) do
    char_width = calculate_visual_width(char)
    new_width = current_width + char_width

    if new_width <= width do
      break_graphemes_by_visual_width(
        rest,
        width,
        [char | current_part],
        parts,
        new_width
      )
    else
      # Complete current part
      completed_part =
        if current_part != [],
          do: Enum.join(Enum.reverse(current_part), ""),
          else: ""

      new_parts =
        if completed_part != "", do: [completed_part | parts], else: parts

      break_graphemes_by_visual_width([char | rest], width, [], new_parts, 0)
    end
  end

  defp wrap_by_word_impl(text, width) do
    # Simple word wrapping implementation
    words = String.split(text, " ")
    wrap_words(words, width, [], [])
  end

  defp wrap_words([], _width, current_line, lines) do
    final_lines =
      if current_line != [],
        do: [Enum.join(Enum.reverse(current_line), " ") | lines],
        else: lines

    Enum.reverse(final_lines)
  end

  defp wrap_words([word | rest], width, current_line, lines) do
    current_text = Enum.join(Enum.reverse(current_line), " ")

    new_text =
      if current_line == [], do: word, else: current_text <> " " <> word

    if String.length(new_text) <= width do
      wrap_words(rest, width, [word | current_line], lines)
    else
      # Start new line with the word
      completed_line =
        if current_line != [],
          do: Enum.join(Enum.reverse(current_line), " "),
          else: ""

      new_lines =
        if completed_line != "", do: [completed_line | lines], else: lines

      # Handle very long words that exceed width
      if String.length(word) > width do
        # Break long word into chunks
        word_chunks = break_long_word(word, width)

        wrap_words(
          rest,
          width,
          [List.last(word_chunks)],
          new_lines ++ Enum.reverse(Enum.drop(word_chunks, -1))
        )
      else
        wrap_words(rest, width, [word], new_lines)
      end
    end
  end

  defp break_long_word(word, width) do
    graphemes = String.graphemes(word)
    chunk_graphemes(graphemes, width, [], [])
  end

  defp chunk_graphemes([], _width, current_chunk, chunks) do
    final_chunks =
      if current_chunk != [],
        do: [Enum.join(Enum.reverse(current_chunk), "") | chunks],
        else: chunks

    Enum.reverse(final_chunks)
  end

  defp chunk_graphemes([char | rest], width, current_chunk, chunks) do
    if length(current_chunk) >= width do
      completed_chunk = Enum.join(Enum.reverse(current_chunk), "")
      chunk_graphemes([char | rest], width, [], [completed_chunk | chunks])
    else
      chunk_graphemes(rest, width, [char | current_chunk], chunks)
    end
  end

  defp calculate_visual_width(text) do
    # Simple implementation: count graphemes, with wider characters counting as 2
    graphemes = String.graphemes(text)

    Enum.reduce(graphemes, 0, fn char, acc ->
      # CJK characters and some symbols take 2 columns
      codepoint = String.to_charlist(char) |> List.first()

      cond do
        # CJK Unified Ideographs
        codepoint >= 0x4E00 and codepoint <= 0x9FFF -> acc + 2
        # CJK Symbols and Punctuation
        codepoint >= 0x3000 and codepoint <= 0x303F -> acc + 2
        # Hiragana
        codepoint >= 0x3040 and codepoint <= 0x309F -> acc + 2
        # Katakana
        codepoint >= 0x30A0 and codepoint <= 0x30FF -> acc + 2
        # Fullwidth Forms
        codepoint >= 0xFF00 and codepoint <= 0xFFEF -> acc + 2
        # Most other characters take 1 column
        true -> acc + 1
      end
    end)
  end

  defp estimate_char_width_from_pixels(pixel_width, font_manager) do
    # Rough estimation: assume monospace font with ~8 pixels per character
    char_pixel_width =
      case font_manager do
        %{size: size} when is_number(size) -> max(size * 0.6, 6)
        _ -> 8
      end

    max(div(pixel_width, trunc(char_pixel_width)), 1)
  end
end
