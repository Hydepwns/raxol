defmodule MultipleViewsDemo do
  @moduledoc """
  An example of how to implement navigation between multiple views.
  """

  alias ExTermbox.{Constants, EventManager, Event, Window}
  import ExTermbox.Renderer.View

  @title "Multiple Views Demo (Press 1, 2 or 3, or q to quit)"

  def run do
    {:ok, _pid} = Window.start_link()
    {:ok, _pid} = EventManager.start_link()
    :ok = EventManager.subscribe(self())

    loop(view_1())
  end

  def loop(view) do
    Window.update(view)

    receive do
      {:event, %Event{ch: ?q}} ->
        :ok = Window.close()

      {:event, %Event{ch: ?1}} ->
        loop(view_1())

      {:event, %Event{ch: ?2}} ->
        loop(view_2())

      {:event, %Event{ch: ?3}} ->
        loop(view_3())
    end
  end

  def view_1 do
    view(top_bar: title_bar(), bottom_bar: status_bar_for("View 1")) do
      element(:panel, %{title: "View 1", height: :fill}, [])
    end
  end

  def view_2 do
    view(top_bar: title_bar(), bottom_bar: status_bar_for("View 2")) do
      element(:panel, %{title: "View 2", height: :fill}, [])
    end
  end

  def view_3 do
    view(top_bar: title_bar(), bottom_bar: status_bar_for("View 3")) do
      element(:panel, %{title: "View 3", height: :fill}, [])
    end
  end

  def title_bar do
    bar do
      element(:text, [@title])
    end
  end

  def status_bar_for(selected) do
    bar do
      element(
        :text_group,
        ["View 1", "View 2", "View 3"]
        |> Enum.map(fn opt ->
          element(:text, if(opt == selected, do: highlighted(), else: %{}), [
            opt
          ])
        end)
        |> Enum.intersperse(element(:text, [" "]))
      )
    end
  end

  def highlighted do
    %{
      background: Constants.color(:white),
      color: Constants.color(:black)
    }
  end
end

MultipleViewsDemo.run()
