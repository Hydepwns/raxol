defmodule Raxol.Effects.HoverHighlight do
  @moduledoc """
  Visual hover feedback for terminal widgets.

  Highlights the widget region under the mouse cursor with a border
  glow, fill tint, or underline. Integrates with the MCP FocusLens to
  provide visual feedback when mouse tracking is active.

  ## Example

      highlight = HoverHighlight.new()
      highlight = HoverHighlight.set_target(highlight, %{x: 5, y: 2, width: 20, height: 3})
      buffer = HoverHighlight.apply(highlight, buffer)

  ## Configuration

      config = %{
        color: :cyan,
        style: :border,      # :border | :fill | :underline
        intensity: 0.6,       # 0.0-1.0 peak intensity
        fade_ms: 200,         # ms to fade after mouse leaves
        enabled: true
      }
  """

  alias Raxol.Core.Buffer

  @type position :: {integer(), integer()}

  @type bounds :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: non_neg_integer(),
          height: non_neg_integer()
        }

  @type config :: %{
          optional(:color) => atom(),
          optional(:style) => :border | :fill | :underline,
          optional(:intensity) => float(),
          optional(:fade_ms) => non_neg_integer(),
          optional(:enabled) => boolean()
        }

  @type t :: %__MODULE__{
          target: bounds() | nil,
          widget_id: String.t() | nil,
          active: boolean(),
          fade_start: integer() | nil,
          config: config()
        }

  defstruct target: nil,
            widget_id: nil,
            active: false,
            fade_start: nil,
            config: %{}

  @default_config %{
    color: :cyan,
    style: :border,
    intensity: 0.6,
    fade_ms: 200,
    enabled: true
  }

  @doc "Create a new hover highlight effect."
  @spec new(config()) :: t()
  def new(config \\ %{}) do
    %__MODULE__{config: Map.merge(@default_config, config)}
  end

  @doc """
  Set the target widget bounds. Pass `nil` to start fade-out.
  """
  @spec set_target(t(), bounds() | nil, String.t() | nil) :: t()
  def set_target(%{config: %{enabled: false}} = highlight, _bounds, _widget_id),
    do: highlight

  def set_target(%{active: false} = highlight, nil, _widget_id), do: highlight

  def set_target(%{active: true} = highlight, nil, _widget_id) do
    %{
      highlight
      | active: false,
        fade_start: System.monotonic_time(:millisecond)
    }
  end

  def set_target(highlight, bounds, widget_id) do
    %{
      highlight
      | target: bounds,
        widget_id: widget_id,
        active: true,
        fade_start: nil
    }
  end

  @doc "Apply the hover highlight to a buffer."
  @spec apply(t(), Buffer.t()) :: Buffer.t()
  def apply(%{config: %{enabled: false}}, buffer), do: buffer
  def apply(%{target: nil}, buffer), do: buffer
  def apply(%{active: false, fade_start: nil}, buffer), do: buffer

  def apply(
        %{active: false, fade_start: start, config: config} = highlight,
        buffer
      ) do
    elapsed = System.monotonic_time(:millisecond) - start
    fade_ms = config.fade_ms

    if elapsed >= fade_ms do
      buffer
    else
      fade_factor = 1.0 - elapsed / fade_ms
      do_apply(highlight, buffer, config.intensity * fade_factor)
    end
  end

  def apply(highlight, buffer) do
    do_apply(highlight, buffer, highlight.config.intensity)
  end

  @doc "Enable or disable the effect."
  @spec set_enabled(t(), boolean()) :: t()
  def set_enabled(highlight, enabled),
    do: put_in(highlight.config.enabled, enabled)

  @doc "Update configuration."
  @spec update_config(t(), config()) :: t()
  def update_config(%{config: current} = highlight, new_config) do
    %{highlight | config: Map.merge(current, new_config)}
  end

  @doc "Clear the highlight immediately (no fade)."
  @spec clear(t()) :: t()
  def clear(highlight) do
    %{highlight | target: nil, widget_id: nil, active: false, fade_start: nil}
  end

  @doc "Whether anything would render right now."
  @spec visible?(t()) :: boolean()
  def visible?(%{config: %{enabled: false}}), do: false
  def visible?(%{target: nil}), do: false
  def visible?(%{active: true}), do: true
  def visible?(%{active: false, fade_start: nil}), do: false

  def visible?(%{active: false, fade_start: start, config: config}) do
    System.monotonic_time(:millisecond) - start < config.fade_ms
  end

  # -- Private --

  defp do_apply(_highlight, buffer, intensity) when intensity <= 0.01,
    do: buffer

  defp do_apply(%{target: bounds, config: config}, buffer, intensity) do
    paint = paint_fn(intensity, config.color)

    case config.style do
      :fill -> apply_fill(buffer, bounds, paint)
      :underline -> apply_underline(buffer, bounds, paint)
      _ -> apply_border(buffer, bounds, paint)
    end
  end

  # Returns a `(buffer, x, y) -> buffer` painter that bakes the current
  # intensity into a style. Cells brighter than 0.6 get the bg color and
  # `:bold`; mid-fade gets bg only; near-fade-out drops to fg-only with
  # `:dim` so the box visibly fades away rather than popping off.
  defp paint_fn(intensity, color) do
    style = intensity_style(intensity, color)
    fn buffer, x, y -> paint_cell(buffer, x, y, style) end
  end

  defp intensity_style(intensity, color) when intensity >= 0.6 do
    %{bg_color: color, fg_color: nil, attrs: [:bold]}
  end

  defp intensity_style(intensity, color) when intensity >= 0.3 do
    %{bg_color: color, fg_color: nil, attrs: []}
  end

  defp intensity_style(_intensity, color) do
    # Near fade-out: drop the bg entirely and tint fg dim instead so the
    # background flicker doesn't dominate the visual fade.
    %{bg_color: nil, fg_color: color, attrs: [:dim]}
  end

  defp apply_border(buffer, %{x: x, y: y, width: w, height: h}, paint) do
    buffer
    |> apply_horizontal_line(x, y, w, paint)
    |> apply_horizontal_line(x, y + h - 1, w, paint)
    |> apply_vertical_line(x, y, h, paint)
    |> apply_vertical_line(x + w - 1, y, h, paint)
  end

  defp apply_fill(buffer, %{x: x, y: y, width: w, height: h}, paint) do
    Enum.reduce(y..(y + h - 1)//1, buffer, fn row, buf ->
      apply_horizontal_line(buf, x, row, w, paint)
    end)
  end

  defp apply_underline(buffer, %{x: x, y: y, width: w, height: h}, paint) do
    apply_horizontal_line(buffer, x, y + h - 1, w, paint)
  end

  defp apply_horizontal_line(buffer, x, y, width, paint) do
    Enum.reduce(x..(x + width - 1)//1, buffer, fn col, buf ->
      paint.(buf, col, y)
    end)
  end

  defp apply_vertical_line(buffer, x, y, height, paint) do
    Enum.reduce(y..(y + height - 1)//1, buffer, fn row, buf ->
      paint.(buf, x, row)
    end)
  end

  defp paint_cell(buffer, x, y, style) do
    cell = Buffer.get_cell(buffer, x, y)
    char = Map.get(cell, :char, " ")
    base_style = Map.get(cell, :style, %{})
    Buffer.set_cell(buffer, x, y, char, Map.merge(base_style, style))
  end
end
