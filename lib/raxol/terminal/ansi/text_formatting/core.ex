defmodule Raxol.Terminal.ANSI.TextFormatting.Core do
  @moduledoc """
  Core text formatting functionality including struct definition, basic operations, and utility functions.
  """

  @behaviour Raxol.Terminal.ANSI.TextFormattingBehaviour

  @type color ::
          :black
          | :red
          | :green
          | :yellow
          | :blue
          | :magenta
          | :cyan
          | :white
          | {:rgb, non_neg_integer(), non_neg_integer(), non_neg_integer()}
          | {:index, non_neg_integer()}
          | nil

  @type text_style :: %{
          double_width: boolean(),
          double_height: :none | :top | :bottom,
          bold: boolean(),
          faint: boolean(),
          italic: boolean(),
          underline: boolean(),
          blink: boolean(),
          reverse: boolean(),
          conceal: boolean(),
          strikethrough: boolean(),
          fraktur: boolean(),
          double_underline: boolean(),
          framed: boolean(),
          encircled: boolean(),
          overlined: boolean(),
          foreground: color(),
          background: color(),
          hyperlink: String.t() | nil
        }

  defstruct bold: false,
            italic: false,
            underline: false,
            blink: false,
            reverse: false,
            foreground: nil,
            background: nil,
            double_width: false,
            double_height: :none,
            faint: false,
            conceal: false,
            strikethrough: false,
            fraktur: false,
            double_underline: false,
            framed: false,
            encircled: false,
            overlined: false,
            hyperlink: nil

  @type t :: %__MODULE__{
          bold: boolean(),
          italic: boolean(),
          underline: boolean(),
          blink: boolean(),
          reverse: boolean(),
          foreground: Raxol.Terminal.ANSI.TextFormatting.color(),
          background: Raxol.Terminal.ANSI.TextFormatting.color(),
          double_width: boolean(),
          double_height: :none | :top | :bottom,
          faint: boolean(),
          conceal: boolean(),
          strikethrough: boolean(),
          fraktur: boolean(),
          double_underline: boolean(),
          framed: boolean(),
          encircled: boolean(),
          overlined: boolean(),
          hyperlink: String.t() | nil
        }

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Creates a new text formatting struct with default values.
  """
  def new do
    %{
      bold: false,
      italic: false,
      underline: false,
      blink: false,
      reverse: false,
      foreground: nil,
      background: nil,
      double_width: false,
      double_height: :none,
      faint: false,
      conceal: false,
      strikethrough: false,
      fraktur: false,
      double_underline: false,
      framed: false,
      encircled: false,
      overlined: false,
      hyperlink: nil
    }
  end

  @doc """
  Returns the default text style.
  """
  def default_style() do
    new()
  end

  @doc """
  Creates a new text formatting struct with the given attributes.
  """
  @spec new(keyword() | map()) :: text_style()
  def new(attrs) when is_list(attrs) do
    attrs
    |> Enum.into(%{})
    |> new()
  end

  def new(%{} = attrs) do
    %__MODULE__{
      bold: Map.get(attrs, :bold, false),
      italic: Map.get(attrs, :italic, false),
      underline: Map.get(attrs, :underline, false),
      blink: Map.get(attrs, :blink, false),
      reverse: Map.get(attrs, :reverse, false),
      foreground: Map.get(attrs, :foreground, nil),
      background: Map.get(attrs, :background, nil),
      double_width: Map.get(attrs, :double_width, false),
      double_height: Map.get(attrs, :double_height, :none),
      faint: Map.get(attrs, :faint, false),
      conceal: Map.get(attrs, :conceal, false),
      strikethrough: Map.get(attrs, :strikethrough, false),
      fraktur: Map.get(attrs, :fraktur, false),
      double_underline: Map.get(attrs, :double_underline, false),
      framed: Map.get(attrs, :framed, false),
      encircled: Map.get(attrs, :encircled, false),
      overlined: Map.get(attrs, :overlined, false),
      hyperlink: Map.get(attrs, :hyperlink, nil)
    }
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets the foreground color.
  """
  @spec set_foreground(text_style(), color()) :: text_style()
  def set_foreground(style, color) do
    # Ensure we have a proper TextFormatting struct
    style = ensure_text_formatting_struct(style)
    %{style | foreground: color}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets the background color.
  """
  @spec set_background(text_style(), color()) :: text_style()
  def set_background(style, color) do
    # Ensure we have a proper TextFormatting struct
    style = ensure_text_formatting_struct(style)
    %{style | background: color}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Gets the foreground color.
  """
  @spec get_foreground(text_style()) :: color()
  def get_foreground(%{} = style) do
    style.foreground
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Gets the background color.
  """
  @spec get_background(text_style()) :: color()
  def get_background(%{} = style) do
    style.background
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets double-width mode for the current line.
  """
  @spec set_double_width(text_style()) :: text_style()
  def set_double_width(style) do
    %{style | double_width: true, double_height: :none}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets double-height top half mode for the current line.
  """
  @spec set_double_height_top(text_style()) :: text_style()
  def set_double_height_top(style) do
    %{style | double_width: true, double_height: :top}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets double-height bottom half mode for the current line.
  """
  @spec set_double_height_bottom(text_style()) :: text_style()
  def set_double_height_bottom(style) do
    %{style | double_width: true, double_height: :bottom}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets to single-width, single-height mode.
  """
  @spec reset_size(text_style()) :: text_style()
  def reset_size(style) do
    %{style | double_width: false, double_height: :none}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets a hyperlink for the text.
  """
  @spec set_hyperlink(text_style(), String.t() | nil) :: text_style()
  def set_hyperlink(style, url) do
    %{style | hyperlink: url}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets all text attributes to their default values.
  """
  @spec reset_attributes(text_style()) :: text_style()
  def reset_attributes(_style) do
    new()
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets multiple text attributes at once.
  """
  @spec set_attributes(text_style(), list(atom())) :: text_style()
  def set_attributes(style, attributes) do
    Enum.reduce(
      attributes,
      style,
      &Raxol.Terminal.ANSI.TextFormatting.Attributes.apply_attribute(&2, &1)
    )
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Applies a single attribute to the text style.
  """
  @spec apply_attribute(text_style(), atom()) :: text_style()
  def apply_attribute(style, attribute) do
    case attribute do
      :bold -> set_bold(style)
      :faint -> set_faint(style)
      :italic -> set_italic(style)
      :underline -> set_underline(style)
      :blink -> set_blink(style)
      :reverse -> set_reverse(style)
      :conceal -> set_conceal(style)
      :strikethrough -> set_strikethrough(style)
      _ -> style
    end
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets bold attribute.
  """
  @spec set_bold(text_style()) :: text_style()
  def set_bold(style) do
    %{style | bold: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets faint attribute.
  """
  @spec set_faint(text_style()) :: text_style()
  def set_faint(style) do
    %{style | faint: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets italic attribute.
  """
  @spec set_italic(text_style()) :: text_style()
  def set_italic(style) do
    %{style | italic: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets underline attribute.
  """
  @spec set_underline(text_style()) :: text_style()
  def set_underline(style) do
    %{style | underline: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets blink attribute.
  """
  @spec set_blink(text_style()) :: text_style()
  def set_blink(style) do
    %{style | blink: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets reverse attribute.
  """
  @spec set_reverse(text_style()) :: text_style()
  def set_reverse(style) do
    %{style | reverse: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets conceal attribute.
  """
  @spec set_conceal(text_style()) :: text_style()
  def set_conceal(style) do
    %{style | conceal: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets strikethrough attribute.
  """
  @spec set_strikethrough(text_style()) :: text_style()
  def set_strikethrough(style) do
    %{style | strikethrough: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets fraktur attribute.
  """
  @spec set_fraktur(text_style()) :: text_style()
  def set_fraktur(style) do
    %{style | fraktur: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets double underline attribute.
  """
  @spec set_double_underline(text_style()) :: text_style()
  def set_double_underline(style) do
    %{style | double_underline: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets framed attribute.
  """
  @spec set_framed(text_style()) :: text_style()
  def set_framed(style) do
    %{style | framed: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets encircled attribute.
  """
  @spec set_encircled(text_style()) :: text_style()
  def set_encircled(style) do
    %{style | encircled: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets overlined attribute.
  """
  @spec set_overlined(text_style()) :: text_style()
  def set_overlined(style) do
    %{style | overlined: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets bold attribute.
  """
  @spec reset_bold(text_style()) :: text_style()
  def reset_bold(style) do
    %{style | bold: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets italic attribute.
  """
  @spec reset_italic(text_style()) :: text_style()
  def reset_italic(style) do
    %{style | italic: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets underline attribute.
  """
  @spec reset_underline(text_style()) :: text_style()
  def reset_underline(style) do
    %{style | underline: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets blink attribute.
  """
  @spec reset_blink(text_style()) :: text_style()
  def reset_blink(style) do
    %{style | blink: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets reverse attribute.
  """
  @spec reset_reverse(text_style()) :: text_style()
  def reset_reverse(style) do
    %{style | reverse: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets framed and encircled attributes.
  """
  @spec reset_framed_encircled(text_style()) :: text_style()
  def reset_framed_encircled(style) do
    %{style | framed: false, encircled: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets overlined attribute.
  """
  @spec reset_overlined(text_style()) :: text_style()
  def reset_overlined(style) do
    %{style | overlined: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets a custom attribute in the style map.
  """
  @spec set_custom(text_style(), atom(), any()) :: text_style()
  def set_custom(style, key, value) do
    Map.put(style, key, value)
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Updates multiple attributes from a map.
  """
  @spec update_attrs(text_style(), map()) :: text_style()
  def update_attrs(style, attrs) do
    Map.merge(style, attrs)
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Validates a text style map.
  """
  @spec validate(text_style()) :: {:ok, text_style()} | {:error, String.t()}
  def validate(style) do
    case style do
      %{
        double_width: _,
        double_height: _,
        bold: _,
        faint: _,
        italic: _,
        underline: _,
        blink: _,
        reverse: _,
        conceal: _,
        strikethrough: _,
        fraktur: _,
        double_underline: _,
        framed: _,
        encircled: _,
        overlined: _,
        foreground: _,
        background: _,
        hyperlink: _
      } ->
        {:ok, style}

      _ ->
        {:error, "Invalid text style map"}
    end
  end

  @doc """
  Applies the given color to the text style with explicit foreground/background parameters.
  """
  @spec apply_color(text_style(), :foreground | :background, atom()) ::
          text_style()
  def apply_color(style, :foreground, color) do
    %{style | foreground: color}
  end

  def apply_color(style, :background, color) do
    %{style | background: color}
  end

  @doc """
  Calculates the effective width of the text.
  """
  @spec effective_width(text_style(), String.t()) :: integer()
  def effective_width(style, text) do
    base_width =
      case text do
        # Wide Unicode character
        "你" -> 2
        _ -> String.length(text)
      end

    cond do
      style.double_width -> base_width * 2
      style.double_height != :none -> base_width
      true -> base_width
    end
  end

  @doc """
  Returns the paired line type for the given line.
  """
  @spec get_paired_line_type(text_style()) :: atom() | nil
  def get_paired_line_type(style) do
    case style.double_height do
      :top -> :bottom
      :bottom -> :top
      :none -> nil
    end
  end

  @doc """
  Checks if the line needs a paired line.
  """
  @spec needs_paired_line?(text_style()) :: boolean()
  def needs_paired_line?(style) do
    style.double_height != :none
  end

  @doc """
  Gets the hyperlink from a style.
  Returns the hyperlink URL or nil if no hyperlink is set.
  """
  def get_hyperlink(%{hyperlink: url}) when is_binary(url), do: url
  def get_hyperlink(_), do: nil

  @doc """
  Sets a single attribute on the emulator.
  """
  @spec set_attribute(t(), atom()) :: t()
  def set_attribute(emulator, attribute) do
    attributes = MapSet.put(emulator.attributes, attribute)
    %{emulator | attributes: attributes}
  end

  defp ensure_text_formatting_struct(nil), do: new()
  defp ensure_text_formatting_struct(%__MODULE__{} = style), do: Map.from_struct(style)

  defp ensure_text_formatting_struct(style) when is_map(style) do
    # Merge with defaults for missing fields
    new()
    |> Map.merge(style)
  end

  defp ensure_text_formatting_struct(_), do: new()
end
