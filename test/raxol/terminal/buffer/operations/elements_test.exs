defmodule Raxol.Terminal.Buffer.Operations.ElementsTest do
  use ExUnit.Case, async: true
  doctest Raxol.Terminal.Buffer.Operations.Elements

  alias Raxol.Terminal.Buffer.Operations.Elements

  describe "move_element/3" do
    test "updates element position" do
      element = %{x: 5, y: 5, width: 10, height: 5, content: "test"}

      result = Elements.move_element(element, 10, 15)

      assert result.x == 10
      assert result.y == 15
      assert result.width == 10  # Should preserve other properties
      assert result.height == 5
      assert result.content == "test"
    end
  end

  describe "set_element_opacity/2" do
    test "sets opacity within valid range" do
      element = %{opacity: 1.0}

      result = Elements.set_element_opacity(element, 0.5)

      assert result.opacity == 0.5
    end

    test "handles full transparency" do
      element = %{opacity: 1.0}

      result = Elements.set_element_opacity(element, 0.0)

      assert result.opacity == 0.0
    end

    test "handles full opacity" do
      element = %{opacity: 0.5}

      result = Elements.set_element_opacity(element, 1.0)

      assert result.opacity == 1.0
    end
  end

  describe "resize_element/3" do
    test "updates element dimensions" do
      element = %{x: 5, y: 5, width: 10, height: 5, content: "test"}

      result = Elements.resize_element(element, 20, 10)

      assert result.width == 20
      assert result.height == 10
      assert result.x == 5  # Should preserve position
      assert result.y == 5
      assert result.content == "test"
    end

    test "requires positive dimensions" do
      element = %{width: 10, height: 5}

      # Should not raise for positive dimensions
      assert %{width: 1, height: 1} = Elements.resize_element(element, 1, 1)
    end
  end
end