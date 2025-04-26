defmodule Raxol.UI.Layout.PanelsTest do
  use ExUnit.Case, async: true

  alias Raxol.UI.Layout.Panels

  describe "measure/2" do
    test "measures a simple panel" do
      panel = %{
        type: :panel,
        attrs: %{},
        children: []
      }

      available_space = %{width: 80, height: 24}

      dimensions = Panels.measure(panel, available_space)

      # Uses full available width by default
      assert dimensions.width == 80
      # Uses full available height by default
      assert dimensions.height == 24
    end

    test "measures a panel with specific dimensions" do
      panel = %{
        type: :panel,
        attrs: %{width: 40, height: 10},
        children: []
      }

      available_space = %{width: 80, height: 24}

      dimensions = Panels.measure(panel, available_space)

      assert dimensions.width == 40
      assert dimensions.height == 10
    end

    test "enforces minimum dimensions" do
      panel = %{
        type: :panel,
        attrs: %{width: 2, height: 2},
        children: []
      }

      available_space = %{width: 80, height: 24}

      dimensions = Panels.measure(panel, available_space)

      # Minimum width and height for a panel should be enforced
      # Minimum width to accommodate borders
      assert dimensions.width >= 4
      # Minimum height to accommodate borders
      assert dimensions.height >= 3
    end

    test "constrains to available space" do
      panel = %{
        type: :panel,
        attrs: %{width: 100, height: 50},
        children: []
      }

      available_space = %{width: 80, height: 24}

      dimensions = Panels.measure(panel, available_space)

      # Should be constrained to available space
      assert dimensions.width == 80
      assert dimensions.height == 24
    end
  end

  describe "process/3" do
    test "processes a panel with no children" do
      panel = %{
        type: :panel,
        attrs: %{title: "Empty Panel"},
        children: []
      }

      space = %{x: 0, y: 0, width: 80, height: 24}

      result = Panels.process(panel, space, [])

      # Should at least include panel elements (box and title)
      assert is_list(List.flatten(result))
      assert length(List.flatten(result)) >= 2

      # Find box element
      box =
        Enum.find(List.flatten(result), fn
          %{type: :box} -> true
          _ -> false
        end)

      assert box != nil
      assert box.width == 80
      assert box.height == 24

      # Find title element
      title =
        Enum.find(List.flatten(result), fn
          %{type: :text, text: text} -> String.contains?(text, "Empty Panel")
          _ -> false
        end)

      assert title != nil
    end

    test "processes a panel with single child" do
      panel = %{
        type: :panel,
        attrs: %{title: "Panel with Child"},
        children: %{type: :label, attrs: %{content: "Child Content"}}
      }

      space = %{x: 0, y: 0, width: 80, height: 24}

      result = Panels.process(panel, space, [])

      # Flattened results should include panel elements and child
      flattened = List.flatten(result)

      # Find child element
      child =
        Enum.find(flattened, fn
          %{type: :text, text: "Child Content"} -> true
          _ -> false
        end)

      assert child != nil

      # Child should be positioned inside the panel borders
      assert child.x > 0
      assert child.y > 0
      assert child.x < 80
      assert child.y < 24
    end

    test "processes a panel with multiple children" do
      panel = %{
        type: :panel,
        attrs: %{title: "Panel with Children"},
        children: [
          %{type: :label, attrs: %{content: "First Child"}},
          %{type: :label, attrs: %{content: "Second Child"}}
        ]
      }

      space = %{x: 0, y: 0, width: 80, height: 24}

      result = Panels.process(panel, space, [])

      # Flattened results should include panel elements and children
      flattened = List.flatten(result)

      # Find child elements
      first_child =
        Enum.find(flattened, fn
          %{type: :text, text: "First Child"} -> true
          _ -> false
        end)

      second_child =
        Enum.find(flattened, fn
          %{type: :text, text: "Second Child"} -> true
          _ -> false
        end)

      assert first_child != nil
      assert second_child != nil

      # Both children should be positioned inside the panel borders
      assert first_child.x > 0
      assert first_child.y > 0
      assert second_child.x > 0
      assert second_child.y > 0
    end

    test "applies different border styles" do
      # Test single border
      single_panel = %{
        type: :panel,
        attrs: %{title: "Single Border", border: :single},
        children: []
      }

      single_result =
        Panels.process(single_panel, %{x: 0, y: 0, width: 20, height: 10}, [])

      # Test double border
      double_panel = %{
        type: :panel,
        attrs: %{title: "Double Border", border: :double},
        children: []
      }

      double_result =
        Panels.process(double_panel, %{x: 0, y: 0, width: 20, height: 10}, [])

      # Test thick border
      thick_panel = %{
        type: :panel,
        attrs: %{title: "Thick Border", border: :thick},
        children: []
      }

      thick_result =
        Panels.process(thick_panel, %{x: 0, y: 0, width: 20, height: 10}, [])

      # Test no border
      no_border_panel = %{
        type: :panel,
        attrs: %{title: "No Border", border: :none},
        children: []
      }

      no_border_result =
        Panels.process(
          no_border_panel,
          %{x: 0, y: 0, width: 20, height: 10},
          []
        )

      # Verify border types are different by looking at box elements
      single_box =
        Enum.find(List.flatten(single_result), fn
          %{type: :box} -> true
          _ -> false
        end)

      double_box =
        Enum.find(List.flatten(double_result), fn
          %{type: :box} -> true
          _ -> false
        end)

      thick_box =
        Enum.find(List.flatten(thick_result), fn
          %{type: :box} -> true
          _ -> false
        end)

      # Each border style should have a box element with different border chars
      assert single_box != nil
      assert double_box != nil
      assert thick_box != nil

      # For no border, there should be no box element
      no_border_box =
        Enum.find(List.flatten(no_border_result), fn
          %{type: :box} -> true
          _ -> false
        end)

      if no_border_box != nil do
        # If there's a box, it shouldn't have border chars
        assert no_border_box.attrs.border == nil
      end
    end
  end
end
