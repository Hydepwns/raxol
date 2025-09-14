# This example demonstrates advanced layout techniques using the `row` and `column` elements from Raxol.View.Elements.
defmodule Raxol.Docs.Guides.Examples.Layout.AdvancedLayoutTest do
  use Raxol.Core.Runtime.Application
  import Raxol.View.Elements

  @impl true
  def init(_opts) do
    # No initial state needed for this static layout example
    %{}
  end

  @impl true
  def update(message, model) do
    model
  end

  @impl true
  def view(_model) do
    view do
      column(
        gap: 20,
        padding: 10,
        style: "border: 1px solid #ccc; width: 400px;"
      ) do
        # Example 1: Centered Row
        text(content: "Row with centered items:", style: "font-weight: bold;")

        row(
          gap: 10,
          justify: :center,
          align: :center,
          style: "border: 1px dashed blue; padding: 5px;"
        ) do
          button(content: "Btn 1")
          button(content: "Button 2")
          button(content: "B3")
        end

        # Example 2: Space Between
        text(
          content: "Row with space-between items:",
          style: "font-weight: bold;"
        )

        row(
          gap: 10,
          justify: :space_between,
          style: "border: 1px dashed green; padding: 5px;"
        ) do
          text(content: "Left Item")
          text(content: "Right Item")
        end

        # Example 3: Nested Layout with Flex
        text(
          content: "Nested Column/Row with Flex:",
          style: "font-weight: bold;"
        )

        row(
          gap: 15,
          align: :start,
          style: "border: 1px dashed red; padding: 5px;"
        ) do
          # Fixed width column
          column(
            gap: 5,
            style: "border: 1px solid orange; padding: 5px; width: 100px;"
          ) do
            text(content: "Sidebar")
            button(content: "Nav 1")
            button(content: "Nav 2")
          end

          # Flexible column taking remaining space
          column(
            gap: 10,
            flex: 1,
            style: "border: 1px solid purple; padding: 5px;"
          ) do
            text(
              content: "Main Content Area",
              style: "font-weight: bold; text-align: center;"
            )

            row(gap: 5, justify: :space_around) do
              text_input(placeholder: "Input 1")
              text_input(placeholder: "Input 2")
            end

            panel(title: "Inner Panel") do
              text(
                content: "Content inside a panel within the flexible column."
              )
            end
          end
        end

        # Example 4: Column Alignment
        text(
          content: "Column with different alignments:",
          style: "font-weight: bold;"
        )

        row(
          gap: 10,
          style:
            "border: 1px dashed teal; padding: 5px; height: 100px; align-items: stretch;"
        ) do
          column(
            align: :start,
            flex: 1,
            style: "border: 1px solid gray; padding: 3px;"
          ) do
            text(content: "Align Start")
            button(content: "S")
          end

          column(
            align: :center,
            flex: 1,
            style: "border: 1px solid gray; padding: 3px;"
          ) do
            text(content: "Align Center")
            button(content: "C")
          end

          column(
            align: :end,
            flex: 1,
            style: "border: 1px solid gray; padding: 3px;"
          ) do
            text(content: "Align End")
            button(content: "E")
          end
        end
      end

      # End main column
    end
  end

  # Function to run the example directly
  def main do
    Raxol.start_link(__MODULE__, [])
    # For CI/test/demo: sleep for 2 seconds, then exit. Adjust as needed.
    Process.sleep(2000)
  end
end

# To run this example: mix run -e "Raxol.Docs.Guides.Examples.Layout.AdvancedLayoutTest.main()"
# (Assuming Raxol is a dependency or mix project is set up)
