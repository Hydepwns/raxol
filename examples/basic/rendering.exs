# This is a kitchen sink example intended to show off most of the
# declarative-style rendering functionality provided by Raxol.
#
# Run this example with:
#
#   mix run examples/rendering.exs

defmodule RenderingDemo do
  @behaviour Raxol.App

  alias Raxol.Core.Runtime.Events.Subscription

  import Raxol.View
  import Raxol.View.Elements

  @spacebar :space

  def init(_context) do
    %{
      current_time: DateTime.utc_now(),
      series_1: [],
      series_2: [],
      overlay: true
    }
  end

  def update(model, message) do
    case message do
      %{type: :key, key: @spacebar, modifiers: []} ->
        %{model | overlay: !model.overlay}

      :tick ->
        %{
          model
          | current_time: DateTime.utc_now(),
            series_1: for(_ <- 0..50, do: :rand.uniform() * 1000),
            series_2: Enum.shuffle([0, 1, 2, 3, 4, 5, 6])
        }

      _ ->
        model
    end
  end

  def subscribe(_model) do
    Subscription.interval(500, :tick)
  end

  def render(model) do
    top_bar =
      Raxol.View.Elements.row do
        text(content: "A top bar for the view")
      end

    bottom_bar =
      Raxol.View.Elements.row do
        text(content: "A bottom bar for the view")
      end

    view do
      panel title: "Rendering Demo", height: :fill do
        Raxol.View.Elements.row do
          column(size: 4) do
            panel title: "Columns" do
              text(content: "4/12")
            end
          end
        end

        Raxol.View.Elements.row do
          column(size: 3) do
            panel do
              text(content: "3/12")
            end
          end

          column(size: 5) do
            panel do
              text(content: "5/12")
            end
          end
        end

        Raxol.View.Elements.row do
          column(size: 4) do
            panel title: "Text & Labels" do
              text(content: "Normal ")
              text(content: "Red", color: :red)

              text(
                content: "Blue, bold underlined",
                color: :blue,
                attributes: [:bold, :underline]
              )

              text(content: "Current Time:")
              text(content: DateTime.to_string(model.current_time))
            end
          end

          column(size: 8) do
            panel title: "Tables" do
              text(content: "[Table placeholder]")
            end
          end
        end

        Raxol.View.Elements.row do
          column(size: 4) do
            panel title: "Trees" do
              text(content: "[Tree placeholder]")
            end
          end

          column(size: 8) do
            panel title: "Charts & Sparklines" do
              text(content: "[Chart/Sparkline placeholder]")
            end
          end
        end
      end
    end
  end
end

Raxol.run(RenderingDemo)
