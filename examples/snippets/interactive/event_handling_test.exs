# This example demonstrates event handling using the Raxol.UI.Components.Input.Button and Raxol.UI.Components.Input.TextField components.
defmodule Raxol.Docs.Guides.Examples.Interactive.EventHandlingTest do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  # Define the application state (model)
  defmodule State do
    defstruct count: 0,
    text_value: ""
  end

  @impl true
  def init(_opts) do
    # Initial state
    %State{}
  end

  @impl true
  def update(message, model) do
    case message do
      # Handle the :on_click event from the button
      {:button_clicked} ->
        IO.puts("Increment button clicked!")
        %State{model | count: model.count + 1}

      # Handle the :on_change event from the text input
      {:text_changed, new_value} ->
        IO.puts("Text input changed: #{new_value}")
        %State{model | text_value: new_value}

      # Catch-all for other messages
      _ ->
        IO.inspect(message, label: "Unhandled message")
        model
    end
  end

  @impl true
  def view(model = %State{}) do
    view do
      column(gap: 15, padding: 10, style: "border: 1px solid #ccc; width: 300px;") do
        # Display the current count
        text(content: "Current Count: #{model.count}", style: "font-size: 1.2em;")

        # Button that sends a :button_clicked message on click
        button(
          content: "Increment",
          on_click: {:button_clicked}, # Send this tuple as the message
          style: :primary
        )

        # Text input that sends :text_changed message on change
        text_input(
          id: "my-text-input",
          placeholder: "Type something...",
          value: model.text_value,
          on_change: {:text_changed} # Send {:text_changed, new_value}
        )

        # Display the current text value
        text(content: "You typed: #{model.text_value}")
      end
    end
  end

  # Function to run the example directly
  def main do
    Raxol.start_link(__MODULE__, [])
    # For CI/test/demo: sleep for 2 seconds, then exit. Adjust as needed.
    Process.sleep(2000)
  end
end

# To run this example: mix run -e "Raxol.Docs.Guides.Examples.Interactive.EventHandlingTest.main()"
# (Assuming Raxol is a dependency or mix project is set up)
