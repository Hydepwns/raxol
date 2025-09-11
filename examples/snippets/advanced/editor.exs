# A sample application that shows how to accept user input and render it to the
# terminal.
#
# Supports editing a single line of text with support for entering characters
# and spaces and deleting them. No support moving the cursor or multiline
# entry.
#
# Usage:
#   elixir examples/snippets/advanced/editor.exs

# Renamed module
defmodule EditorExample do
  # Use correct behaviour and DSL
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  alias Raxol.Core.Events.Event
  alias Raxol.Core.Commands.Command
  require Raxol.Core.Runtime.Log

  # Space character
  @spacebar " "

  @delete_keys [
    :delete,
    :backspace
  ]

  @impl true
  def init(_context) do
    Raxol.Core.Runtime.Log.debug("EditorExample: init/1")
    # Return :ok tuple with map model
    {:ok, %{text: ""}}
  end

  @impl true
  def update(message, model) do
    Raxol.Core.Runtime.Log.debug(
      "EditorExample: update/2 received message: \#{inspect(message)}"
    )

    case message do
      # Use Event struct for key presses
      %Event{type: :key, data: %{key: key_name}} when key_name in @delete_keys ->
        new_text = String.slice(model.text, 0..-2) || ""
        {:ok, %{model | text: new_text}, []}

      %Event{type: :key, data: %{key: :char, char: @spacebar}} ->
        {:ok, %{model | text: model.text <> @spacebar}, []}

      # Check for printable character
      %Event{type: :key, data: %{key: :char, char: char}}
      when not is_nil(char) and String.length(char) == 1 ->
        # Append printable chars (basic check)
        {:ok, %{model | text: model.text <> char}, []}

      # Handle quit keys
      %Event{type: :key, data: %{key: :char, char: "q"}} ->
        {:ok, model, [Command.new(:quit)]}

      %Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {:ok, model, [Command.new(:quit)]}

      _ ->
        # Return :ok tuple
        {:ok, model, []}
    end
  end

  # Renamed from render/1
  @impl true
  def view(%{text: text} = model) do
    Raxol.Core.Runtime.Log.debug("EditorExample: view/1")

    view do
      # Use box and text
      box title: "Simple Editor (q/Ctrl+C to quit)",
          style: [[:border, :single], [:padding, 1]] do
        # Add a simple cursor indicator
        text(content: text <> "_")
      end
    end
  end
end

Raxol.Core.Runtime.Log.info("EditorExample: Starting Raxol...")
# Use standard startup
{:ok, _pid} = Raxol.start_link(EditorExample, [])
Raxol.Core.Runtime.Log.info("EditorExample: Raxol started. Running...")
