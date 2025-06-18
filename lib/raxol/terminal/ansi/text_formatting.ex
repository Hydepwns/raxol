defmodule Raxol.Terminal.ANSI.TextFormatting do
  @moduledoc '''
  Handles advanced text formatting features for the terminal emulator.
  This includes double-width and double-height characters, as well as
  other advanced text attributes and colors.
  '''

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
            background: nil

  @type t :: %__MODULE__{
          bold: boolean(),
          italic: boolean(),
          underline: boolean(),
          blink: boolean(),
          reverse: boolean(),
          foreground: Raxol.Terminal.ANSI.TextFormatting.color(),
          background: Raxol.Terminal.ANSI.TextFormatting.color()
        }

  @attribute_handlers %{
    reset: &Raxol.Terminal.ANSI.TextFormatting.new/0,
    double_width: &__MODULE__.set_double_width/1,
    double_height_top: &__MODULE__.set_double_height_top/1,
    double_height_bottom: &__MODULE__.set_double_height_bottom/1,
    bold: &__MODULE__.set_bold/1,
    faint: &__MODULE__.set_faint/1,
    italic: &__MODULE__.set_italic/1,
    underline: &__MODULE__.set_underline/1,
    blink: &__MODULE__.set_blink/1,
    reverse: &__MODULE__.set_reverse/1,
    conceal: &__MODULE__.set_conceal/1,
    strikethrough: &__MODULE__.set_strikethrough/1,
    fraktur: &__MODULE__.set_fraktur/1,
    double_underline: &__MODULE__.set_double_underline/1,
    framed: &__MODULE__.set_framed/1,
    encircled: &__MODULE__.set_encircled/1,
    overlined: &__MODULE__.set_overlined/1
  }

  @sgr_style_map %{
    bold: 1,
    italic: 3,
    underline: 4,
    blink: 5,
    reverse: 7,
    conceal: 8,
    strikethrough: 9
  }

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Creates a new text formatting struct with default values.
  '''
  def new do
    %__MODULE__{
      bold: false,
      italic: false,
      underline: false,
      blink: false,
      reverse: false,
      foreground: nil,
      background: nil
    }
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets the foreground color.
  '''
  @spec set_foreground(text_style(), color()) :: text_style()
  def set_foreground(style, color) do
    %{style | foreground: color}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets the background color.
  '''
  @spec set_background(text_style(), color()) :: text_style()
  def set_background(style, color) do
    %{style | background: color}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Gets the foreground color.
  '''
  @spec get_foreground(text_style()) :: color()
  def get_foreground(%{} = style) do
    style.foreground
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Gets the background color.
  '''
  @spec get_background(text_style()) :: color()
  def get_background(%{} = style) do
    style.background
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets double-width mode for the current line.
  '''
  @spec set_double_width(text_style()) :: text_style()
  def set_double_width(style) do
    %{style | double_width: true, double_height: :none}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets double-height top half mode for the current line.
  '''
  @spec set_double_height_top(text_style()) :: text_style()
  def set_double_height_top(style) do
    %{style | double_width: true, double_height: :top}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets double-height bottom half mode for the current line.
  '''
  @spec set_double_height_bottom(text_style()) :: text_style()
  def set_double_height_bottom(style) do
    %{style | double_width: true, double_height: :bottom}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Resets to single-width, single-height mode.
  '''
  @spec reset_size(text_style()) :: text_style()
  def reset_size(style) do
    %{style | double_width: false, double_height: :none}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Applies a text attribute to the style map.

  ## Parameters

  * `style` - The current text style
  * `attribute` - The attribute to apply (e.g., :bold, :underline, etc.)

  ## Returns

  The updated text style with the new attribute applied.
  '''
  @spec apply_attribute(text_style(), atom()) :: text_style()
  def apply_attribute(style, attribute) do
    case Map.get(@attribute_handlers, attribute) do
      nil -> style
      handler -> handler.(style)
    end
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets bold text mode.
  '''
  @spec set_bold(text_style()) :: text_style()
  def set_bold(style) do
    %{style | bold: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets faint text mode.
  '''
  @spec set_faint(text_style()) :: text_style()
  def set_faint(style) do
    %{style | faint: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets italic text mode.
  '''
  @spec set_italic(text_style()) :: text_style()
  def set_italic(style) do
    %{style | italic: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets underline text mode.
  '''
  @spec set_underline(text_style()) :: text_style()
  def set_underline(style) do
    %{style | underline: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets blink text mode.
  '''
  @spec set_blink(text_style()) :: text_style()
  def set_blink(style) do
    %{style | blink: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets reverse video mode.
  '''
  @spec set_reverse(text_style()) :: text_style()
  def set_reverse(style) do
    %{style | reverse: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets concealed text mode.
  '''
  @spec set_conceal(text_style()) :: text_style()
  def set_conceal(style) do
    %{style | conceal: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets strikethrough text mode.
  '''
  @spec set_strikethrough(text_style()) :: text_style()
  def set_strikethrough(style) do
    %{style | strikethrough: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets fraktur text mode.
  '''
  @spec set_fraktur(text_style()) :: text_style()
  def set_fraktur(style) do
    %{style | fraktur: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets double underline text mode.
  '''
  @spec set_double_underline(text_style()) :: text_style()
  def set_double_underline(style) do
    %{style | double_underline: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets framed text mode.
  '''
  @spec set_framed(text_style()) :: text_style()
  def set_framed(style) do
    %{style | framed: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets encircled text mode.
  '''
  @spec set_encircled(text_style()) :: text_style()
  def set_encircled(style) do
    %{style | encircled: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets overlined text mode.
  '''
  @spec set_overlined(text_style()) :: text_style()
  def set_overlined(style) do
    %{style | overlined: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets a hyperlink for the text.
  '''
  @spec set_hyperlink(text_style(), String.t() | nil) :: text_style()
  def set_hyperlink(style, url) do
    %{style | hyperlink: url}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Resets all text attributes to their default values.
  '''
  @spec reset_attributes(text_style()) :: text_style()
  def reset_attributes(_style) do
    new()
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets multiple text attributes at once.
  '''
  @spec set_attributes(text_style(), list(atom())) :: text_style()
  def set_attributes(style, attributes) do
    Enum.reduce(attributes, style, &apply_attribute(&2, &1))
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Sets a custom attribute in the style map.
  '''
  @spec set_custom(text_style(), atom(), any()) :: text_style()
  def set_custom(style, key, value) do
    Map.put(style, key, value)
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Updates multiple attributes from a map.
  '''
  @spec update_attrs(text_style(), map()) :: text_style()
  def update_attrs(style, attrs) do
    Map.merge(style, attrs)
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Validates a text style map.
  '''
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

  @doc '''
  Applies the given color to the text.
  '''
  @spec apply_color(String.t(), atom(), atom()) :: String.t()
  def apply_color(text, _fg, _bg) do
    # Implementation for applying color
    text
  end

  @doc '''
  Calculates the effective width of the text.
  '''
  @spec effective_width(String.t(), map()) :: integer()
  def effective_width(text, _buffer) do
    # Implementation for calculating effective width
    String.length(text)
  end

  @doc '''
  Returns the paired line type for the given line.
  '''
  @spec get_paired_line_type(String.t()) :: atom()
  def get_paired_line_type(_line) do
    # Implementation for getting paired line type
    :none
  end

  @doc '''
  Checks if the line needs a paired line.
  '''
  @spec needs_paired_line?(String.t()) :: boolean()
  def needs_paired_line?(_line) do
    # Implementation for checking if line needs pairing
    false
  end

  @doc '''
  Converts an ANSI code to a color name.
  '''
  @spec ansi_code_to_color_name(integer()) :: atom()
  def ansi_code_to_color_name(_code) do
    # Implementation for converting ANSI code to color name
    :default
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Resets bold text mode.
  '''
  @spec reset_bold(text_style()) :: text_style()
  def reset_bold(style) do
    %{style | bold: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Resets italic text mode.
  '''
  @spec reset_italic(text_style()) :: text_style()
  def reset_italic(style) do
    %{style | italic: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Resets underline text mode.
  '''
  @spec reset_underline(text_style()) :: text_style()
  def reset_underline(style) do
    %{style | underline: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Resets blink text mode.
  '''
  @spec reset_blink(text_style()) :: text_style()
  def reset_blink(style) do
    %{style | blink: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc '''
  Resets reverse video mode.
  '''
  @spec reset_reverse(text_style()) :: text_style()
  def reset_reverse(style) do
    %{style | reverse: false}
  end

  @doc '''
  Gets the hyperlink from a style.
  Returns the hyperlink URL or nil if no hyperlink is set.
  '''
  def get_hyperlink(%{hyperlink: url}) when is_binary(url), do: url
  def get_hyperlink(_), do: nil

  @doc '''
  Formats a style into SGR (Select Graphic Rendition) parameters.
  Returns a list of ANSI SGR codes.
  '''
  def format_sgr_params(style) do
    Enum.reduce(@sgr_style_map, [], fn {attr, code}, acc ->
      if Map.get(style, attr), do: [code] ++ acc, else: acc
    end)
    |> Enum.concat([38, 5, style.foreground])
    |> Enum.concat([48, 5, style.background])
  end

  @doc '''
  Sets a single attribute on the emulator.
  '''
  @spec set_attribute(t(), atom()) :: t()
  def set_attribute(emulator, attribute) do
    attributes = MapSet.put(emulator.attributes, attribute)
    %{emulator | attributes: attributes}
  end
end
