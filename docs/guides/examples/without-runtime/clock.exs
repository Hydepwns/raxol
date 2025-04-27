# An example of how to create application loops.

defmodule Clock do
  use Raxol.View

  alias Raxol.{EventManager, Window}

  def start do
    {:ok, _pid} = Window.start_link()
    {:ok, _pid} = EventManager.start_link()
    :ok = EventManager.subscribe(self())
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

    view do
      panel title: "Clock Example ('q' to quit)", height: :fill do
        text(content: time_str)
      end
    end
  end
end

Clock.start()
