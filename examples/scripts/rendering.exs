# This is a kitchen sink example intended to show off some
# declarative-style rendering functionality provided by Raxol.
#
# Usage:
#   elixir examples/snippets/basic/rendering.exs

defmodule RenderingDemo do
  # Use the correct Application behaviour and View DSL
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  alias Raxol.Core.Runtime.Events.Subscription
  alias Raxol.Core.Events.Event
  alias Raxol.Core.Commands.Command
  require Raxol.Core.Runtime.Log

  # Spacebar character
  @spacebar " "

  @impl true
  def init(_context) do
    Raxol.Core.Runtime.Log.debug("RenderingDemo: init/1")

    {:ok,
     %{
       current_time: DateTime.utc_now(),
       series_1: Enum.map(0..10, fn _ -> :rand.uniform(100) end),
       series_2: Enum.shuffle(0..6),
       table_data: [
         %{id: 1, name: "Item A", value: :rand.uniform(100)},
         %{id: 2, name: "Item B", value: :rand.uniform(100)},
         %{id: 3, name: "Item C", value: :rand.uniform(100)}
       ],
       overlay: true
     }}
  end

  @impl true
  def update(message, model) do
    Raxol.Core.Runtime.Log.debug(
      "RenderingDemo: update/2 received message: \#{inspect(message)}"
    )

    case message do
      # Use Event struct for key presses
      %Event{type: :key, data: %{key: :char, char: @spacebar}} ->
        # Return :ok tuple
        {:ok, %{model | overlay: !model.overlay}, []}

      # Handle quit keys
      %Event{type: :key, data: %{key: :char, char: "q"}} ->
        {:ok, model, [Command.new(:quit)]}

      %Event{type: :key, data: %{key: :char, char: "c", ctrl: true}} ->
        {:ok, model, [Command.new(:quit)]}

      :tick ->
        new_model = %{
          model
          | current_time: DateTime.utc_now(),
            series_1: Enum.map(0..10, fn _ -> :rand.uniform(100) end),
            series_2: Enum.shuffle(0..6),
            table_data:
              Enum.map(model.table_data, fn row ->
                %{row | value: :rand.uniform(100)}
              end)
        }

        # Return :ok tuple
        {:ok, new_model, []}

      _ ->
        # Return :ok tuple
        {:ok, model, []}
    end
  end

  @impl true
  def subscriptions(_model) do
    Raxol.Core.Runtime.Log.debug("RenderingDemo: subscriptions/1")
    Subscription.interval(500, :tick)
  end

  @impl true
  def view(model) do
    Raxol.Core.Runtime.Log.debug("RenderingDemo: view/1")
    # No need for explicit Raxol.View.Elements.row when imported
    view do
      box title: "Rendering Demo",
          style: [[:height, :fill], [:padding, 1], [:border, :single]] do
        # Added outer column for layout
        column style: %{gap: 1} do
          row do
            box title: "Text Styling",
                style: [[:width, "50%"], [:border, :round]] do
              column style: %{padding: 1} do
                text(content: "Normal ")
                text(content: "Red", style: %{color: :red})

                text(
                  content: "Blue, bold underlined",
                  style: [[:color, :blue], :bold, :underline]
                )

                text(content: "Current Time:", style: %{margin_top: 1})
                text(content: DateTime.to_string(model.current_time))

                text(
                  content: "Press Space to toggle overlay: \#{model.overlay}"
                )
              end
            end

            box title: "Table Example",
                style: [[:width, "50%"], [:border, :round]] do
              # Use the actual table element
              table(
                id: :demo_table,
                data: model.table_data,
                columns: [
                  %{header: "ID", key: :id, width: 5},
                  %{header: "Name", key: :name, width: 10},
                  %{header: "Value", key: :value, width: 10}
                ],
                style: [[:height, 5], [:width, :fill]]
              )
            end
          end

          row do
            box title: "Placeholders",
                style: [[:width, "50%"], [:border, :round]] do
              column style: %{padding: 1} do
                text(content: "[Tree placeholder]")
                text(content: "[Chart/Sparkline placeholder]")
              end
            end

            box title: "Info", style: [[:width, "50%"], [:border, :round]] do
              column style: %{padding: 1} do
                text(content: "Press 'q' or Ctrl+C to quit.")
              end
            end
          end
        end

        # End outer column
      end
    end
  end
end

Raxol.Core.Runtime.Log.info("RenderingDemo: Starting Raxol...")
{:ok, _pid} = Raxol.start_link(RenderingDemo, [])
Raxol.Core.Runtime.Log.info("RenderingDemo: Raxol started. Running...")
