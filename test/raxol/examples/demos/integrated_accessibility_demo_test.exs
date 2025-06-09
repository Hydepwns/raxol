defmodule Raxol.Examples.Demos.IntegratedAccessibilityDemoTest do
  use ExUnit.Case, async: true

  alias Raxol.Examples.Demos.IntegratedAccessibilityDemo

  describe "IntegratedAccessibilityDemo" do
    test "initializes and renders without errors" do
      # Test init
      assert {:ok, {model, _commands}} = IntegratedAccessibilityDemo.init([])
      assert is_map(model)

      # Test view
      # The view function returns a structure that the Layout engine would process.
      # For this basic test, we just want to ensure it doesn't crash.
      view_structure = IntegratedAccessibilityDemo.view(model)

      # Basic check on the returned view structure
      assert is_map(view_structure)
      assert Map.has_key?(view_structure, :type)
      # Based on the demo's top-level View.column
      assert view_structure.type == :flex
      assert is_list(view_structure.children)
    end
  end
end
