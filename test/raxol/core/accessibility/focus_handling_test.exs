defmodule Raxol.Core.Accessibility.FocusHandlingTest do
  @moduledoc """
  Tests for the focus handling system, including element focus tracking,
  announcement generation, and screen reader compatibility.
  """
  use ExUnit.Case, async: false
  import Mox

  alias Raxol.Core.Accessibility
  alias Raxol.Core.UserPreferences
  alias Raxol.Core.AccessibilityTestHelper, as: Helper

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Raxol.Core.I18n.init()
    :ok
  end

  describe "Focus Change Handling" do
    setup do
      prefs_name =
        String.to_atom(
          "user_prefs_focus_change_" <>
            Integer.to_string(System.unique_integer([:positive]))
        )

      {:ok, context} = Helper.setup_test_preferences_with_events(prefs_name)
      context
    end

    test "handle_focus_change/2 announces element when it receives focus", %{
      pref_pid: pref_pid
    } do
      Accessibility.register_element_metadata("search_button", %{
        label: "Search"
      })

      Accessibility.clear_announcements()
      Raxol.Core.Events.Manager.dispatch({:focus_change, nil, "search_button"})
      assert Accessibility.get_next_announcement(pref_pid) == "Search"
    end

    test "handle_focus_change/2 does nothing when element has no announcement",
         %{
           pref_pid: pref_pid
         } do
      Accessibility.clear_announcements()

      Raxol.Core.Events.Manager.dispatch(
        {:focus_change, nil, "unknown_element"}
      )

      assert Accessibility.get_next_announcement(pref_pid) == nil
    end

    test "handle_focus_change/2 announces multiple elements correctly", %{
      pref_pid: pref_pid
    } do
      Helper.register_test_elements()
      Accessibility.clear_announcements()

      Raxol.Core.Events.Manager.dispatch({:focus_change, nil, "search_button"})

      Raxol.Core.Events.Manager.dispatch(
        {:focus_change, "search_button", "text_input"}
      )

      Raxol.Core.Events.Manager.dispatch(
        {:focus_change, "text_input", "submit_button"}
      )

      assert Accessibility.get_next_announcement(pref_pid) == "Search"
      assert Accessibility.get_next_announcement(pref_pid) == "Username"
      assert Accessibility.get_next_announcement(pref_pid) == "Submit Form"
      assert Accessibility.get_next_announcement(pref_pid) == nil
    end

    test "handle_focus_change/2 announces correctly after multiple focus changes",
         %{
           pref_pid: pref_pid
         } do
      Accessibility.register_element_metadata("el1", %{label: "Element One"})
      Accessibility.register_element_metadata("el2", %{label: "Element Two"})

      Accessibility.clear_announcements()

      Raxol.Core.Events.Manager.dispatch({:focus_change, nil, "el1"})
      Raxol.Core.Events.Manager.dispatch({:focus_change, "el1", "el2"})

      assert Accessibility.get_next_announcement(pref_pid) == "Element One"
      assert Accessibility.get_next_announcement(pref_pid) == "Element Two"
      assert Accessibility.get_next_announcement(pref_pid) == nil
    end

    test "handle_focus_change/2 announces element labels correctly", %{
      pref_pid: pref_pid
    } do
      Accessibility.register_element_metadata("button1", %{label: "OK"})
      Accessibility.register_element_metadata("input_field", %{label: "Name"})

      Accessibility.register_element_metadata("link_about", %{label: "About Us"})

      Accessibility.clear_announcements()
      Raxol.Core.Events.Manager.dispatch({:focus_change, nil, "button1"})

      assert Accessibility.get_next_announcement(pref_pid) == "OK"
      assert Accessibility.get_next_announcement(pref_pid) == nil
    end

    test "get_element_label/1 retrieves correct label", %{
      pref_pid: pref_pid
    } do
      Accessibility.register_element_metadata("my_element", %{
        label: "My Special Element"
      })

      Accessibility.clear_announcements()
      Raxol.Core.Events.Manager.dispatch({:focus_change, nil, "my_element"})

      assert Accessibility.get_next_announcement(pref_pid) ==
               "My Special Element"

      assert Accessibility.get_next_announcement(pref_pid) == nil
    end

    test "get_element_label/1 handles missing labels and metadata gracefully",
         %{
           pref_pid: pref_pid
         } do
      Accessibility.register_element_metadata("no_label_element", %{})
      Accessibility.clear_announcements()

      Raxol.Core.Events.Manager.dispatch(
        {:focus_change, nil, "no_label_element"}
      )

      assert Accessibility.get_next_announcement(pref_pid) == nil

      Accessibility.clear_announcements()

      Raxol.Core.Events.Manager.dispatch(
        {:focus_change, nil, "completely_unknown_element"}
      )

      assert Accessibility.get_next_announcement(pref_pid) == nil
    end

    test "handle_focus_change/2 does not announce if screen reader is disabled",
         %{
           pref_pid: pref_pid
         } do
      UserPreferences.set(Helper.pref_key(:screen_reader), false, pref_pid)

      Accessibility.register_element_metadata("button_no_speak", %{
        label: "Important Button"
      })

      Accessibility.clear_announcements()

      Raxol.Core.Events.Manager.dispatch(
        {:focus_change, nil, "button_no_speak"}
      )

      assert Accessibility.get_next_announcement(pref_pid) == nil
    end
  end
end

ExUnit.start()
Code.require_file("../accessibility_test_helper.exs", __DIR__)
