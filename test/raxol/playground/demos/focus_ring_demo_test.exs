defmodule Raxol.Playground.Demos.FocusRingDemoTest do
  use ExUnit.Case, async: true

  alias Raxol.Playground.Demos.FocusRingDemo

  @last_item_index 4

  defp key_event(char) do
    %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: char}}
  end

  defp special_key(key, extra \\ %{}) do
    %Raxol.Core.Events.Event{type: :key, data: Map.merge(%{key: key}, extra)}
  end

  describe "init/1" do
    test "starts focused on first item with solid style" do
      model = FocusRingDemo.init(nil)
      assert model.focused == 0
      assert model.style == :solid
      assert model.ring_config.style == :solid
    end
  end

  describe "navigation" do
    test "tab moves focus forward" do
      model = FocusRingDemo.init(nil)
      {model, []} = FocusRingDemo.update(special_key(:tab), model)
      assert model.focused == 1
    end

    test "tab wraps around" do
      model = %{FocusRingDemo.init(nil) | focused: @last_item_index}
      {model, []} = FocusRingDemo.update(special_key(:tab), model)
      assert model.focused == 0
    end

    test "shift+tab moves focus backward" do
      model = %{FocusRingDemo.init(nil) | focused: 2}
      {model, []} = FocusRingDemo.update(special_key(:tab, %{shift: true}), model)
      assert model.focused == 1
    end

    test "shift+tab wraps to last item" do
      model = FocusRingDemo.init(nil)
      {model, []} = FocusRingDemo.update(special_key(:tab, %{shift: true}), model)
      assert model.focused == @last_item_index
    end

    test "up moves focus up" do
      model = %{FocusRingDemo.init(nil) | focused: 3}
      {model, []} = FocusRingDemo.update(special_key(:up), model)
      assert model.focused == 2
    end

    test "up clamps at 0" do
      model = FocusRingDemo.init(nil)
      {model, []} = FocusRingDemo.update(special_key(:up), model)
      assert model.focused == 0
    end

    test "down moves focus down" do
      model = FocusRingDemo.init(nil)
      {model, []} = FocusRingDemo.update(special_key(:down), model)
      assert model.focused == 1
    end

    test "down clamps at last item" do
      model = %{FocusRingDemo.init(nil) | focused: @last_item_index}
      {model, []} = FocusRingDemo.update(special_key(:down), model)
      assert model.focused == @last_item_index
    end
  end

  describe "style cycling" do
    test "s cycles through styles" do
      model = FocusRingDemo.init(nil)
      assert model.style == :solid

      {model, []} = FocusRingDemo.update(key_event("s"), model)
      assert model.style == :double
      assert model.ring_config.style == :double

      {model, []} = FocusRingDemo.update(key_event("s"), model)
      assert model.style == :rounded

      {model, []} = FocusRingDemo.update(key_event("s"), model)
      assert model.style == :dots

      {model, []} = FocusRingDemo.update(key_event("s"), model)
      assert model.style == :solid
    end
  end

  describe "subscribe/1" do
    test "returns empty list" do
      model = FocusRingDemo.init(nil)
      assert FocusRingDemo.subscribe(model) == []
    end
  end

  describe "view/1" do
    test "returns element tree" do
      model = FocusRingDemo.init(nil)
      view = FocusRingDemo.view(model)
      assert is_map(view)
    end
  end

  describe "unknown events" do
    test "unknown events pass through" do
      model = FocusRingDemo.init(nil)
      {result, []} = FocusRingDemo.update(:unknown, model)
      assert result == model
    end
  end
end
