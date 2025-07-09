defmodule Raxol.Core.UXRefinementKeyboardTest do
  use ExUnit.Case, async: false
  import Mox
  import Raxol.Guards
  require Raxol.Core.Runtime.Log

  # Aliases for mocks will be used directly, e.g., Raxol.Mocks.AccessibilityMock
  # alias Raxol.Core.Accessibility # Removed
  alias Raxol.Core.Accessibility.Mock, as: Raxol.Mocks.AccessibilityMock
  alias Raxol.Core.Events.Manager, as: EventManager
  # alias Raxol.Core.FocusManager # Removed
  # alias Raxol.Core.KeyboardShortcuts # Removed
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.Events.Event

  # alias Raxol.Core.UserPreferences # Not directly used in :meck refactor, keep if other tests need

  # Define the mock for KeyboardShortcutsBehaviour (already present)
  # Mox.defmock(Raxol.Mocks.KeyboardShortcutsMock, for: Raxol.Core.KeyboardShortcutsBehaviour)
  # Mocks for Accessibility and FocusManager are defined in test/support/mocks.ex

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    # Initialize event manager for tests
    EventManager.init()

    on_exit(fn ->
      # Clean up any enabled features
      [
        :keyboard_shortcuts,
        :events,
        :focus_management,
        :accessibility,
        :hints
      ]
      |> Enum.each(fn feature ->
        if UXRefinement.feature_enabled?(feature) do
          UXRefinement.disable_feature(feature)
        end
      end)

      # Clean up EventManager
      if Process.whereis(EventManager), do: EventManager.cleanup()
    end)

    :ok
  end

  describe "keyboard shortcuts integration" do
    test "enable_feature/1 initializes keyboard shortcuts" do
      expect(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)

      assert :ok = UXRefinement.enable_feature(:keyboard_shortcuts)

      assert UXRefinement.feature_enabled?(:keyboard_shortcuts)
      assert UXRefinement.feature_enabled?(:events)
    end

    test "disable_feature/1 cleans up keyboard shortcuts" do
      stub(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      UXRefinement.enable_feature(:keyboard_shortcuts)

      expect(Raxol.Mocks.KeyboardShortcutsMock, :cleanup, fn -> :ok end)
      assert :ok = UXRefinement.disable_feature(:keyboard_shortcuts)
      refute UXRefinement.feature_enabled?(:keyboard_shortcuts)
    end

    test "UXRefinement.set_shortcuts_context/1 delegates to KeyboardShortcutsMock" do
      stub(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      UXRefinement.enable_feature(:keyboard_shortcuts)

      test_context = :editor

      expect(Raxol.Mocks.KeyboardShortcutsMock, :set_context, fn context ->
        assert context == test_context
        :ok
      end)

      assert UXRefinement.set_shortcuts_context(test_context) == :ok
    end

    test "UXRefinement.get_available_shortcuts/1 delegates to KeyboardShortcutsMock" do
      stub(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      UXRefinement.enable_feature(:keyboard_shortcuts)

      expected_shortcuts_data = %{some: :shortcuts}

      # Test with explicit context
      expect(
        Raxol.Mocks.KeyboardShortcutsMock,
        :get_shortcuts_for_context,
        fn context ->
          assert context == :editor
          expected_shortcuts_data
        end
      )

      assert UXRefinement.get_available_shortcuts(:editor) ==
               expected_shortcuts_data

      # Test with nil context (default argument)
      expect(
        Raxol.Mocks.KeyboardShortcutsMock,
        :get_shortcuts_for_context,
        fn context ->
          assert context == nil
          expected_shortcuts_data
        end
      )

      assert UXRefinement.get_available_shortcuts() == expected_shortcuts_data
    end

    test "UXRefinement.show_shortcuts_help/0 delegates to KeyboardShortcutsMock" do
      stub(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      UXRefinement.enable_feature(:keyboard_shortcuts, [], nil)

      expect(
        Raxol.Mocks.KeyboardShortcutsMock,
        :show_shortcuts_help,
        fn _user_prefs_pid_or_name ->
          :ok
        end
      )

      assert UXRefinement.show_shortcuts_help(nil) == :ok
    end
  end

  describe "component shortcuts integration" do
    test "UXRefinement.register_accessibility_metadata/2 calls Accessibility.register_element_metadata" do
      expect(Raxol.Mocks.AccessibilityMock, :enable, fn _, _ -> :ok end)

      stub(Raxol.Mocks.FocusManagerMock, :register_focus_change_handler, fn _ ->
        :ok
      end)

      UXRefinement.enable_feature(:accessibility)

      metadata = %{label: "Search", hint: "Press Enter to search"}
      component_id = "search_button"

      expect(
        Raxol.Mocks.AccessibilityMock,
        :register_element_metadata,
        fn id, meta ->
          assert id == component_id
          assert meta == metadata
          :ok
        end
      )

      assert UXRefinement.register_accessibility_metadata(
               component_id,
               metadata
             ) == :ok
    end

    test "register_component_hint/2 registers shortcuts via KeyboardShortcuts" do
      stub(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:hints)
      UXRefinement.enable_feature(:focus_management)

      hint_info = %{
        basic: "Search for content",
        detailed: "Search for content in the application",
        shortcuts: [
          {"Enter", "Execute search"},
          {"Alt+S", "Focus search"}
        ]
      }

      expect(
        Raxol.Mocks.KeyboardShortcutsMock,
        :register_shortcut,
        2,
        fn shortcut_key, name, _callback, opts ->
          case shortcut_key do
            "Enter" ->
              assert name == "search_button_shortcut_Enter"
              assert Keyword.get(opts, :description) == "Execute search"
              assert Keyword.get(opts, :context) == "search_button"

            "Alt+S" ->
              assert name == "search_button_shortcut_Alt+S"
              assert Keyword.get(opts, :description) == "Focus search"
              assert Keyword.get(opts, :context) == "search_button"

            _ ->
              flunk("Unexpected shortcut_key: #{inspect(shortcut_key)}")
          end

          :ok
        end
      )

      UXRefinement.register_component_hint("search_button", hint_info)
    end
  end

  describe "shortcut handling specific to UXRefinement callbacks" do
    test "shortcut callback from register_component_hint triggers FocusManager.set_focus" do
      stub(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      stub(Raxol.Mocks.AccessibilityMock, :enable, fn _, _ -> :ok end)

      stub(Raxol.Mocks.FocusManagerMock, :register_focus_change_handler, fn _ ->
        :ok
      end)

      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:focus_management)
      UXRefinement.enable_feature(:accessibility)

      callback_ref = System.unique_integer([:positive])
      Process.put(callback_ref, nil)

      stub(
        Raxol.Mocks.KeyboardShortcutsMock,
        :register_shortcut,
        fn _key, _name, cb_fun, _opts ->
          Process.put(callback_ref, cb_fun)
          :ok
        end
      )

      component_id = "search_button_focus"

      UXRefinement.register_component_hint(component_id, %{
        shortcuts: [{"Alt+F", "Focus This Component"}]
      })

      shortcut_callback = Process.get(callback_ref)

      if !function?(shortcut_callback, 0) do
        flunk(
          "Shortcut callback was not captured. KeyboardShortcuts.register_shortcut mock might not have been called correctly."
        )
      end

      expect(Raxol.Mocks.FocusManagerMock, :set_focus, fn id ->
        assert id == component_id
        :ok
      end)

      shortcut_callback.()
    end
  end

  describe "events integration" do
    test "keyboard events are handled via KeyboardShortcuts and EventManager" do
      # UXRefinement.enable_feature(:events) MUST be first
      # Calls EventManager.init()
      UXRefinement.enable_feature(:events)

      # Manually register the mock handler AFTER EventManager is initialized
      EventManager.register_handler(
        :keyboard_event,
        Raxol.Mocks.KeyboardShortcutsMock,
        :handle_keyboard_event
      )

      # Stub KeyboardShortcutsMock.init to be a simple :ok for this test's purpose,
      # as we are handling its usual registration task manually above.
      Mox.stub(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      # Enable the feature in UXRefinement
      UXRefinement.enable_feature(:keyboard_shortcuts)

      context_pid = self()

      event_handled_callback = fn ->
        send(context_pid, :handled_shortcut_event)
      end

      Mox.expect(
        Raxol.Mocks.KeyboardShortcutsMock,
        :handle_keyboard_event,
        fn {event_name, dispatched_payload} ->
          assert event_name == :keyboard_event
          assert dispatched_payload.type == :key
          assert dispatched_payload.data == %{key: "t", modifiers: [:ctrl]}
          event_handled_callback.()
          :ok
        end
      )

      event_to_dispatch = %Event{
        type: :key,
        data: %{key: "t", modifiers: [:ctrl]}
      }

      EventManager.dispatch({:keyboard_event, event_to_dispatch})

      # Wait for event to be handled with a timeout
      assert_receive :handled_shortcut_event, 100
      Mox.verify!(Raxol.Mocks.KeyboardShortcutsMock)
    end
  end
end
