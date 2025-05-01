# This example demonstrates handling and displaying of events.
#
# Run this with: mix run examples/without-runtime/event_viewer.exs

# Top-level setup is not needed if module handles it
# alias Raxol.{EventManager, Window}
# import Raxol.View

# Start the window and subscribe to events
# {:ok, _pid} = Window.start_link()
# {:ok, _pid} = EventManager.start_link()
# :ok = EventManager.subscribe(self())

defmodule EventViewer do
  # use Raxol.View
  import Raxol.View

  alias Raxol.{EventManager, Window}

  # Removed alias Raxol.View as import Raxol.View is used

  # @line_count 30 # Unused

  @title "Event Viewer (click, resize, or press a key - 'q' to quit)"
  @input_mode :esc_with_mouse # Correct syntax for atom

  def start do
    {:ok, _pid} = Window.start_link(input_mode: @input_mode)
    {:ok, _pid} = EventManager.start_link()
    :ok = EventManager.subscribe(self())

    # Initial update removed, first event will render
    # :ok = Window.update(layout())
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

    # Wrap the whole view in ~V and the panel
    ~V"""
    <.panel title={@title} height=:fill>
      <.table>
        <.tr>
          <.td>Type</.td>
          <.td>{inspect(type)}</.td>
          <.td>{inspect(type_name)}</.td>
        </.tr>
        <.tr>
          <.td>Mod</.td>
          <.td>{inspect(mod)}</.td>
          <.td></.td>
        </.tr>
        <.tr>
          <.td>Key</.td>
          <.td>{inspect(key)}</.td>
          <.td>{inspect(key_name)}</.td>
        </.tr>
        <.tr>
          <.td>Char</.td>
          <.td>{inspect(ch)}</.td>
          <.td>{<<ch::utf8>>}</.td>
        </.tr>
        <.tr>
          <.td>Width</.td>
          <.td>{inspect(w)}</.td>
          <.td></.td>
        </.tr>
        <.tr>
          <.td>Height</.td>
          <.td>{inspect(h)}</.td>
          <.td></.td>
        </.tr>
        <.tr>
          <.td>X</.td>
          <.td>{inspect(x)}</.td>
          <.td></.td>
        </.tr>
        <.tr>
          <.td>Y</.td>
          <.td>{inspect(y)}</.td>
          <.td></.td>
        </.tr>
      </.table>
    </.panel>
    """
  end

  # Removed layout function, incorporated into event_view
  # def layout(children \\ []) do
  #   view do
  #     panel([title: @title, height: :fill], children)
  #   end
  # end

  def reverse_lookup(map, val) do
    # Add safety for not found keys
    case Enum.find(map, fn {_, v} -> v == val end) do
      {key, _} -> key
      nil -> :unknown
    end
  end

  # Simplified event_types and keys maps (assuming these exist elsewhere or are for example)
  defp event_types, do: %{key: 1, mouse: 2, resize: 3} # Example
  defp keys, do: %{enter: 13, q: 113} # Example


  # Removed commented out render function
  # defp render(events) do
  #   ...
  # end

  # Removed unused helper
  # defp key_from_val(map, val) do
  #  ...
  # end
end

# Removed confusing top-level code
# Initial state: empty event log
# state = EventViewer.new()
# Render the initial view
# :ok = Window.update(EventViewer.render(state))
# Main loop
# loop = fn loop, state ->
#   ...
# end
# Start the loop
# loop.(loop, state)

# Start the application via the module
EventViewer.start()
