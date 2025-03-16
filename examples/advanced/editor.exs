# A sample application that shows how to accept user input and render it to the
# terminal.
#
# Supports editing a single line of text with support for entering characters
# and spaces and deleting them. No support moving the cursor or multiline
# entry---that's left as an exercise for the reader.
#
# Run this example with:
#
#   mix run examples/editor.exs

defmodule Editor do
  @behaviour Raxol.App

  import Raxol.View
  import Raxol.Constants, only: [key: 1]

  @spacebar key(:space)

  @delete_keys [
    key(:delete),
    key(:backspace),
    key(:backspace2)
  ]

  def init(_context) do
    ""
  end

  def update(model, message) do
    case message do
      {:event, %{key: key}} when key in @delete_keys ->
        String.slice(model, 0..-2)

      {:event, %{key: @spacebar}} ->
        model <> " "

      {:event, %{ch: ch}} when ch > 0 ->
        model <> <<ch::utf8>>

      _ ->
        model
    end
  end

  def render(text) do
    view do
      panel title: "Editor (CTRL-d to quit)" do
        label(content: text <> "▌")
      end
    end
  end
end

Raxol.run(
  Editor,
  quit_events: [
    {:key, Raxol.Constants.key(:ctrl_d)}
  ]
)
