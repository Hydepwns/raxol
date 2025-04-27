# This example demonstrates handling and displaying of events.
#
# Run this with: mix run examples/without-runtime/event_viewer.exs

alias Raxol.{EventManager, Window}

import Raxol.View

# Start the window and subscribe to events
{:ok, _pid} = Window.start_link()
{:ok, _pid} = EventManager.start_link()
:ok = EventManager.subscribe(self())

defmodule EventViewer do
  use Raxol.View

  alias Raxol.{EventManager, Window, View}

  @line_count 30

  @title "Event Viewer (click, resize, or press a key - 'q' to quit)"
  @input_mode input_mode(:esc_with_mouse)

  def start do
    {:ok, _pid} = Window.start_link(input_mode: @input_mode)
    {:ok, _pid} = EventManager.start_link()
    :ok = EventManager.subscribe(self())

    :ok = Window.update(layout())
    loop()
  end

  def loop do
    receive do
      {:event, %{ch: ?q}} ->
        :ok = EventManager.stop()
        :ok = Window.close()

      {:event, %{} = event} ->
        :ok = Window.update(event_view(event))
        loop()
    end
  end

  def event_view(%{
        type: type,
        mod: mod,
        key: key,
        ch: ch,
        w: w,
        h: h,
        x: x,
        y: y
      }) do
    type_name = reverse_lookup(event_types(), type)

    key_name =
      if key != 0,
        do: reverse_lookup(keys(), key),
        else: :none

    layout([
      table do
        table_row do
          table_cell(content: "Type")
          table_cell(content: inspect(type))
          table_cell(content: inspect(type_name))
        end

        table_row do
          table_cell(content: "Mod")
          table_cell(content: inspect(mod))
          table_cell(content: "")
        end

        table_row do
          table_cell(content: "Key")
          table_cell(content: inspect(key))
          table_cell(content: inspect(key_name))
        end

        table_row do
          table_cell(content: "Char")
          table_cell(content: inspect(ch))
          table_cell(content: <<ch::utf8>>)
        end

        table_row do
          table_cell(content: "Width")
          table_cell(content: inspect(w))
          table_cell(content: "")
        end

        table_row do
          table_cell(content: "Height")
          table_cell(content: inspect(h))
          table_cell(content: "")
        end

        table_row do
          table_cell(content: "X")
          table_cell(content: inspect(x))
          table_cell(content: "")
        end

        table_row do
          table_cell(content: "Y")
          table_cell(content: inspect(y))
          table_cell(content: "")
        end
      end
    ])
  end

  def layout(children \\ []) do
    view do
      panel([title: @title, height: :fill], children)
    end
  end

  def reverse_lookup(map, val) do
    map |> Enum.find(fn {_, v} -> v == val end) |> elem(0)
  end

  # Converts the event history to a view definition.
  defp render(events) do
    view do
      panel title: "Event Viewer", height: :fill do
        # Table needs component
        # table headers: ["Type", "Data"] do
        #   for event <- events do
        #     table_row do
        #       table_cell(content: to_string(event.type))
        #       table_cell(content: inspect(event.data))
        #     end
        #   end
        # end
        text(content: "[Events table placeholder]")
      end
    end
  end

  defp key_from_val(map, val) do
    map |> Enum.find(fn {_, v} -> v == val end) |> elem(0)
  end
end

# Initial state: empty event log
state = EventViewer.new()

# Render the initial view
:ok = Window.update(EventViewer.render(state))

# Main loop
loop = fn loop, state ->
  receive do
    # When an event is received, add it to the list of entries
    {:event, %{} = e} = event ->
      # If we receive 'q', quit the application
      if e[:ch] == ?q do
        :ok = Window.close()
      else
        # Otherwise, add the event to the top of the events list and re-render
        new_state = EventViewer.add_event(state, event)
        :ok = Window.update(EventViewer.render(new_state))
        loop.(loop, new_state)
      end
  end
end

# Start the loop
loop.(loop, state)
