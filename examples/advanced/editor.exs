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

  @spacebar :space

  @delete_keys [
    :delete,
    :backspace
  ]

  def init(_context) do
    ""
  end

  def update(model, message) do
    case message do
      %{type: :key, key: key, modifiers: []} when key in @delete_keys ->
        String.slice(model, 0..-2)

      %{type: :key, key: @spacebar, modifiers: []} ->
        model <> " "

      %{type: :key, key: char_code, modifiers: []} when is_integer(char_code) and char_code >= 32 ->
        model <> <<char_code::utf8>>

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
  quit_keys: [
    %{type: :key, key: ?d, modifiers: [:ctrl]}
  ]
)
