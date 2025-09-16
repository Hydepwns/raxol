defprotocol Raxol.Protocols.Styleable do
  @moduledoc """
  Protocol for applying styles to data structures.

  This protocol provides a unified interface for applying visual styles
  (colors, formatting, effects) to different types of data in the terminal.

  ## Style Attributes

  Styles are represented as maps with the following optional keys:
    * `:foreground` - Foreground color (RGB tuple or color name)
    * `:background` - Background color (RGB tuple or color name)
    * `:bold` - Bold text (boolean)
    * `:italic` - Italic text (boolean)
    * `:underline` - Underlined text (boolean)
    * `:blink` - Blinking text (boolean)
    * `:reverse` - Reverse video (boolean)
    * `:hidden` - Hidden/invisible text (boolean)
    * `:strikethrough` - Strikethrough text (boolean)

  ## Examples

      defimpl Raxol.Protocols.Styleable, for: MyComponent do
        def apply_style(component, style) do
          %{component | style: merge_styles(component.style, style)}
        end

        def get_style(component) do
          component.style || %{}
        end

        def merge_styles(component, new_style) do
          %{component | style: Map.merge(get_style(component), new_style)}
        end

        def reset_style(component) do
          %{component | style: %{}}
        end
      end
  """

  @type style :: %{
          optional(:foreground) =>
            {non_neg_integer(), non_neg_integer(), non_neg_integer()} | atom(),
          optional(:background) =>
            {non_neg_integer(), non_neg_integer(), non_neg_integer()} | atom(),
          optional(:bold) => boolean(),
          optional(:italic) => boolean(),
          optional(:underline) => boolean(),
          optional(:blink) => boolean(),
          optional(:reverse) => boolean(),
          optional(:hidden) => boolean(),
          optional(:strikethrough) => boolean()
        }

  @doc """
  Applies a style to the data structure.

  ## Parameters
    * `data` - The data structure to style
    * `style` - The style map to apply

  ## Returns
  The data structure with the style applied.
  """
  @spec apply_style(t, style()) :: t
  def apply_style(data, style)

  @doc """
  Gets the current style of the data structure.

  ## Returns
  The current style map, or an empty map if no style is set.
  """
  @spec get_style(t) :: style()
  def get_style(data)

  @doc """
  Merges new styles with existing styles.

  New styles override existing ones for the same keys.

  ## Parameters
    * `data` - The data structure with existing styles
    * `new_style` - The new style map to merge

  ## Returns
  The data structure with merged styles.
  """
  @spec merge_styles(t, style()) :: t
  def merge_styles(data, new_style)

  @doc """
  Resets all styles to default.

  ## Returns
  The data structure with all styles removed.
  """
  @spec reset_style(t) :: t
  def reset_style(data)

  @doc """
  Converts the style to ANSI escape codes.

  ## Returns
  A string containing the ANSI escape codes for the style.
  """
  @spec to_ansi(t) :: binary()
  def to_ansi(data)
end

# Implementation for Color struct
defimpl Raxol.Protocols.Styleable, for: Raxol.Style.Colors.Color do
  def apply_style(color, style) do
    Map.merge(color, style)
  end

  def get_style(color) do
    %{
      foreground: {color.r, color.g, color.b}
    }
  end

  def merge_styles(color, new_style) do
    Map.merge(color, new_style)
  end

  def reset_style(color) do
    %{color | r: 0, g: 0, b: 0}
  end

  def to_ansi(%{r: r, g: g, b: b}) do
    "\e[38;2;#{r};#{g};#{b}m"
  end
end

# Implementation for Maps (generic style containers)
defimpl Raxol.Protocols.Styleable, for: Map do
  def apply_style(map, style) do
    merge_styles(map, style)
  end

  def get_style(map) do
    Map.get(map, :style, %{})
  end

  def merge_styles(map, new_style) do
    current_style = get_style(map)
    Map.put(map, :style, Map.merge(current_style, new_style))
  end

  def reset_style(map) do
    Map.delete(map, :style)
  end

  def to_ansi(map) do
    style = get_style(map)
    build_ansi_codes(style)
  end

  @spec build_ansi_codes(map()) :: binary()
  defp build_ansi_codes(style) do
    codes = []

    codes = if style[:bold], do: ["1" | codes], else: codes
    codes = if style[:italic], do: ["3" | codes], else: codes
    codes = if style[:underline], do: ["4" | codes], else: codes
    codes = if style[:blink], do: ["5" | codes], else: codes
    codes = if style[:reverse], do: ["7" | codes], else: codes
    codes = if style[:hidden], do: ["8" | codes], else: codes
    codes = if style[:strikethrough], do: ["9" | codes], else: codes

    codes =
      case style[:foreground] do
        {r, g, b} -> ["38;2;#{r};#{g};#{b}" | codes]
        :black -> ["30" | codes]
        :red -> ["31" | codes]
        :green -> ["32" | codes]
        :yellow -> ["33" | codes]
        :blue -> ["34" | codes]
        :magenta -> ["35" | codes]
        :cyan -> ["36" | codes]
        :white -> ["37" | codes]
        _ -> codes
      end

    codes =
      case style[:background] do
        {r, g, b} -> ["48;2;#{r};#{g};#{b}" | codes]
        :black -> ["40" | codes]
        :red -> ["41" | codes]
        :green -> ["42" | codes]
        :yellow -> ["43" | codes]
        :blue -> ["44" | codes]
        :magenta -> ["45" | codes]
        :cyan -> ["46" | codes]
        :white -> ["47" | codes]
        _ -> codes
      end

    if codes == [] do
      ""
    else
      "\e[#{Enum.join(codes, ";")}m"
    end
  end
end
