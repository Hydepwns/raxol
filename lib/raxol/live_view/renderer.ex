defmodule Raxol.LiveView.Renderer do
  @moduledoc """
  Core buffer-to-HTML rendering engine for Raxol web terminals.

  This module handles the conversion of terminal buffers (grid of cells)
  into optimized HTML suitable for web rendering with character-perfect
  monospace grid alignment.

  ## Features

  - Virtual DOM-style diffing to minimize DOM updates
  - Smart caching for common characters and styles
  - Efficient iodata-based string building
  - Dirty checking to skip unnecessary renders
  - Graceful error handling with fallback rendering

  ## Usage

      buffer = %{
        lines: [%{cells: [%{char: "H", style: %{bold: true}}]}],
        width: 80,
        height: 24
      }

      renderer = Raxol.LiveView.Renderer.new()
      {html, new_renderer} = Raxol.LiveView.Renderer.render(renderer, buffer)
  """

  alias Raxol.Core.Runtime.Log

  defstruct [
    :html_char_cache,
    :style_class_cache,
    :previous_buffer,
    :previous_html,
    :render_count,
    :cache_hits,
    :cache_misses
  ]

  @type cell :: %{char: String.t(), style: map()}
  @type line :: %{cells: [cell()]}
  @type buffer :: %{lines: [line()], width: integer(), height: integer()}
  @type t :: %__MODULE__{}

  @doc """
  Creates a new renderer with empty caches.
  """
  def new do
    %__MODULE__{
      html_char_cache: build_char_cache(),
      style_class_cache: %{},
      previous_buffer: nil,
      previous_html: nil,
      render_count: 0,
      cache_hits: 0,
      cache_misses: 0
    }
  end

  @doc """
  Renders a buffer to HTML, using diffing and caching for performance.

  Returns `{html_string, updated_renderer}`. On error, returns a fallback
  empty terminal HTML and logs the error.

  ## Examples

      renderer = Renderer.new()
      {html, new_renderer} = Renderer.render(renderer, buffer)

      # With invalid buffer - returns empty terminal, logs error
      {html, renderer} = Renderer.render(renderer, nil)
  """
  def render(renderer, nil) do
    Log.error("Renderer received nil buffer, returning empty terminal",
      module: __MODULE__,
      function: :render
    )

    :telemetry.execute(
      [:raxol, :liveview, :render, :error],
      %{count: 1},
      %{reason: :nil_buffer}
    )

    empty_html = ~s(<div class="raxol-terminal" data-grid="true"></div>)
    {empty_html, renderer}
  end

  def render(%__MODULE__{previous_buffer: nil} = renderer, buffer) do
    # First render - generate full HTML
    start_time = System.monotonic_time()

    case validate_buffer(buffer) do
      :ok ->
        {html, updated_renderer} = render_full_buffer(buffer, renderer)

        duration = System.monotonic_time() - start_time

        buffer_size =
          case Map.get(buffer, :lines) do
            lines when is_list(lines) -> length(lines)
            _ -> 0
          end

        :telemetry.execute(
          [:raxol, :liveview, :render, :full],
          %{duration: duration, buffer_size: buffer_size},
          %{
            width: Map.get(buffer, :width, 0),
            height: Map.get(buffer, :height, 0)
          }
        )

        new_renderer = %{
          updated_renderer
          | previous_buffer: buffer,
            previous_html: html,
            render_count: updated_renderer.render_count + 1
        }

        {html, new_renderer}

      {:error, reason} ->
        Log.warning("Buffer validation failed: #{inspect(reason)}",
          module: __MODULE__,
          function: :render
        )

        :telemetry.execute(
          [:raxol, :liveview, :render, :error],
          %{count: 1},
          %{reason: :validation_failed}
        )

        render_fallback(renderer)
    end
  end

  def render(
        %__MODULE__{previous_buffer: prev_buffer, previous_html: cached_html} =
          renderer,
        buffer
      )
      when prev_buffer == buffer do
    # No changes - return cached HTML
    :telemetry.execute(
      [:raxol, :liveview, :render, :cached],
      %{count: 1},
      %{cache_hit: true}
    )

    {cached_html, renderer}
  end

  def render(%__MODULE__{previous_buffer: prev_buffer} = renderer, buffer) do
    # Changes detected - use smart diffing
    start_time = System.monotonic_time()

    case validate_buffer(buffer) do
      :ok ->
        {html, updated_renderer} =
          render_with_smart_diff(buffer, prev_buffer, renderer)

        duration = System.monotonic_time() - start_time

        buffer_size =
          case Map.get(buffer, :lines) do
            lines when is_list(lines) -> length(lines)
            _ -> 0
          end

        :telemetry.execute(
          [:raxol, :liveview, :render, :diff],
          %{duration: duration, buffer_size: buffer_size},
          %{
            width: Map.get(buffer, :width, 0),
            height: Map.get(buffer, :height, 0),
            cache_hit_ratio:
              calculate_hit_ratio(
                updated_renderer.cache_hits,
                updated_renderer.cache_misses
              )
          }
        )

        final_renderer = %{
          updated_renderer
          | previous_buffer: buffer,
            previous_html: html,
            render_count: updated_renderer.render_count + 1
        }

        {html, final_renderer}

      {:error, reason} ->
        Log.warning(
          "Buffer validation failed during re-render: #{inspect(reason)}",
          module: __MODULE__,
          function: :render
        )

        :telemetry.execute(
          [:raxol, :liveview, :render, :error],
          %{count: 1},
          %{reason: :validation_failed}
        )

        # Return previous HTML on validation error
        {renderer.previous_html || render_empty_terminal(), renderer}
    end
  end

  @doc """
  Validates a buffer structure.

  Returns `:ok` if valid, or `{:error, reason}` if invalid.
  """
  def validate_buffer(%{lines: lines}) when is_list(lines) do
    cond do
      Enum.empty?(lines) ->
        :ok

      not Enum.all?(lines, &valid_line?/1) ->
        {:error, :invalid_line_structure}

      true ->
        :ok
    end
  end

  def validate_buffer(_), do: {:error, :invalid_buffer_structure}

  defp valid_line?(%{cells: cells}) when is_list(cells) do
    Enum.all?(cells, &valid_cell?/1)
  end

  defp valid_line?(_), do: false

  defp valid_cell?(%{char: char, style: style})
       when is_binary(char) and is_map(style),
       do: true

  defp valid_cell?(_), do: false

  defp render_fallback(renderer) do
    html = render_empty_terminal()
    {html, renderer}
  end

  defp render_empty_terminal do
    ~s(<div class="raxol-terminal raxol-error" data-grid="true"><div class="raxol-line"><span class="raxol-cell">Terminal render error</span></div></div>)
  end

  # Private Implementation

  defp render_full_buffer(buffer, renderer) do
    # Render all lines and collect cache stats
    {lines_html, total_hits, total_misses} =
      buffer
      |> get_buffer_lines()
      |> Enum.with_index()
      |> Enum.reduce({[], 0, 0}, fn {line, line_idx},
                                    {html_acc, hits_acc, misses_acc} ->
        {line_html, hits, misses} =
          line_to_html_optimized(line, line_idx, renderer)

        {[line_html | html_acc], hits_acc + hits, misses_acc + misses}
      end)

    html = wrap_in_grid_container(Enum.reverse(lines_html))

    # Update renderer with cache stats
    updated_renderer = %{
      renderer
      | cache_hits: renderer.cache_hits + total_hits,
        cache_misses: renderer.cache_misses + total_misses
    }

    {html, updated_renderer}
  end

  @doc """
  Invalidates all caches, forcing a full re-render on next call.
  """
  def invalidate_cache(renderer) do
    %{
      renderer
      | html_char_cache: build_char_cache(),
        style_class_cache: %{},
        previous_buffer: nil,
        previous_html: nil
    }
  end

  @doc """
  Returns statistics about cache performance.
  """
  def stats(renderer) do
    hit_ratio = calculate_hit_ratio(renderer.cache_hits, renderer.cache_misses)

    %{
      render_count: renderer.render_count,
      cache_hits: renderer.cache_hits,
      cache_misses: renderer.cache_misses,
      hit_ratio: hit_ratio
    }
  end

  defp calculate_hit_ratio(0, 0), do: 0.0
  defp calculate_hit_ratio(hits, misses), do: hits / (hits + misses)

  # Private Implementation

  defp render_with_smart_diff(buffer, prev_buffer, renderer) do
    current_lines = get_buffer_lines(buffer)
    prev_lines = get_buffer_lines(prev_buffer)
    changed_lines = find_changed_lines(current_lines, prev_lines)

    render_based_on_changes(buffer, current_lines, changed_lines, renderer)
  end

  defp render_based_on_changes(buffer, current_lines, changed_lines, renderer)
       when length(changed_lines) > 0 and
              length(changed_lines) > div(length(current_lines), 3) do
    # More than 1/3 of lines changed - full render is faster
    render_full_buffer(buffer, renderer)
  end

  defp render_based_on_changes(_buffer, current_lines, changed_lines, renderer) do
    # Render only changed lines and patch
    patch_html_with_changes(current_lines, changed_lines, renderer)
  end

  defp find_changed_lines(current_lines, prev_lines) do
    current_lines
    |> Enum.with_index()
    |> Enum.filter(fn {line, idx} ->
      prev_line = Enum.at(prev_lines, idx)
      not lines_identical?(line, prev_line)
    end)
  end

  defp patch_html_with_changes(current_lines, _changed_lines, renderer) do
    # Always do full render (patch-based rendering would need client-side JS support)
    {lines_html, total_hits, total_misses} =
      current_lines
      |> Enum.with_index()
      |> Enum.reduce({[], 0, 0}, fn {line, line_idx},
                                    {html_acc, hits_acc, misses_acc} ->
        {line_html, hits, misses} =
          line_to_html_optimized(line, line_idx, renderer)

        {[line_html | html_acc], hits_acc + hits, misses_acc + misses}
      end)

    html = wrap_in_grid_container(Enum.reverse(lines_html))

    # Update renderer with cache stats
    updated_renderer = %{
      renderer
      | cache_hits: renderer.cache_hits + total_hits,
        cache_misses: renderer.cache_misses + total_misses
    }

    {html, updated_renderer}
  end

  # Optimized line rendering using caches
  defp line_to_html_optimized(line, _line_idx, renderer) do
    cells = line.cells

    # Use IO.iodata for efficient string building and track cache stats
    {cell_html, hits, misses} =
      Enum.reduce(cells, {[], 0, 0}, fn cell,
                                        {html_acc, hits_acc, misses_acc} ->
        {cell_html, hit?} = cell_to_html_cached(cell, renderer)

        if hit? do
          {[cell_html | html_acc], hits_acc + 1, misses_acc}
        else
          {[cell_html | html_acc], hits_acc, misses_acc + 1}
        end
      end)

    # Build line HTML efficiently
    line_html = [
      ~s(<div class="raxol-line">),
      Enum.reverse(cell_html),
      ~s(</div>)
    ]

    {line_html, hits, misses}
  end

  defp cell_to_html_cached(cell, renderer) do
    cache_key = {cell.char, cell.style}

    Map.fetch(renderer.html_char_cache, cache_key)
    |> handle_cache_result(cell)
  end

  defp handle_cache_result({:ok, cached_html}, _cell), do: {cached_html, true}
  defp handle_cache_result(:error, cell), do: {generate_cell_html(cell), false}

  defp generate_cell_html(%{char: char, style: style}) do
    classes = get_cached_style_classes(style)
    escaped_char = get_cached_escaped_char(char)

    # Use iolist for efficiency
    [~s(<span class="raxol-cell ), classes, ~s(">), escaped_char, ~s(</span>)]
  end

  defp get_cached_style_classes(style) do
    # Cache style combinations to avoid repeated string building
    case style do
      %{bold: false, reverse: false, fg_color: nil, bg_color: nil} ->
        # Most common case - no styling
        ""

      %{bold: true, reverse: false, fg_color: nil, bg_color: nil} ->
        "raxol-bold"

      %{bold: false, reverse: true, fg_color: nil, bg_color: nil} ->
        "raxol-reverse"

      %{bold: true, reverse: true, fg_color: nil, bg_color: nil} ->
        "raxol-bold raxol-reverse"

      _ ->
        # For complex styles, fall back to dynamic generation
        style_to_css_classes(style)
    end
  end

  defp get_cached_escaped_char(char) do
    # Use pre-computed escape cache
    case char do
      " " -> "&nbsp;"
      "&" -> "&amp;"
      "<" -> "&lt;"
      ">" -> "&gt;"
      "\"" -> "&quot;"
      "'" -> "&#39;"
      _ -> char
    end
  end

  # Pre-build cache of common HTML characters
  defp build_char_cache do
    common_chars = [
      " ",
      "a",
      "e",
      "i",
      "o",
      "u",
      "n",
      "r",
      "t",
      "s",
      "l",
      "0",
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
      "-",
      "_",
      "=",
      "+",
      "|",
      "\\",
      "/",
      ".",
      ",",
      ":",
      "┌",
      "┐",
      "└",
      "┘",
      "─",
      "│",
      "█",
      "▓",
      "▒",
      "░"
    ]

    default_style = %{
      bold: false,
      italic: false,
      underline: false,
      reverse: false,
      fg_color: nil,
      bg_color: nil
    }

    # Pre-generate HTML for common char/style combinations
    for char <- common_chars, into: %{} do
      cache_key = {char, default_style}
      cell = %{char: char, style: default_style}
      html = generate_cell_html(cell) |> IO.iodata_to_binary()
      {cache_key, html}
    end
  end

  # Utility functions
  defp lines_identical?(line1, line2) do
    # Compare line cells efficiently, handling nil cases
    case {line1, line2} do
      {nil, nil} -> true
      {nil, _} -> false
      {_, nil} -> false
      {l1, l2} -> l1.cells == l2.cells
    end
  end

  defp get_buffer_lines(buffer) do
    case buffer do
      lines when is_list(lines) -> lines
      %{lines: lines} -> lines
      _ -> []
    end
  end

  defp style_to_css_classes(style) do
    []
    |> add_class_if(Map.get(style, :bold, false), "raxol-bold")
    |> add_class_if(Map.get(style, :italic, false), "raxol-italic")
    |> add_class_if(Map.get(style, :underline, false), "raxol-underline")
    |> add_class_if(Map.get(style, :reverse, false), "raxol-reverse")
    |> add_color_class(
      Map.get(style, :fg_color) || Map.get(style, :color),
      "raxol-fg"
    )
    |> add_color_class(
      Map.get(style, :bg_color) || Map.get(style, :background),
      "raxol-bg"
    )
    |> Enum.join(" ")
  end

  defp add_class_if(classes, true, class_name), do: [class_name | classes]
  defp add_class_if(classes, false, _class_name), do: classes

  defp add_color_class(classes, nil, _prefix), do: classes

  defp add_color_class(classes, color, prefix),
    do: ["#{prefix}-#{color_name(color)}" | classes]

  defp color_name(color) when is_atom(color) do
    color |> Atom.to_string() |> String.replace("_", "-")
  end

  defp color_name(color) when is_tuple(color) do
    case color do
      {:rgb, r, g, b} -> "rgb-#{r}-#{g}-#{b}"
      _ -> "default"
    end
  end

  defp color_name(_), do: "default"

  defp wrap_in_grid_container(lines) do
    # Use iolist for efficiency
    [
      ~s(<div class="raxol-terminal" data-grid="true">),
      "\n",
      lines |> Enum.intersperse("\n"),
      "\n",
      ~s(</div>)
    ]
    |> IO.iodata_to_binary()
  end
end
