defmodule Raxol.UI.Components.Input.SelectListTest do
  use ExUnit.Case, async: true
  import Mox

  alias Raxol.UI.Components.Input.SelectList
  alias Raxol.Core.Events.Event

  # Define mocks
  Mox.defmock(TestPlugin, for: Raxol.Core.Runtime.Plugins.Plugin)

  setup :verify_on_exit!

  # Recursive helper to extract all text content from a rendered tree
  defp extract_texts(tree) when is_list(tree),
    do: Enum.flat_map(tree, &extract_texts/1)

  defp extract_texts(%{type: :text, props: %{content: content}}), do: [content]
  defp extract_texts(%{children: children}), do: extract_texts(children)
  defp extract_texts(_), do: []

  describe "init/1" do
    test "initializes with default values when no props provided" do
      assert_raise ArgumentError, "SelectList requires :options prop", fn ->
        SelectList.init(%{})
      end
    end

    test "initializes with provided values" do
      options = [{"Option 1", :opt1}, {"Option 2", :opt2}]
      on_select = fn _ -> :selected end

      state =
        SelectList.init(%{
          options: options,
          label: "Select an option:",
          on_select: on_select,
          max_height: 10,
          enable_search: true,
          multiple: true,
          searchable_fields: [:name, :email],
          placeholder: "Type to search...",
          empty_message: "No matches found",
          show_pagination: true
        })

      assert state.options == options
      assert state.label == "Select an option:"
      assert state.on_select == on_select
      assert state.max_height == 10
      assert state.enable_search == true
      assert state.multiple == true
      assert state.searchable_fields == [:name, :email]
      assert state.placeholder == "Type to search..."
      assert state.empty_message == "No matches found"
      assert state.show_pagination == true
      assert state.focused_index == 0
      assert state.scroll_offset == 0
      assert state.search_text == ""
      assert state.filtered_options == nil
      assert state.is_filtering == false
      assert state.selected_indices == MapSet.new()
      assert state.is_search_focused == false
      assert state.page_size == 10
      assert state.current_page == 0
      assert state.has_focus == false
      assert state.visible_height == nil
      assert state.last_key_time == nil
      assert state.search_buffer == ""
      assert state.search_timer == nil
    end

    test "validates option format" do
      assert_raise ArgumentError,
                   "SelectList options must be {label, value} or {label, value, style} tuples",
                   fn ->
                     SelectList.init(%{options: ["invalid"]})
                   end

      assert_raise ArgumentError,
                   "SelectList option labels must be strings",
                   fn ->
                     SelectList.init(%{options: [{:invalid, :value}]})
                   end
    end
  end

  describe "update/2" do
    setup do
      options = [{"Option 1", :opt1}, {"Option 2", :opt2}, {"Option 3", :opt3}]

      state =
        SelectList.init(%{
          options: options,
          max_height: 10,
          show_pagination: false,
          current_page: 0,
          page_size: 10
        })

      {:ok, state: state}
    end

    test "updates props", %{state: state} do
      new_options = [{"New 1", :new1}, {"New 2", :new2}]

      {new_state, _} =
        SelectList.update(
          {:update_props,
           %{
             options: new_options,
             max_height: 10,
             show_pagination: false,
             current_page: 0,
             page_size: 10
           }},
          state
        )

      assert new_state.options == new_options
      assert new_state.filtered_options == nil
      assert new_state.is_filtering == false
      assert new_state.search_text == ""
      assert new_state.search_buffer == ""
      assert new_state.search_timer == nil
      assert new_state.focused_index == 0
      assert new_state.scroll_offset == 0
      assert new_state.current_page == 0
    end

    test "handles search", %{state: state} do
      # Initial search
      {state1, _} = SelectList.update({:search, "opt"}, state)
      assert state1.search_buffer == "opt"
      assert state1.search_timer != nil

      # Apply search after timer
      {state2, _} = SelectList.update({:apply_search, "opt"}, state1)
      assert state2.search_text == "opt"
      assert state2.search_timer == nil
      assert state2.is_filtering == true
      assert state2.filtered_options != nil
    end

    test "handles selection", %{state: state} do
      # Single selection
      state_with_on_select =
        state
        |> Map.put(:on_select, fn _ -> :selected end)
        |> Map.put(:on_change, fn _ -> :ok end)

      {state1, _} = SelectList.update({:select_option, 1}, state_with_on_select)
      assert state1.focused_index == 1

      # Multiple selection
      state2 =
        state1
        |> Map.put(:multiple, true)
        |> Map.put(:on_change, fn _ -> :ok end)

      {state3, _} = SelectList.update({:select_option, 2}, state2)
      assert MapSet.size(state3.selected_indices) == 1
      assert MapSet.member?(state3.selected_indices, 2)
    end

    test "handles pagination", %{state: state} do
      state1 = %{state | show_pagination: true, page_size: 2}
      {state2, _} = SelectList.update({:set_page, 1}, state1)
      assert state2.current_page == 1
    end

    test "handles focus", %{state: state} do
      on_focus = fn index -> send(self(), {:focused, index}) end

      state1 =
        state
        |> Map.put(:on_focus, on_focus)
        |> Map.put(:on_change, fn _ -> :ok end)

      {state2, _} = SelectList.update({:set_focus, true}, state1)
      assert state2.has_focus == true
      assert_received {:focused, 0}
    end

    test "handles search focus toggle", %{state: state} do
      state1 = %{state | enable_search: true}

      # Toggle on
      {state2, _} = SelectList.update({:toggle_search_focus}, state1)
      assert state2.is_search_focused == true
      assert state2.search_text == ""
      assert state2.search_buffer == ""
      assert state2.filtered_options == nil
      assert state2.is_filtering == false

      # Toggle off
      {state3, _} = SelectList.update({:toggle_search_focus}, state2)
      assert state3.is_search_focused == false
    end

    test "filters options by searchable field", %{state: state} do
      options = [
        {"Alice", %{email: "alice@example.com"}},
        {"Bob", %{email: "bob@work.com"}},
        {"Carol", %{email: "carol@school.edu"}},
        {"Bobby", %{email: "bobby@work.com"}}
      ]

      state =
        Raxol.UI.Components.Input.SelectList.init(%{
          options: options,
          enable_search: true,
          searchable_fields: [:email],
          max_height: 10,
          show_pagination: false,
          current_page: 0,
          page_size: 10
        })

      # Simulate entering a search term 'bob'
      {state1, _} =
        Raxol.UI.Components.Input.SelectList.update({:search, "bob"}, state)

      {state2, _} =
        Raxol.UI.Components.Input.SelectList.update(
          {:apply_search, "bob"},
          state1
        )

      # Should only match "Bob" and "Bobby" (emails contain 'bob')
      assert state2.is_filtering == true

      assert state2.filtered_options == [
               {"Bob", %{email: "bob@work.com"}},
               {"Bobby", %{email: "bobby@work.com"}}
             ]

      # Render and check only filtered options are present
      rendered = Raxol.UI.Components.Input.SelectList.render(state2, %{})

      texts = extract_texts(rendered)

      assert Enum.any?(texts, &String.contains?(&1, "Bob"))
      assert Enum.any?(texts, &String.contains?(&1, "Bobby"))
      refute Enum.any?(texts, &String.contains?(&1, "Alice"))
      refute Enum.any?(texts, &String.contains?(&1, "Carol"))
    end

    test "shows empty message when no options match filter", %{state: state} do
      options = [
        {"Alpha", :alpha},
        {"Beta", :beta},
        {"Gamma", :gamma}
      ]

      state =
        Raxol.UI.Components.Input.SelectList.init(%{
          options: options,
          enable_search: true,
          empty_message: "Nothing found!",
          max_height: 10,
          show_pagination: false,
          current_page: 0,
          page_size: 10
        })

      # Simulate entering a search term that matches nothing
      {state1, _} =
        Raxol.UI.Components.Input.SelectList.update({:search, "zzz"}, state)

      {state2, _} =
        Raxol.UI.Components.Input.SelectList.update(
          {:apply_search, "zzz"},
          state1
        )

      assert state2.is_filtering == true
      assert state2.filtered_options == []

      # Render and check the empty message is present
      rendered = Raxol.UI.Components.Input.SelectList.render(state2, %{})

      texts = extract_texts(rendered)

      assert Enum.any?(texts, &String.contains?(&1, "Nothing found!"))
      refute Enum.any?(texts, &String.contains?(&1, "Alpha"))
      refute Enum.any?(texts, &String.contains?(&1, "Beta"))
      refute Enum.any?(texts, &String.contains?(&1, "Gamma"))
    end

    test "filters options case-insensitively", %{state: state} do
      options = [
        {"Apple", :apple},
        {"banana", :banana},
        {"Grape", :grape},
        {"Pineapple", :pineapple}
      ]

      state =
        Raxol.UI.Components.Input.SelectList.init(%{
          options: options,
          enable_search: true,
          max_height: 10,
          show_pagination: false,
          current_page: 0,
          page_size: 10
        })

      # Simulate entering a lowercase search term for a capitalized label
      {state1, _} =
        Raxol.UI.Components.Input.SelectList.update({:search, "apple"}, state)

      {state2, _} =
        Raxol.UI.Components.Input.SelectList.update(
          {:apply_search, "apple"},
          state1
        )

      assert state2.is_filtering == true

      assert state2.filtered_options == [
               {"Apple", :apple},
               {"Pineapple", :pineapple}
             ]

      # Simulate entering an uppercase search term for a lowercase label
      {state3, _} =
        Raxol.UI.Components.Input.SelectList.update({:search, "BANANA"}, state)

      {state4, _} =
        Raxol.UI.Components.Input.SelectList.update(
          {:apply_search, "BANANA"},
          state3
        )

      assert state4.is_filtering == true
      assert state4.filtered_options == [{"banana", :banana}]

      # Render and check only filtered options are present for each case
      rendered2 = Raxol.UI.Components.Input.SelectList.render(state2, %{})

      texts2 = extract_texts(rendered2)

      assert Enum.any?(texts2, &String.contains?(&1, "Apple"))
      assert Enum.any?(texts2, &String.contains?(&1, "Pineapple"))
      refute Enum.any?(texts2, &String.contains?(&1, "banana"))
      refute Enum.any?(texts2, &String.contains?(&1, "Grape"))

      rendered4 = Raxol.UI.Components.Input.SelectList.render(state4, %{})

      texts4 = extract_texts(rendered4)

      assert Enum.any?(texts4, &String.contains?(&1, "banana"))
      refute Enum.any?(texts4, &String.contains?(&1, "Apple"))
      refute Enum.any?(texts4, &String.contains?(&1, "Pineapple"))
      refute Enum.any?(texts4, &String.contains?(&1, "Grape"))
    end

    test "keyboard navigation only moves through filtered options", %{
      state: state
    } do
      options = [
        {"Alpha", :alpha},
        {"Beta", :beta},
        {"Gamma", :gamma},
        {"Delta", :delta},
        {"Alphabet", :alphabet}
      ]

      state =
        Raxol.UI.Components.Input.SelectList.init(%{
          options: options,
          enable_search: true,
          max_height: 10,
          show_pagination: false,
          current_page: 0,
          page_size: 10
        })

      # Filter for options containing 'Al' (should match 'Alpha' and 'Alphabet')
      {state1, _} =
        Raxol.UI.Components.Input.SelectList.update({:search, "Al"}, state)

      {state2, _} =
        Raxol.UI.Components.Input.SelectList.update(
          {:apply_search, "Al"},
          state1
        )

      assert state2.filtered_options == [
               {"Alpha", :alpha},
               {"Alphabet", :alphabet}
             ]

      assert state2.focused_index == 0

      # Simulate down arrow (should move to second filtered option)
      state3 = %{
        state2
        | filtered_options: state2.filtered_options,
          is_filtering: true
      }

      state3 =
        Raxol.UI.Components.Input.SelectList.Navigation.update_focus_and_scroll(
          state3,
          1
        )

      assert state3.focused_index == 1

      # Simulate up arrow (should move back to first filtered option)
      state4 =
        Raxol.UI.Components.Input.SelectList.Navigation.update_focus_and_scroll(
          state3,
          0
        )

      assert state4.focused_index == 0

      # Simulate down arrow past end (should stay at last filtered option)
      state5 =
        Raxol.UI.Components.Input.SelectList.Navigation.update_focus_and_scroll(
          state4,
          2
        )

      assert state5.focused_index == 1
    end
  end

  describe "handle_event/3" do
    setup do
      options = [{"Option 1", :opt1}, {"Option 2", :opt2}, {"Option 3", :opt3}]
      state = SelectList.init(%{options: options})
      {:ok, state: state}
    end

    test "handles keyboard navigation", %{state: state} do
      # Down arrow
      event = %Event{type: :key, data: %{key: "Down"}}
      {state1, _} = SelectList.handle_event(event, %{}, state)
      assert state1.focused_index == 1

      # Up arrow
      event = %Event{type: :key, data: %{key: "Up"}}
      {state2, _} = SelectList.handle_event(event, %{}, state1)
      assert state2.focused_index == 0

      # Page down
      event = %Event{type: :key, data: %{key: "PageDown"}}
      {state3, _} = SelectList.handle_event(event, %{}, state)
      assert state3.focused_index == 2

      # Page up
      event = %Event{type: :key, data: %{key: "PageUp"}}
      {state4, _} = SelectList.handle_event(event, %{}, state3)
      assert state4.focused_index == 0

      # Home
      event = %Event{type: :key, data: %{key: "Home"}}
      {state5, _} = SelectList.handle_event(event, %{}, state3)
      assert state5.focused_index == 0

      # End
      event = %Event{type: :key, data: %{key: "End"}}
      {state6, _} = SelectList.handle_event(event, %{}, state)
      assert state6.focused_index == 2
    end

    test "handles selection", %{state: state} do
      on_select = fn value -> send(self(), {:selected, value}) end

      state1 =
        state
        |> Map.put(:on_select, on_select)
        |> Map.put(:on_change, fn _ -> :ok end)

      # Enter key
      event = %Event{type: :key, data: %{key: "Enter"}}
      {state2, _} = SelectList.handle_event(event, %{}, state1)
      assert_received {:selected, :opt1}
      assert state2.focused_index == 0

      # Multiple selection
      state3 = %{state2 | multiple: true}
      event = %Event{type: :key, data: %{key: "Space"}}
      {state4, _} = SelectList.handle_event(event, %{}, state3)
      assert MapSet.size(state4.selected_indices) == 1
      assert MapSet.member?(state4.selected_indices, 0)
    end

    test "handles search", %{state: state} do
      state1 = %{state | enable_search: true, is_search_focused: true}

      # Tab to toggle search focus
      event = %Event{type: :key, data: %{key: "Tab"}}
      {state2, _} = SelectList.handle_event(event, %{}, state1)
      assert state2.is_search_focused == false

      # Character input
      event = %Event{type: :key, data: %{key: "a"}}
      {state3, _} = SelectList.handle_event(event, %{}, state1)
      assert state3.search_buffer == "a"
      assert state3.search_timer != nil

      # Backspace
      event = %Event{type: :key, data: %{key: "Backspace"}}
      {state4, _} = SelectList.handle_event(event, %{}, state3)
      assert state4.search_buffer == ""
    end

    test "handles mouse click", %{state: state} do
      # Click on search box
      event = %Event{type: :mouse, data: %{x: 1, y: 1}}
      state1 = %{state | enable_search: true}
      {state2, _} = SelectList.handle_event(event, %{}, state1)
      assert state2.is_search_focused == true

      # Click on option
      event = %Event{type: :mouse, data: %{x: 1, y: 3}}
      {state3, _} = SelectList.handle_event(event, %{}, state1)
      assert state3.focused_index == 1
    end

    test "handles focus events", %{state: state} do
      # Focus
      event = %Event{type: :focus}
      {state1, _} = SelectList.handle_event(event, %{}, state)
      assert state1.has_focus == true

      # Blur
      event = %Event{type: :blur}
      {state2, _} = SelectList.handle_event(event, %{}, state1)
      assert state2.has_focus == false
    end

    test "handles resize events", %{state: state} do
      event = %Event{type: :resize, data: %{width: 80, height: 24}}
      {state1, _} = SelectList.handle_event(event, %{}, state)
      assert state1.visible_height == 24
    end
  end

  describe "theming, style, and lifecycle" do
    test "applies style and theme props to container and options" do
      options = [
        {"Styled Option", :styled, %{color: "#990000"}},
        {"Normal Option", :normal}
      ]

      theme = %{
        container: %{border: "2px solid #00ff00"},
        option: %{font_weight: "bold"},
        selected_color: "#123456",
        focused_bg: "#abcdef"
      }

      style = %{
        container: %{border_radius: "8px"},
        option: %{font_style: "italic"},
        selected_color: "#654321"
      }

      state =
        Raxol.UI.Components.Input.SelectList.init(%{
          options: options,
          theme: theme,
          style: style,
          max_height: 10,
          show_pagination: false,
          current_page: 0,
          page_size: 10,
          on_change: fn _ -> :ok end
        })

      rendered = Raxol.UI.Components.Input.SelectList.render(state, %{})
      # Container should have merged style
      container = Enum.find(rendered, &(&1[:type] == :container))
      assert container.props.style.border == "2px solid #00ff00"
      assert container.props.style.border_radius == "8px"
      # First option should have per-option style merged
      [first_option, _second_option] = container.children

      assert (first_option.children
              |> hd
              |> Map.get(:props)
              |> Map.get(:style))[:color] == "#990000"

      # Option style from theme and style
      assert first_option.props.style.font_weight == "bold"
      assert first_option.props.style.font_style == "italic"
      # Selected color from style overrides theme
      state = %{state | selected_indices: MapSet.new([0])}
      rendered = Raxol.UI.Components.Input.SelectList.render(state, %{})
      container = Enum.find(rendered, &(&1[:type] == :container))
      first_option = hd(container.children)

      text_style =
        first_option.children |> hd |> Map.get(:props) |> Map.get(:style)

      assert text_style.color == "#654321"
      # Focused background from theme
      state = %{state | focused_index: 0}
      rendered = Raxol.UI.Components.Input.SelectList.render(state, %{})
      container = Enum.find(rendered, &(&1[:type] == :container))
      first_option = hd(container.children)
      assert first_option.props.style.background_color == "#abcdef"
    end

    test "mount/1 and unmount/1 return state unchanged" do
      options = [{"A", 1}]
      state = Raxol.UI.Components.Input.SelectList.init(%{options: options})
      assert Raxol.UI.Components.Input.SelectList.mount(state) == state
      assert Raxol.UI.Components.Input.SelectList.unmount(state) == state
    end

    test "responds to max_height prop dynamically" do
      options = [{"A", 1}, {"B", 2}]

      state =
        Raxol.UI.Components.Input.SelectList.init(%{
          options: options,
          max_height: 5,
          on_change: fn _ -> :ok end
        })

      rendered = Raxol.UI.Components.Input.SelectList.render(state, %{})
      container = Enum.find(rendered, &(&1[:type] == :container))
      assert container.props.style.max_height == 5
      # Update max_height
      {state2, _} =
        Raxol.UI.Components.Input.SelectList.update(
          {:update_props, %{max_height: 10, options: options}},
          state
        )

      rendered2 = Raxol.UI.Components.Input.SelectList.render(state2, %{})
      container2 = Enum.find(rendered2, &(&1[:type] == :container))
      assert container2.props.style.max_height == 10
    end
  end
end
