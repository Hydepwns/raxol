defmodule Raxol.UI.Components.Display.Text do
  @moduledoc """
  Styled text rendering with wrapping, alignment, and truncation.

  Display-only widget -- no keyboard handling.

  Props:
  - `content` (string) -- text to display
  - `wrap` (`:word | :char | :none`) -- wrapping mode, default `:none`
  - `align` (`:left | :center | :right`) -- alignment within width, default `:left`
  - `width` (integer | nil) -- constraint for wrapping/alignment/truncation
  - `truncate` (boolean) -- truncate with ellipsis when exceeding width, default `false`
  - `style`, `theme`, `id` -- standard
  """

  alias Raxol.UI.Components.Input.TextWrapping
  alias Raxol.UI.Theming.Theme

  @behaviour Raxol.UI.Components.Base.Component

  @type t :: %{
          id: String.t() | atom(),
          content: String.t(),
          wrap: :word | :char | :none,
          align: :left | :center | :right,
          width: non_neg_integer() | nil,
          truncate: boolean(),
          style: map(),
          theme: map()
        }

  @impl true
  @spec init(keyword()) :: {:ok, t()}
  def init(props) do
    state = %{
      id:
        Keyword.get(props, :id, "text-#{:erlang.unique_integer([:positive])}"),
      content: Keyword.get(props, :content, ""),
      wrap: Keyword.get(props, :wrap, :none),
      align: Keyword.get(props, :align, :left),
      width: Keyword.get(props, :width),
      truncate: Keyword.get(props, :truncate, false),
      style: Keyword.get(props, :style, %{}),
      theme: Keyword.get(props, :theme, %{})
    }

    {:ok, state}
  end

  @impl true
  def mount(state), do: {state, []}

  @impl true
  def unmount(state), do: state

  @impl true
  @spec update(map(), t()) :: {t(), list()}
  def update(props, state) when is_map(props) do
    Raxol.UI.Components.Base.Component.merge_props(props, state)
  end

  def update(_msg, state), do: {state, []}

  @impl true
  def handle_event(_event, state, _context), do: {state, []}

  @impl true
  @spec render(t(), map()) :: map()
  def render(state, context) do
    theme = Map.merge(context[:theme] || %{}, state.theme || %{})
    theme_style = Theme.component_style(theme, :text)
    style = Map.merge(theme_style, state.style || %{})

    lines =
      process_content(state.content, state.width, state.wrap, state.truncate)

    lines = align_lines(lines, state.width, state.align)

    case lines do
      [single] ->
        Raxol.View.Components.text(id: state.id, content: single, style: style)

      multiple ->
        children =
          multiple
          |> Enum.with_index()
          |> Enum.map(fn {line, i} ->
            Raxol.View.Components.text(
              id: "#{state.id}-line-#{i}",
              content: line,
              style: style
            )
          end)

        %{type: :column, style: style, children: children}
    end
  end

  # --- Content processing ---

  defp process_content(content, nil, _wrap, _truncate), do: [content]

  defp process_content(content, _width, _wrap, _truncate) when content == "",
    do: [""]

  defp process_content(content, width, :none, true) do
    [truncate_line(content, width)]
  end

  defp process_content(content, _width, :none, false), do: [content]

  defp process_content(content, width, :word, _truncate) do
    TextWrapping.wrap_line_by_word(content, width)
  end

  defp process_content(content, width, :char, _truncate) do
    TextWrapping.wrap_line_by_char(content, width)
  end

  defp truncate_line(text, width) when width < 4 do
    String.slice(text, 0, width)
  end

  defp truncate_line(text, width) do
    if String.length(text) > width do
      String.slice(text, 0, width - 3) <> "..."
    else
      text
    end
  end

  # --- Alignment ---

  defp align_lines(lines, nil, _align), do: lines
  defp align_lines(lines, _width, :left), do: lines

  defp align_lines(lines, width, :right) do
    Enum.map(lines, fn line ->
      pad = max(width - String.length(line), 0)
      String.duplicate(" ", pad) <> line
    end)
  end

  defp align_lines(lines, width, :center) do
    Enum.map(lines, fn line ->
      total_pad = max(width - String.length(line), 0)
      left_pad = div(total_pad, 2)
      right_pad = total_pad - left_pad

      String.duplicate(" ", left_pad) <>
        line <> String.duplicate(" ", right_pad)
    end)
  end
end
