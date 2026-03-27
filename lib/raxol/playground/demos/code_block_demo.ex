defmodule Raxol.Playground.Demos.CodeBlockDemo do
  @moduledoc "Playground demo: code display with line numbers and language samples."
  use Raxol.Core.Runtime.Application

  @samples [
    %{
      lang: "Elixir",
      label: "Pattern Matching",
      code:
        "def greet(:world), do: \"Hello, world!\"\ndef greet(name), do: \"Hello, \#{name}!\""
    },
    %{
      lang: "Rust",
      label: "Hello World",
      code: "fn main() {\n    println!(\"Hello, world!\");\n}"
    },
    %{
      lang: "Python",
      label: "List Comprehension",
      code: "squares = [x ** 2 for x in range(10)]\nprint(squares)"
    }
  ]

  @impl true
  def init(_context) do
    %{current: 0, show_line_numbers: true}
  end

  @impl true
  def update(message, model) do
    max_idx = length(@samples) - 1

    case message do
      key_match("n") ->
        {%{model | current: min(model.current + 1, max_idx)}, []}

      key_match("p") ->
        {%{model | current: max(model.current - 1, 0)}, []}

      key_match("l") ->
        {%{model | show_line_numbers: not model.show_line_numbers}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    sample = Enum.at(@samples, model.current)
    lines = String.split(sample.code, "\n")

    code_lines =
      lines
      |> Enum.with_index(1)
      |> Enum.map(fn {line, num} ->
        if model.show_line_numbers do
          pad = String.pad_leading(Integer.to_string(num), 2)
          text("#{pad} | #{line}")
        else
          text("  #{line}")
        end
      end)

    ln_label = if model.show_line_numbers, do: "ON", else: "OFF"

    column style: %{gap: 1} do
      [
        text("CodeBlock Demo", style: [:bold]),
        divider(),
        text("#{sample.lang}: #{sample.label}", style: [:bold]),
        box style: %{border: :single, padding: 1, width: 45} do
          column style: %{gap: 0} do
            code_lines
          end
        end,
        divider(),
        row style: %{gap: 2} do
          [
            text("#{model.current + 1}/#{length(@samples)}"),
            text("Line numbers: #{ln_label}")
          ]
        end,
        text("[n] next  [p] previous  [l] toggle line numbers", style: [:dim])
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []
end
