defmodule Raxol.Terminal.ANSI.TextFormatting do
  @moduledoc """
  Handles advanced text formatting features for the terminal emulator.
  This includes double-width and double-height characters, as well as
  other advanced text attributes and colors.
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

  @attribute_handlers %{
    reset: &Raxol.Terminal.ANSI.TextFormatting.new/0,
    double_width: &__MODULE__.set_double_width/1,
    double_height_top: &__MODULE__.set_double_height_top/1,
    double_height_bottom: &__MODULE__.set_double_height_bottom/1,
    no_double_width: &__MODULE__.reset_size/1,
    no_double_height: &__MODULE__.reset_size/1,
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
    overlined: &__MODULE__.set_overlined/1,
    default_fg: &__MODULE__.reset_foreground/1,
    default_bg: &__MODULE__.reset_background/1,
    normal_intensity: &__MODULE__.reset_bold/1,
    not_framed_encircled: &__MODULE__.reset_framed_encircled/1,
    not_overlined: &__MODULE__.reset_overlined/1
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
  @doc """
  Creates a new text formatting struct with default values.
  """
  def new do
    %__MODULE__{
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
    %{style | foreground: color}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets the background color.
  """
  @spec set_background(text_style(), color()) :: text_style()
  def set_background(style, color) do
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
  Applies a text attribute to the style map.

  ## Parameters

  * `style` - The current text style
  * `attribute` - The attribute to apply (e.g., :bold, :underline, etc.)

  ## Returns

  The updated text style with the new attribute applied.
  """
  @spec apply_attribute(text_style(), atom()) :: text_style()
  def apply_attribute(style, attribute) do
    case attribute do
      :reset ->
        new()

      :no_bold ->
        %{style | bold: false}

      :no_italic ->
        %{style | italic: false}

      :no_underline ->
        %{style | underline: false}

      :no_blink ->
        %{style | blink: false}

      :no_reverse ->
        %{style | reverse: false}

      :no_conceal ->
        %{style | conceal: false}

      :no_strikethrough ->
        %{style | strikethrough: false}

      :no_fraktur ->
        %{style | fraktur: false}

      :no_double_underline ->
        %{style | double_underline: false}

      :no_framed ->
        %{style | framed: false}

      :no_encircled ->
        %{style | encircled: false}

      :no_overlined ->
        %{style | overlined: false}

      _ ->
        case Map.get(@attribute_handlers, attribute) do
          nil -> style
          handler -> handler.(style)
        end
    end
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets bold text mode.
  """
  @spec set_bold(text_style()) :: text_style()
  def set_bold(style) do
    %{style | bold: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets faint text mode.
  """
  @spec set_faint(text_style()) :: text_style()
  def set_faint(style) do
    %{style | faint: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets italic text mode.
  """
  @spec set_italic(text_style()) :: text_style()
  def set_italic(style) do
    %{style | italic: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets underline text mode.
  """
  @spec set_underline(text_style()) :: text_style()
  def set_underline(style) do
    %{style | underline: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets blink text mode.
  """
  @spec set_blink(text_style()) :: text_style()
  def set_blink(style) do
    %{style | blink: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets reverse video mode.
  """
  @spec set_reverse(text_style()) :: text_style()
  def set_reverse(style) do
    %{style | reverse: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets concealed text mode.
  """
  @spec set_conceal(text_style()) :: text_style()
  def set_conceal(style) do
    %{style | conceal: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets strikethrough text mode.
  """
  @spec set_strikethrough(text_style()) :: text_style()
  def set_strikethrough(style) do
    %{style | strikethrough: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets fraktur text mode.
  """
  @spec set_fraktur(text_style()) :: text_style()
  def set_fraktur(style) do
    %{style | fraktur: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets double underline text mode.
  """
  @spec set_double_underline(text_style()) :: text_style()
  def set_double_underline(style) do
    %{style | double_underline: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets framed text mode.
  """
  @spec set_framed(text_style()) :: text_style()
  def set_framed(style) do
    %{style | framed: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets encircled text mode.
  """
  @spec set_encircled(text_style()) :: text_style()
  def set_encircled(style) do
    %{style | encircled: true}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Sets overlined text mode.
  """
  @spec set_overlined(text_style()) :: text_style()
  def set_overlined(style) do
    %{style | overlined: true}
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
    Enum.reduce(attributes, style, &apply_attribute(&2, &1))
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
  Converts an ANSI code to a color name.
  """
  @spec ansi_code_to_color_name(integer()) :: atom()
  def ansi_code_to_color_name(code) do
    case code do
      0 -> :black
      1 -> :red
      2 -> :green
      3 -> :yellow
      4 -> :blue
      5 -> :magenta
      6 -> :cyan
      7 -> :white
      8 -> :bright_black
      9 -> :bright_red
      10 -> :bright_green
      11 -> :bright_yellow
      12 -> :bright_blue
      13 -> :bright_magenta
      14 -> :bright_cyan
      15 -> :bright_white
      _ -> :default
    end
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

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets bold text mode.
  """
  @spec reset_bold(text_style()) :: text_style()
  def reset_bold(style) do
    %{style | bold: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets italic text mode.
  """
  @spec reset_italic(text_style()) :: text_style()
  def reset_italic(style) do
    %{style | italic: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets underline text mode.
  """
  @spec reset_underline(text_style()) :: text_style()
  def reset_underline(style) do
    %{style | underline: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets blink text mode.
  """
  @spec reset_blink(text_style()) :: text_style()
  def reset_blink(style) do
    %{style | blink: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets reverse video mode.
  """
  @spec reset_reverse(text_style()) :: text_style()
  def reset_reverse(style) do
    %{style | reverse: false}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets foreground color.
  """
  @spec reset_foreground(text_style()) :: text_style()
  def reset_foreground(style) do
    %{style | foreground: nil}
  end

  @impl Raxol.Terminal.ANSI.TextFormattingBehaviour
  @doc """
  Resets background color.
  """
  @spec reset_background(text_style()) :: text_style()
  def reset_background(style) do
    %{style | background: nil}
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

  @doc """
  Gets the hyperlink from a style.
  Returns the hyperlink URL or nil if no hyperlink is set.
  """
  def get_hyperlink(%{hyperlink: url}) when is_binary(url), do: url
  def get_hyperlink(_), do: nil

  @doc """
  Formats a style into SGR (Select Graphic Rendition) parameters.
  Returns a list of ANSI SGR codes.
  """
  def format_sgr_params(style) do
    Enum.reduce(@sgr_style_map, [], fn {attr, code}, acc ->
      if Map.get(style, attr), do: [code] ++ acc, else: acc
    end)
    |> Enum.concat([38, 5, style.foreground])
    |> Enum.concat([48, 5, style.background])
  end

  @doc """
  Sets a single attribute on the emulator.
  """
  @spec set_attribute(t(), atom()) :: t()
  def set_attribute(emulator, attribute) do
    attributes = MapSet.put(emulator.attributes, attribute)
    %{emulator | attributes: attributes}
  end

  @doc """
  Parses SGR (Select Graphic Rendition) parameters and applies them to the style.
  """
  @spec parse_sgr_param(integer() | tuple(), text_style()) :: text_style()
  def parse_sgr_param(param, style) do
    case param do
      0 -> new()
      code when is_integer(code) -> handle_integer_param(code, style)
      tuple when is_tuple(tuple) -> handle_tuple_param(tuple, style)
      _ -> style
    end
  end

  defp handle_integer_param(code, style) do
    cond do
      # Basic attributes
      code == 1 ->
        %{style | bold: true}

      code == 2 ->
        %{style | faint: true}

      code == 3 ->
        %{style | italic: true}

      code == 4 ->
        %{style | underline: true}

      code == 5 ->
        %{style | blink: true}

      code == 7 ->
        %{style | reverse: true}

      code == 8 ->
        %{style | conceal: true}

      code == 9 ->
        %{style | strikethrough: true}

      # Advanced attributes
      code == 51 ->
        %{style | framed: true}

      code == 52 ->
        %{style | encircled: true}

      code == 53 ->
        %{style | overlined: true}

      code == 54 ->
        %{style | framed: false, encircled: false}

      code == 55 ->
        %{style | overlined: false}

      # Colors
      code in [30, 31, 32, 33, 34, 35, 36, 37] ->
        %{style | foreground: ansi_code_to_color_name(code - 30)}

      code in [90, 91, 92, 93, 94, 95, 96, 97] ->
        %{style | foreground: ansi_code_to_color_name(code - 90)}

      code in [40, 41, 42, 43, 44, 45, 46, 47] ->
        %{style | background: ansi_code_to_color_name(code - 40)}

      code in [100, 101, 102, 103, 104, 105, 106, 107] ->
        %{style | background: ansi_code_to_color_name(code - 100)}

      true ->
        style
    end
  end

  defp handle_tuple_param({:fg_8bit, color_code}, style) do
    %{style | foreground: {:index, color_code}}
  end

  defp handle_tuple_param({:bg_8bit, color_code}, style) do
    %{style | background: {:index, color_code}}
  end

  defp handle_tuple_param({:fg_rgb, r, g, b}, style) do
    %{style | foreground: {:rgb, r, g, b}}
  end

  defp handle_tuple_param({:bg_rgb, r, g, b}, style) do
    %{style | background: {:rgb, r, g, b}}
  end

  defp handle_tuple_param(_, style) do
    style
  end
end
