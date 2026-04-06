defmodule Raxol.Effects.HoverHighlight do
  @moduledoc """
  Visual hover feedback for terminal widgets.

  Highlights the widget region under the mouse cursor with a subtle
  border glow. Integrates with the MCP FocusLens to provide visual
  feedback when mouse tracking is active.

  ## Example

      highlight = HoverHighlight.new()
      highlight = HoverHighlight.set_target(highlight, %{x: 5, y: 2, width: 20, height: 3})
      buffer = HoverHighlight.apply(highlight, buffer)

  ## Configuration

      config = %{
        color: :cyan,
        style: :border,      # :border | :fill | :underline
        intensity: 0.6,       # 0.0-1.0
        fade_ms: 200,         # ms to fade after mouse leaves
        enabled: true
      }

      highlight = HoverHighlight.new(config)
  """

  alias Raxol.Core.Buffer

  @type position :: {non_neg_integer(), non_neg_integer()}

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
  Set the target widget bounds to highlight.

  Pass `nil` to clear the highlight (starts fade-out).
  """
  @spec set_target(t(), bounds() | nil, String.t() | nil) :: t()
  def set_target(%{config: %{enabled: false}} = highlight, _bounds, _widget_id),
    do: highlight

  def set_target(highlight, nil, _widget_id) do
    if highlight.active do
      %{
        highlight
        | active: false,
          fade_start: System.monotonic_time(:millisecond)
      }
    else
      highlight
    end
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

  @doc """
  Apply the hover highlight to a buffer.

  Renders a border, fill, or underline on the target widget bounds.
  """
  @spec apply(t(), Buffer.t()) :: Buffer.t()
  def apply(%{config: %{enabled: false}}, buffer), do: buffer
  def apply(%{target: nil}, buffer), do: buffer

  def apply(%{active: false, fade_start: nil}, buffer), do: buffer

  def apply(%{active: false, fade_start: start} = highlight, buffer) do
    elapsed = System.monotonic_time(:millisecond) - start
    fade_ms = highlight.config.fade_ms

    if elapsed >= fade_ms do
      buffer
    else
      fade_factor = 1.0 - elapsed / fade_ms
      do_apply(highlight, buffer, highlight.config.intensity * fade_factor)
    end
  end

  def apply(highlight, buffer) do
    do_apply(highlight, buffer, highlight.config.intensity)
  end

  @doc "Enable or disable the effect."
  @spec set_enabled(t(), boolean()) :: t()
  def set_enabled(highlight, enabled) do
    put_in(highlight.config.enabled, enabled)
  end

  @doc "Update configuration."
  @spec update_config(t(), config()) :: t()
  def update_config(%{config: current} = highlight, new_config) do
    %{highlight | config: Map.merge(current, new_config)}
  end

  @doc "Clear the highlight immediately."
  @spec clear(t()) :: t()
  def clear(highlight) do
    %{highlight | target: nil, widget_id: nil, active: false, fade_start: nil}
  end

  @doc "Check if the highlight is currently visible."
  @spec visible?(t()) :: boolean()
  def visible?(%{config: %{enabled: false}}), do: false
  def visible?(%{target: nil}), do: false
  def visible?(%{active: true}), do: true

  def visible?(%{active: false, fade_start: nil}), do: false

  def visible?(%{active: false, fade_start: start, config: config}) do
    elapsed = System.monotonic_time(:millisecond) - start
    elapsed < config.fade_ms
  end

  # -- Private -----------------------------------------------------------------

  defp do_apply(%{target: bounds, config: config}, buffer, intensity)
       when intensity > 0.01 do
    color = config.color

    case config.style do
      :border -> apply_border(buffer, bounds, color, intensity)
      :fill -> apply_fill(buffer, bounds, color, intensity)
      :underline -> apply_underline(buffer, bounds, color, intensity)
      _ -> apply_border(buffer, bounds, color, intensity)
    end
  end

  defp do_apply(_, buffer, _intensity), do: buffer

  defp apply_border(
         buffer,
         %{x: x, y: y, width: w, height: h},
         color,
         _intensity
       ) do
    buffer
    |> apply_horizontal_line(x, y, w, color)
    |> apply_horizontal_line(x, y + h - 1, w, color)
    |> apply_vertical_line(x, y, h, color)
    |> apply_vertical_line(x + w - 1, y, h, color)
  end

  defp apply_fill(buffer, %{x: x, y: y, width: w, height: h}, color, _intensity) do
    Enum.reduce(y..(y + h - 1)//1, buffer, fn row, buf ->
      apply_horizontal_line(buf, x, row, w, color)
    end)
  end

  defp apply_underline(
         buffer,
         %{x: x, y: y, width: w, height: h},
         color,
         _intensity
       ) do
    apply_horizontal_line(buffer, x, y + h - 1, w, color)
  end

  defp apply_horizontal_line(buffer, x, y, width, color) do
    Enum.reduce(x..(x + width - 1)//1, buffer, fn col, buf ->
      apply_cell_highlight(buf, col, y, color)
    end)
  end

  defp apply_vertical_line(buffer, x, y, height, color) do
    Enum.reduce(y..(y + height - 1)//1, buffer, fn row, buf ->
      apply_cell_highlight(buf, x, row, color)
    end)
  end

  defp apply_cell_highlight(buffer, x, y, color) do
    cell = Buffer.get_cell(buffer, x, y)
    char = Map.get(cell, :char, " ")
    style = Map.get(cell, :style, %{})
    highlighted_style = Map.put(style, :bg_color, color)
    Buffer.set_cell(buffer, x, y, char, highlighted_style)
  end
end
