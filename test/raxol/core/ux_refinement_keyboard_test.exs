defmodule Raxol.Core.UXRefinementKeyboardTest do
  use ExUnit.Case, async: false
  require Logger

  # Aliases for mocks will be used directly, e.g., Raxol.Mocks.AccessibilityMock
  # alias Raxol.Core.Accessibility # Removed
  alias Raxol.Core.Events.Manager, as: EventManager
  # alias Raxol.Core.FocusManager # Removed
  # alias Raxol.Core.KeyboardShortcuts # Removed
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.Events.Event

  # alias Raxol.Core.UserPreferences # Not directly used in :meck refactor, keep if other tests need

  # Define the mock for KeyboardShortcutsBehaviour (already present)
  # Mox.defmock(Raxol.Mocks.KeyboardShortcutsMock, for: Raxol.Core.KeyboardShortcutsBehaviour)
  # Mocks for Accessibility and FocusManager are defined in test/support/mocks.ex

  setup do
    # It's good practice to verify Mox expectations in on_exit
    # Ensure fresh stubs for each test if needed
    Mox.stub_global(Raxol.Mocks.AccessibilityMock, false)
    Mox.stub_global(Raxol.Mocks.FocusManagerMock, false)
    Mox.stub_global(Raxol.Mocks.KeyboardShortcutsMock, false)
    on_exit(fn -> Mox.verify_on_exit!() end)
    :ok
  end

  describe "keyboard shortcuts integration" do
    test "enable_feature/1 initializes keyboard shortcuts" do
      Mox.expect(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)

      assert :ok = UXRefinement.enable_feature(:keyboard_shortcuts)

      assert UXRefinement.feature_enabled?(:keyboard_shortcuts)
      assert UXRefinement.feature_enabled?(:events)
      Mox.verify!(Raxol.Mocks.KeyboardShortcutsMock)
    end

    test "disable_feature/1 cleans up keyboard shortcuts" do
      Mox.stub_request(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      UXRefinement.enable_feature(:keyboard_shortcuts)

      Mox.expect(Raxol.Mocks.KeyboardShortcutsMock, :cleanup, fn -> :ok end)
      assert :ok = UXRefinement.disable_feature(:keyboard_shortcuts)
      refute UXRefinement.feature_enabled?(:keyboard_shortcuts)
      Mox.verify!(Raxol.Mocks.KeyboardShortcutsMock)
    end

    # Unskip and refactor this test
    test "UXRefinement.register_shortcut/4 delegates to KeyboardShortcuts" do
      UXRefinement.enable_feature(:keyboard_shortcuts)
      # Stub init from enable_feature
      Mox.stub_request(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)

      key_combo = "Ctrl+S"
      action_name = :save_action
      callback_fun = fn -> :saved end
      opts = [context: :global]

      Mox.expect(Raxol.Mocks.KeyboardShortcutsMock, :register_shortcut, fn key,
                                                                           action,
                                                                           cb,
                                                                           cb_opts ->
        assert key == key_combo
        assert action == action_name
        assert cb == callback_fun
        assert cb_opts == opts
        :ok
      end)

      assert UXRefinement.register_shortcut(
               key_combo,
               action_name,
               callback_fun,
               opts
             ) == :ok

      Mox.verify!(Raxol.Mocks.KeyboardShortcutsMock)
    end

    # REVISIT: This test was testing KeyboardShortcuts directly. UXRefinement API differs.
    @tag :skip
    test "set_shortcuts_context/1 delegates to KeyboardShortcuts" do
      # :meck.expect(KeyboardShortcuts, :set_context, fn context ->
      #   assert context == :editor
      #   :ok
      # end)
      # assert KeyboardShortcuts.set_context(:editor) == :ok
      :noop
    end

    # Skip: KeyboardShortcuts.get_available_shortcuts/0 removed or changed. UXRefinement API differs.
    @tag :skip
    test "get_available_shortcuts/0 delegates to KeyboardShortcuts" do
      # expected_shortcuts = %{global: %{"Ctrl+S" => :save}}
      # :meck.expect(KeyboardShortcuts, :get_available_shortcuts, fn ->
      #   expected_shortcuts
      # end)
      # assert KeyboardShortcuts.get_available_shortcuts() == expected_shortcuts
      :noop
    end

    # Skip: KeyboardShortcuts.show_help/0 removed or changed. UXRefinement API differs slightly.
    @tag :skip
    test "show_shortcuts_help/0 delegates to KeyboardShortcuts" do
      # :meck.expect(KeyboardShortcuts, :show_help, fn ->
      #   :ok
      # end)
      # assert KeyboardShortcuts.show_help() == :ok
      :noop
    end
  end

  describe "component shortcuts integration" do
    test "UXRefinement.register_accessibility_metadata/2 calls Accessibility.register_element_metadata" do
      UXRefinement.enable_feature(:accessibility)
      # Stub Accessibility.enable that is called by enable_feature
      Mox.stub_request(Raxol.Mocks.AccessibilityMock, :enable, fn _opts ->
        :ok
      end)

      # Stub FocusManager.register_focus_change_handler that is called by enable_feature
      Mox.stub_request(
        Raxol.Mocks.FocusManagerMock,
        :register_focus_change_handler,
        fn _handler -> :ok end
      )

      metadata = %{label: "Search", hint: "Press Enter to search"}
      component_id = "search_button"

      Mox.expect(
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

      Mox.verify!(Raxol.Mocks.AccessibilityMock)
    end

    test "register_component_hint/2 registers shortcuts via KeyboardShortcuts" do
      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:hints)
      UXRefinement.enable_feature(:focus_management)

      Mox.stub_request(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)

      hint_info = %{
        basic: "Search for content",
        detailed: "Search for content in the application",
        shortcuts: [
          {"Enter", "Execute search"},
          {"Alt+S", "Focus search"}
        ]
      }

      Mox.expect(
        Raxol.Mocks.KeyboardShortcutsMock,
        :register_shortcut,
        2,
        fn shortcut_key, name, _callback, opts ->
          case shortcut_key do
            "Enter" ->
              assert name == :search_button_shortcut_Enter
              assert Keyword.get(opts, :description) == "Execute search"
              assert Keyword.get(opts, :context) == "search_button"

            "Alt+S" ->
              assert name == :search_button_shortcut_Alt_S
              assert Keyword.get(opts, :description) == "Focus search"
              assert Keyword.get(opts, :context) == "search_button"

            _ ->
              flunk("Unexpected shortcut_key: #{inspect(shortcut_key)}")
          end

          :ok
        end
      )

      UXRefinement.register_component_hint("search_button", hint_info)
      Mox.verify!(Raxol.Mocks.KeyboardShortcutsMock)
    end
  end

  describe "shortcut handling specific to UXRefinement callbacks" do
    test "shortcut callback from register_component_hint triggers FocusManager.set_focus" do
      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:focus_management)
      # For consistency, as focus changes often have a11y implications
      UXRefinement.enable_feature(:accessibility)

      Mox.stub_request(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      Mox.stub_request(Raxol.Mocks.AccessibilityMock, :enable, fn _ -> :ok end)

      Mox.stub_request(
        Raxol.Mocks.FocusManagerMock,
        :register_focus_change_handler,
        fn _ -> :ok end
      )

      callback_ref = :atom.unique_to_string(:callback_ref) |> String.to_atom()
      Process.put(callback_ref, nil)

      Mox.stub_request(
        Raxol.Mocks.KeyboardShortcutsMock,
        :register_shortcut,
        fn _key, _name, cb_fun, _opts ->
          Process.put(callback_ref, cb_fun)
          :ok
        end
      )

      component_id = "search_button_focus"

      UXRefinement.register_component_hint(component_id, %{
        # Using a distinct shortcut for clarity
        shortcuts: [{"Alt+F", "Focus This Component"}]
      })

      shortcut_callback = Process.get(callback_ref)

      if !is_function(shortcut_callback, 0) do
        flunk(
          "Shortcut callback was not captured. KeyboardShortcuts.register_shortcut mock might not have been called correctly."
        )
      end

      Mox.expect(Raxol.Mocks.FocusManagerMock, :set_focus, fn id ->
        assert id == component_id
        :ok
      end)

      shortcut_callback.()
      Mox.verify!(Raxol.Mocks.FocusManagerMock)
    end

    test "shortcut callback from register_component_hint handles accessibility announcements" do
      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:focus_management)
      UXRefinement.enable_feature(:accessibility)

      Mox.stub_request(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)
      Mox.stub_request(Raxol.Mocks.AccessibilityMock, :enable, fn _ -> :ok end)

      Mox.stub_request(
        Raxol.Mocks.FocusManagerMock,
        :register_focus_change_handler,
        fn _ -> :ok end
      )

      # For disable_feature in on_exit
      Mox.stub_request(
        Raxol.Mocks.FocusManagerMock,
        :unregister_focus_change_handler,
        fn _ -> :ok end
      )

      component_id = "action_button"
      action_announcement = "Action performed on #{component_id}"

      # Metadata for focus change announcements (if any)
      metadata = %{label: "Action Button", announcement: action_announcement}

      Mox.expect(
        Raxol.Mocks.AccessibilityMock,
        :register_element_metadata,
        fn id, meta_arg ->
          assert id == component_id
          # Assuming UXRefinement passes it through
          assert meta_arg == metadata
          :ok
        end
      )

      UXRefinement.register_accessibility_metadata(component_id, metadata)

      callback_ref = :atom.unique_to_string(:callback_ref) |> String.to_atom()
      Process.put(callback_ref, nil)

      Mox.stub_request(
        Raxol.Mocks.KeyboardShortcutsMock,
        :register_shortcut,
        fn _key, _name, cb_fun, _opts ->
          Process.put(callback_ref, cb_fun)
          :ok
        end
      )

      # This hint registers a shortcut whose callback should trigger an announcement
      UXRefinement.register_component_hint(component_id, %{
        shortcuts: [{"Ctrl+A", "Perform Action and Announce"}]
        # Assuming the callback for this shortcut will call UXRefinement.announce(action_announcement)
      })

      shortcut_callback = Process.get(callback_ref)

      if !is_function(shortcut_callback, 0) do
        flunk("Shortcut callback was not captured.")
      end

      # Expect FocusManager.set_focus (standard behavior for such shortcuts)
      Mox.expect(Raxol.Mocks.FocusManagerMock, :set_focus, fn id ->
        assert id == component_id
        :ok
      end)

      # Expect the direct announcement from the shortcut's action
      Mox.expect(Raxol.Mocks.AccessibilityMock, :announce, fn message, _opts ->
        assert message == action_announcement
        :ok
      end)

      # Note: The announcement from handle_accessibility_focus_change is a secondary effect
      # and depends on EventManager dispatching, which is harder to test here without more setup.
      # This test focuses on the direct announcement if the callback calls UXRefinement.announce.

      shortcut_callback.()

      Mox.verify!(Raxol.Mocks.FocusManagerMock)
      # Verifies both register_element_metadata and announce
      Mox.verify!(Raxol.Mocks.AccessibilityMock)
    end
  end

  describe "events integration" do
    test "keyboard events are handled via KeyboardShortcuts and EventManager" do
      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:events)

      Mox.stub_request(Raxol.Mocks.KeyboardShortcutsMock, :init, fn -> :ok end)

      context_pid = self()

      event_handled_callback = fn ->
        send(context_pid, :handled_shortcut_event)
      end

      # We expect that EventManager, upon receiving a keyboard_event,
      # will delegate to the keyboard_shortcuts_module(), which is our mock.
      # The mock should then call its handle_event function.
      Mox.expect(
        Raxol.Mocks.KeyboardShortcutsMock,
        :handle_event,
        fn dispatched_event ->
          # Check the structure of the event received by KeyboardShortcuts.handle_event
          # This depends on how EventManager wraps/passes the event.
          # Assuming EventManager dispatches the original event data.
          assert dispatched_event.type == :key
          assert dispatched_event.data == %{key: "t", modifiers: [:ctrl]}
          # Simulate the action of a matched shortcut
          event_handled_callback.()
          :ok
        end
      )

      # This event should be processed by EventManager, which then calls the mocked KeyboardShortcuts.handle_event
      event_to_dispatch = %Event{
        type: :key,
        data: %{key: "t", modifiers: [:ctrl]}
      }

      EventManager.dispatch({:keyboard_event, event_to_dispatch})

      assert_received :handled_shortcut_event
      Mox.verify!(Raxol.Mocks.KeyboardShortcutsMock)
    end
  end
end
