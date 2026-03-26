defmodule Raxol.Playground.AppTest do
  use ExUnit.Case, async: true

  alias Raxol.Playground.App

  defp key_event(char) do
    %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: char}}
  end

  defp special_key(key, extra \\ %{}) do
    %Raxol.Core.Events.Event{type: :key, data: Map.merge(%{key: key}, extra)}
  end

  describe "init/1" do
    test "initializes with components and first selected" do
      model = App.init(nil)
      assert length(model.components) == 23
      assert model.cursor == 0
      assert model.selected != nil
      assert model.focus == :sidebar
      assert model.demo_model != nil
    end
  end

  describe "sidebar navigation" do
    test "j moves cursor down" do
      model = App.init(nil)
      {model, []} = App.update(key_event("j"), model)
      assert model.cursor == 1
    end

    test "k moves cursor up" do
      model = App.init(nil)
      {model, []} = App.update(key_event("j"), model)
      {model, []} = App.update(key_event("k"), model)
      assert model.cursor == 0
    end

    test "cursor clamps to bounds" do
      model = App.init(nil)
      {model, []} = App.update(key_event("k"), model)
      assert model.cursor == 0
    end

    test "arrow keys also navigate" do
      model = App.init(nil)
      {model, []} = App.update(special_key(:down), model)
      assert model.cursor == 1
      {model, []} = App.update(special_key(:up), model)
      assert model.cursor == 0
    end
  end

  describe "component selection" do
    test "enter selects component and switches to demo focus" do
      model = App.init(nil)
      {model, []} = App.update(key_event("j"), model)
      {model, []} = App.update(special_key(:enter), model)
      assert model.selected.name == Enum.at(model.components, 1).name
      assert model.focus == :demo
      assert model.demo_model != nil
    end
  end

  describe "focus cycling" do
    test "tab cycles between sidebar and demo" do
      model = App.init(nil)
      assert model.focus == :sidebar
      {model, []} = App.update(special_key(:tab), model)
      assert model.focus == :demo
      {model, []} = App.update(special_key(:tab), model)
      assert model.focus == :sidebar
    end
  end

  describe "search" do
    test "/ enters search mode" do
      model = App.init(nil)
      {model, []} = App.update(key_event("/"), model)
      assert model.focus == :search
      assert model.search == ""
    end

    test "typing in search filters components" do
      model = App.init(nil)
      {model, []} = App.update(key_event("/"), model)
      {model, []} = App.update(key_event("b"), model)
      {model, []} = App.update(key_event("u"), model)
      {model, []} = App.update(key_event("t"), model)
      assert model.search == "but"
      assert length(model.components) >= 1
      assert Enum.any?(model.components, &(&1.name == "Button"))
    end

    test "escape exits search" do
      model = App.init(nil)
      {model, []} = App.update(key_event("/"), model)
      {model, []} = App.update(special_key(:escape), model)
      assert model.focus == :sidebar
    end

    test "backspace in search removes character" do
      model = App.init(nil)
      {model, []} = App.update(key_event("/"), model)
      {model, []} = App.update(key_event("a"), model)
      {model, []} = App.update(key_event("b"), model)
      assert model.search == "ab"
      {model, []} = App.update(special_key(:backspace), model)
      assert model.search == "a"
    end
  end

  describe "code panel" do
    test "c toggles code panel" do
      model = App.init(nil)
      assert model.show_code == false
      {model, []} = App.update(key_event("c"), model)
      assert model.show_code == true
      {model, []} = App.update(key_event("c"), model)
      assert model.show_code == false
    end
  end

  describe "demo forwarding" do
    test "events forward to demo when focused on demo" do
      model = App.init(nil)
      # Select Button demo
      {model, []} = App.update(special_key(:enter), model)
      assert model.focus == :demo
      # Send "1" which ButtonDemo handles as primary click
      {model, []} = App.update(key_event("1"), model)
      assert model.demo_model.clicks == 1
    end
  end

  describe "quit" do
    test "q sends quit command from sidebar" do
      model = App.init(nil)
      {_model, commands} = App.update(key_event("q"), model)
      assert commands != []
    end

    test "ctrl+c sends quit from any focus" do
      model = App.init(nil)

      event = %Raxol.Core.Events.Event{
        type: :key,
        data: %{key: :char, char: "c", ctrl: true}
      }

      {_model, commands} = App.update(event, model)
      assert commands != []
    end
  end

  describe "view" do
    test "renders without errors" do
      model = App.init(nil)
      view = App.view(model)
      assert is_map(view)
    end

    test "renders with code panel open" do
      model = App.init(nil)
      model = %{model | show_code: true}
      view = App.view(model)
      assert is_map(view)
    end

    test "renders with search active" do
      model = App.init(nil)
      model = %{model | focus: :search, search: "test"}
      view = App.view(model)
      assert is_map(view)
    end

    test "renders with no selection" do
      model = App.init(nil)
      model = %{model | selected: nil, demo_model: nil}
      view = App.view(model)
      assert is_map(view)
    end
  end
end
