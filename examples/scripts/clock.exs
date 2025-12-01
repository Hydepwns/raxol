# An example of how to create application loops.

defmodule Clock do
  # use Raxol.View
  import Raxol.View

  alias Raxol.Core.Events.EventManager
  alias Raxol.Window

  def start do
    {:ok, _pid} = Window.start_link()
    {:ok, _pid} = EventManager.start_link(name: EventManager)
    {:ok, _ref} = EventManager.subscribe([:keyboard])
    loop()
  end

  def loop do
    clock_view = render(DateTime.utc_now())
    Window.update(clock_view)

    receive do
      {:event, %{ch: ?q}} ->
        :ok = Window.close()
    after
      1_000 ->
        loop()
    end
  end

  def render(now) do
    time_str = DateTime.to_string(now)

    # view do
    #   panel title: "Clock Example ('q' to quit)", height: :fill do
    #     text(content: time_str)
    #   end
    # end
    ~V"""
    <.panel title="Clock Example ('q' to quit)" height=:fill>
      <.text>{time_str}</.text>
    </.panel>
    """
  end
end

Clock.start()
