defmodule Raxol.Playground.Demos.TextAreaDemo do
  @moduledoc "Playground demo: multi-line text editor with insert and normal modes."
  use Raxol.Core.Runtime.Application

  @impl true
  def init(_context) do
    %{
      lines: ["Hello, world!", "Edit me with 'i'", ""],
      cursor_line: 0,
      cursor_col: 0,
      mode: :normal
    }
  end

  @impl true
  def update(message, model) do
    case {model.mode, message} do
      {:normal, key_match("i")} ->
        {%{
           model
           | mode: :insert,
             cursor_col: String.length(current_line(model))
         }, []}

      {:normal, key_match("j")} ->
        {%{
           model
           | cursor_line: min(model.cursor_line + 1, length(model.lines) - 1)
         }, []}

      {:normal, key_match("k")} ->
        {%{model | cursor_line: max(model.cursor_line - 1, 0)}, []}

      {:insert, key_match(:escape)} ->
        {%{model | mode: :normal}, []}

      {:insert, key_match(:enter)} ->
        lines = List.insert_at(model.lines, model.cursor_line + 1, "")

        {%{
           model
           | lines: lines,
             cursor_line: model.cursor_line + 1,
             cursor_col: 0
         }, []}

      {:insert, key_match(:backspace)} ->
        line = current_line(model)
        new_line = String.slice(line, 0..-2//1)
        lines = List.replace_at(model.lines, model.cursor_line, new_line)
        {%{model | lines: lines, cursor_col: max(model.cursor_col - 1, 0)}, []}

      {:insert, key_match(:char, char: ch)}
      when byte_size(ch) == 1 ->
        line = current_line(model) <> ch
        lines = List.replace_at(model.lines, model.cursor_line, line)
        {%{model | lines: lines, cursor_col: model.cursor_col + 1}, []}

      _ ->
        {model, []}
    end
  end

  defp current_line(model), do: Enum.at(model.lines, model.cursor_line, "")

  @impl true
  def view(model) do
    mode_str = if model.mode == :normal, do: "NORMAL", else: "INSERT"

    line_rows =
      model.lines
      |> Enum.with_index()
      |> Enum.map(fn {line, i} ->
        prefix = if i == model.cursor_line, do: ">", else: " "
        num = String.pad_leading("#{i + 1}", 2)
        text("#{prefix} #{num} | #{line}")
      end)

    column style: %{gap: 1} do
      [
        text("TextArea Demo", style: [:bold]),
        text("Mode: #{mode_str}", style: [:bold]),
        divider(),
        box style: %{border: :single, padding: 1, width: 50} do
          column(style: %{gap: 0}, do: line_rows)
        end,
        text("Ln #{model.cursor_line + 1}, Col #{model.cursor_col}"),
        text("[i] insert  [esc] normal  [j/k] navigate  [enter] newline",
          style: [:dim]
        )
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end
