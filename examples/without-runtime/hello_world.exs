# This is a simple terminal application to show how Raxol works.
#
# This application will display "Hello, World!" and quit when the 'q' key is
# pressed.
#
# Run this example with: mix run examples/without-runtime/hello_world.exs

alias Raxol.{EventManager, Window}

import Raxol.View

# First, we initialize the terminal window.
{:ok, _pid} = Window.start_link()

# Next, we start the event manager, which will translate terminal events into
# Elixir messages for our process.
{:ok, _pid} = EventManager.start_link()

# Let's subscribe `self()` to receive events from the event manager.
:ok = EventManager.subscribe(self())

# Now we define the view.
hello_world_view =
  view do
    panel title: "Hello, World!", height: :fill do
      label(content: "Press 'q' to quit.")
    end
  end

# Update the window with our view.
:ok = Window.update(hello_world_view)

# We'll loop until a 'q' key is pressed. When the key is detected, we'll close
# the window and the application will exit.
receive do
  {:event, %{ch: ?q}} ->
    :ok = Window.close()
end
