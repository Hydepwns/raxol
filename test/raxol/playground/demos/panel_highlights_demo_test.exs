defmodule Raxol.Playground.Demos.PanelHighlightsDemoTest do
  use ExUnit.Case, async: true

  alias Raxol.Playground.Demos.PanelHighlightsDemo

  defp special_key(key) do
    %Raxol.Core.Events.Event{type: :key, data: %{key: key}}
  end

  describe "init/1" do
    test "starts with focus on first panel" do
      model = PanelHighlightsDemo.init(nil)
      assert model.focused == 0
    end
  end

  describe "navigation" do
    test "right moves focus right" do
      model = PanelHighlightsDemo.init(nil)
      {model, []} = PanelHighlightsDemo.update(special_key(:right), model)
      assert model.focused == 1
    end

    test "left wraps within row" do
      model = %{focused: 0}
      {model, []} = PanelHighlightsDemo.update(special_key(:left), model)
      assert model.focused == 2
    end

    test "right wraps within row" do
      model = %{focused: 2}
      {model, []} = PanelHighlightsDemo.update(special_key(:right), model)
      assert model.focused == 0
    end

    test "down moves to second row" do
      model = %{focused: 1}
      {model, []} = PanelHighlightsDemo.update(special_key(:down), model)
      assert model.focused == 4
    end

    test "up moves to first row" do
      model = %{focused: 4}
      {model, []} = PanelHighlightsDemo.update(special_key(:up), model)
      assert model.focused == 1
    end

    test "up from first row stays" do
      model = %{focused: 1}
      {model, []} = PanelHighlightsDemo.update(special_key(:up), model)
      assert model.focused == 1
    end

    test "down from second row stays" do
      model = %{focused: 4}
      {model, []} = PanelHighlightsDemo.update(special_key(:down), model)
      assert model.focused == 4
    end
  end

  describe "subscribe/1" do
    test "returns empty list" do
      model = PanelHighlightsDemo.init(nil)
      assert PanelHighlightsDemo.subscribe(model) == []
    end
  end

  describe "view/1" do
    test "returns element tree" do
      model = PanelHighlightsDemo.init(nil)
      view = PanelHighlightsDemo.view(model)
      assert is_map(view)
    end
  end

  describe "unknown events" do
    test "unknown events pass through" do
      model = PanelHighlightsDemo.init(nil)
      {result, []} = PanelHighlightsDemo.update(:unknown, model)
      assert result == model
    end
  end
end
