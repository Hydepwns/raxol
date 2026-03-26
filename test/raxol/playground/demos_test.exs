defmodule Raxol.Playground.DemosTest do
  use ExUnit.Case, async: true

  alias Raxol.Playground.Demos.{
    ButtonDemo,
    TextInputDemo,
    TableDemo,
    ProgressDemo,
    ModalDemo,
    MenuDemo
  }

  defp key_event(char) do
    %Raxol.Core.Events.Event{type: :key, data: %{key: :char, char: char}}
  end

  defp special_key(key, extra \\ %{}) do
    %Raxol.Core.Events.Event{type: :key, data: Map.merge(%{key: key}, extra)}
  end

  describe "ButtonDemo" do
    test "init returns zero state" do
      model = ButtonDemo.init(nil)
      assert model.clicks == 0
      assert model.last_action == "none"
    end

    test "primary click increments" do
      model = ButtonDemo.init(nil)
      {model, []} = ButtonDemo.update(:primary, model)
      assert model.clicks == 1
      assert model.last_action == "primary"
    end

    test "danger resets clicks" do
      model = %{clicks: 5, last_action: "primary"}
      {model, []} = ButtonDemo.update(:danger, model)
      assert model.clicks == 0
      assert model.last_action == "reset"
    end

    test "keyboard shortcut 1 increments" do
      model = ButtonDemo.init(nil)
      {model, []} = ButtonDemo.update(key_event("1"), model)
      assert model.clicks == 1
    end

    test "view returns element tree" do
      model = ButtonDemo.init(nil)
      view = ButtonDemo.view(model)
      assert is_map(view)
    end
  end

  describe "TextInputDemo" do
    test "init returns empty value" do
      model = TextInputDemo.init(nil)
      assert model.value == ""
      assert model.char_count == 0
    end

    test "typing appends characters" do
      model = TextInputDemo.init(nil)
      {model, []} = TextInputDemo.update(key_event("h"), model)
      {model, []} = TextInputDemo.update(key_event("i"), model)
      assert model.value == "hi"
      assert model.char_count == 2
    end

    test "backspace removes last character" do
      model = %{value: "hello", char_count: 5}
      {model, []} = TextInputDemo.update(special_key(:backspace), model)
      assert model.value == "hell"
      assert model.char_count == 4
    end

    test "backspace on empty string stays empty" do
      model = %{value: "", char_count: 0}
      {model, []} = TextInputDemo.update(special_key(:backspace), model)
      assert model.value == ""
    end

    test "view returns element tree" do
      model = TextInputDemo.init(nil)
      view = TextInputDemo.view(model)
      assert is_map(view)
    end
  end

  describe "TableDemo" do
    test "init starts at row 0" do
      model = TableDemo.init(nil)
      assert model.cursor == 0
      assert model.sort_col == nil
    end

    test "j moves cursor down" do
      model = TableDemo.init(nil)
      {model, []} = TableDemo.update(key_event("j"), model)
      assert model.cursor == 1
    end

    test "k moves cursor up" do
      model = %{cursor: 2, sort_col: nil, sort_dir: :asc}
      {model, []} = TableDemo.update(key_event("k"), model)
      assert model.cursor == 1
    end

    test "cursor does not go below 0" do
      model = %{cursor: 0, sort_col: nil, sort_dir: :asc}
      {model, []} = TableDemo.update(key_event("k"), model)
      assert model.cursor == 0
    end

    test "s cycles sort" do
      model = TableDemo.init(nil)
      {model, []} = TableDemo.update(key_event("s"), model)
      assert model.sort_col == 1
      assert model.sort_dir == :asc
    end

    test "view returns element tree" do
      model = TableDemo.init(nil)
      view = TableDemo.view(model)
      assert is_map(view)
    end
  end

  describe "ProgressDemo" do
    test "init starts at 50" do
      model = ProgressDemo.init(nil)
      assert model.value == 50
      assert model.auto == false
    end

    test "plus increments by 5" do
      model = ProgressDemo.init(nil)
      {model, []} = ProgressDemo.update(key_event("+"), model)
      assert model.value == 55
    end

    test "minus decrements by 5" do
      model = ProgressDemo.init(nil)
      {model, []} = ProgressDemo.update(key_event("-"), model)
      assert model.value == 45
    end

    test "value clamps to 0-100" do
      model = %{value: 100, auto: false}
      {model, []} = ProgressDemo.update(key_event("+"), model)
      assert model.value == 100

      model = %{value: 0, auto: false}
      {model, []} = ProgressDemo.update(key_event("-"), model)
      assert model.value == 0
    end

    test "a toggles auto mode" do
      model = ProgressDemo.init(nil)
      {model, []} = ProgressDemo.update(key_event("a"), model)
      assert model.auto == true
      {model, []} = ProgressDemo.update(key_event("a"), model)
      assert model.auto == false
    end

    test "tick increments when auto is on" do
      model = %{value: 50, auto: true}
      {model, []} = ProgressDemo.update(:tick, model)
      assert model.value == 52
    end

    test "tick wraps at 100" do
      model = %{value: 100, auto: true}
      {model, []} = ProgressDemo.update(:tick, model)
      assert model.value == 0
    end

    test "subscribe returns interval when auto" do
      assert ProgressDemo.subscribe(%{auto: true}) != []
      assert ProgressDemo.subscribe(%{auto: false}) == []
    end

    test "view returns element tree" do
      model = ProgressDemo.init(nil)
      view = ProgressDemo.view(model)
      assert is_map(view)
    end
  end

  describe "ModalDemo" do
    test "init starts closed" do
      model = ModalDemo.init(nil)
      assert model.show == false
      assert model.confirmed == 0
      assert model.cancelled == 0
    end

    test "o opens modal" do
      model = ModalDemo.init(nil)
      {model, []} = ModalDemo.update(key_event("o"), model)
      assert model.show == true
    end

    test "y confirms and closes" do
      model = %{show: true, confirmed: 0, cancelled: 0}
      {model, []} = ModalDemo.update(key_event("y"), model)
      assert model.show == false
      assert model.confirmed == 1
    end

    test "n cancels and closes" do
      model = %{show: true, confirmed: 0, cancelled: 0}
      {model, []} = ModalDemo.update(key_event("n"), model)
      assert model.show == false
      assert model.cancelled == 1
    end

    test "enter confirms when open" do
      model = %{show: true, confirmed: 0, cancelled: 0}
      {model, []} = ModalDemo.update(special_key(:enter), model)
      assert model.confirmed == 1
    end

    test "escape cancels when open" do
      model = %{show: true, confirmed: 0, cancelled: 0}
      {model, []} = ModalDemo.update(special_key(:escape), model)
      assert model.cancelled == 1
    end

    test "view returns element tree" do
      model = ModalDemo.init(nil)
      view = ModalDemo.view(model)
      assert is_map(view)
    end
  end

  describe "MenuDemo" do
    test "init starts at first item" do
      model = MenuDemo.init(nil)
      assert model.selected == 0
      assert model.expanded == false
    end

    test "l moves to next menu" do
      model = MenuDemo.init(nil)
      {model, []} = MenuDemo.update(key_event("l"), model)
      assert model.selected == 1
    end

    test "h moves to previous menu" do
      model = %{selected: 2, sub_selected: 0, expanded: false}
      {model, []} = MenuDemo.update(key_event("h"), model)
      assert model.selected == 1
    end

    test "menu wraps around" do
      model = %{selected: 4, sub_selected: 0, expanded: false}
      {model, []} = MenuDemo.update(key_event("l"), model)
      assert model.selected == 0
    end

    test "enter toggles expansion" do
      model = MenuDemo.init(nil)
      {model, []} = MenuDemo.update(special_key(:enter), model)
      assert model.expanded == true
      {model, []} = MenuDemo.update(special_key(:enter), model)
      assert model.expanded == false
    end

    test "j/k navigate sub-items when expanded" do
      model = %{selected: 0, sub_selected: 0, expanded: true}
      {model, []} = MenuDemo.update(key_event("j"), model)
      assert model.sub_selected == 1
      {model, []} = MenuDemo.update(key_event("k"), model)
      assert model.sub_selected == 0
    end

    test "escape closes menu" do
      model = %{selected: 0, sub_selected: 0, expanded: true}
      {model, []} = MenuDemo.update(special_key(:escape), model)
      assert model.expanded == false
    end

    test "view returns element tree" do
      model = MenuDemo.init(nil)
      view = MenuDemo.view(model)
      assert is_map(view)
    end
  end
end
