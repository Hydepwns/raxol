defmodule Raxol.UI.Layout.EngineTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Layout.Engine
  alias Raxol.UI.Layout.{Grid, Panels, Containers}

  describe "apply_layout/2" do
    test "applies layout to a simple view" do
      view = %{
        type: :view,
        children: [
          %{type: :label, attrs: %{content: "Hello, World!"}}
        ]
      }

      dimensions = %{width: 80, height: 24}

      result = Engine.apply_layout(view, dimensions)

      assert is_list(result)
      assert length(result) > 0

      # The first element should be a text element
      text_element = Enum.find(result, fn elem -> elem.type == :text end)
      assert text_element != nil
      assert text_element.text == "Hello, World!"
      assert text_element.x == 0
      assert text_element.y == 0
    end

    test "applies layout to a view with a panel" do
      view = %{
        type: :view,
        children: [
          %{
            type: :panel,
            attrs: %{title: "Test Panel"},
            children: [
              %{type: :label, attrs: %{content: "Panel Content"}}
            ]
          }
        ]
      }

      dimensions = %{width: 80, height: 24}

      result = Engine.apply_layout(view, dimensions)

      assert is_list(result)

      # Find the panel box
      box_element = Enum.find(result, fn elem -> elem.type == :box end)
      assert box_element != nil
      assert box_element.x == 0
      assert box_element.y == 0
      assert box_element.width == 80
      assert box_element.height == 24

      # Find the panel title
      title_element =
        Enum.find(result, fn
          %{type: :text, text: text} -> String.contains?(text, "Test Panel")
          _ -> false
        end)

      assert title_element != nil

      # Find the panel content
      content_element =
        Enum.find(result, fn
          %{type: :text, text: "Panel Content"} -> true
          _ -> false
        end)

      assert content_element != nil
      # Content should be inside the panel
      assert content_element.x > 0
      assert content_element.y > 0
    end

    test "applies layout to nested containers" do
      view = %{
        type: :view,
        children: [
          %{
            type: :row,
            children: [
              %{
                type: :column,
                children: [
                  %{type: :label, attrs: %{content: "Top Left"}},
                  %{type: :label, attrs: %{content: "Bottom Left"}}
                ]
              },
              %{
                type: :column,
                children: [
                  %{type: :label, attrs: %{content: "Top Right"}},
                  %{type: :label, attrs: %{content: "Bottom Right"}}
                ]
              }
            ]
          }
        ]
      }

      dimensions = %{width: 80, height: 24}

      result = Engine.apply_layout(view, dimensions)

      assert is_list(result)
      # Four label elements
      assert length(result) == 4

      # Find the labels
      top_left =
        Enum.find(result, fn
          %{type: :text, text: "Top Left"} -> true
          _ -> false
        end)

      bottom_left =
        Enum.find(result, fn
          %{type: :text, text: "Bottom Left"} -> true
          _ -> false
        end)

      top_right =
        Enum.find(result, fn
          %{type: :text, text: "Top Right"} -> true
          _ -> false
        end)

      bottom_right =
        Enum.find(result, fn
          %{type: :text, text: "Bottom Right"} -> true
          _ -> false
        end)

      assert top_left != nil
      assert bottom_left != nil
      assert top_right != nil
      assert bottom_right != nil

      # Check vertical and horizontal relationships
      assert top_left.y < bottom_left.y
      assert top_right.y < bottom_right.y
      assert top_left.x < top_right.x
      assert bottom_left.x < bottom_right.x
    end
  end

  describe "measure_element/2" do
    test "measures a label element" do
      element = %{type: :label, attrs: %{content: "Test Label"}}
      available_space = %{width: 80, height: 24}

      dimensions = Engine.measure_element(element, available_space)

      # Length of "Test Label"
      assert dimensions.width == 10
      assert dimensions.height == 1
    end

    test "measures a button element" do
      element = %{type: :button, attrs: %{label: "Click Me"}}
      available_space = %{width: 80, height: 24}

      dimensions = Engine.measure_element(element, available_space)

      # Button width = text length + 4 for padding
      assert dimensions.width == 12
      assert dimensions.height == 3
    end

    test "measures a text input element" do
      element = %{type: :text_input, attrs: %{value: "Hello"}}
      available_space = %{width: 80, height: 24}

      dimensions = Engine.measure_element(element, available_space)

      # Text input width = text length + 4 for padding
      assert dimensions.width == 9
      assert dimensions.height == 3
    end

    test "constrains element size to available space" do
      # Create a label with very long text
      element = %{type: :label, attrs: %{content: String.duplicate("A", 100)}}
      available_space = %{width: 50, height: 24}

      dimensions = Engine.measure_element(element, available_space)

      # Constrained to available width
      assert dimensions.width == 50
      assert dimensions.height == 1
    end
  end
end
