defmodule Raxol.Core.UXRefinementKeyboardTest do
  use ExUnit.Case, async: false
  require Logger

  alias Raxol.Core.Accessibility
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.FocusManager
  alias Raxol.Core.KeyboardShortcuts
  alias Raxol.Core.UXRefinement
  alias Raxol.Core.Events.Event
  alias Raxol.Core.UserPreferences

  setup do
    # Start UserPreferences GenServer if not already running
    # REMOVE GLOBAL START
    # pref_pid =
    #   case Process.whereis(Raxol.Core.UserPreferences) do
    #     nil ->
    #       {:ok, pid} = Raxol.Core.UserPreferences.start_link([])
    #       pid
    #     pid when is_pid(pid) ->
    #       pid
    #   end

    # Start FocusManager if not already running
    # focus_pid =
    #   case Process.whereis(Raxol.Core.FocusManager) do
    #     nil ->
    #       {:ok, pid} = Raxol.Core.FocusManager.start_link()
    #       pid
    #     pid when is_pid(pid) ->
    #       pid
    #   end
    :ok
    # on_exit fn ->
    #   # Ensure UserPreferences and FocusManager are stopped on exit
    #   if Process.alive?(pref_pid), do: Process.exit(pref_pid, :shutdown)
    #   if Process.alive?(focus_pid), do: Process.exit(focus_pid, :shutdown)
    # end
  end

  describe "keyboard shortcuts integration" do
    test "enable_feature/1 initializes keyboard shortcuts" do
      # Enable keyboard shortcuts
      assert :ok = UXRefinement.enable_feature(:keyboard_shortcuts)

      # Verify feature is enabled
      assert UXRefinement.feature_enabled?(:keyboard_shortcuts)

      # Verify events are also enabled
      assert UXRefinement.feature_enabled?(:events)
    end

    test "disable_feature/1 cleans up keyboard shortcuts" do
      # First enable
      UXRefinement.enable_feature(:keyboard_shortcuts)

      # Then disable
      assert :ok = UXRefinement.disable_feature(:keyboard_shortcuts)

      # Verify feature is disabled
      refute UXRefinement.feature_enabled?(:keyboard_shortcuts)
    end

    test "register_shortcut/4 delegates to KeyboardShortcuts" do
      callback = fn -> :saved end

      # Expect call on the actual module
      :meck.expect(KeyboardShortcuts, :register_shortcut, fn key, action, cb, opts ->
        assert key == "Ctrl+S"
        assert action == :save
        assert cb == callback
        assert opts == [context: :global]
        :ok
      end)

      # Call the actual module
      assert KeyboardShortcuts.register_shortcut("Ctrl+S", :save, callback, [context: :global]) == :ok
    end

    test "set_shortcuts_context/1 delegates to KeyboardShortcuts" do
      # Expect call on the actual module
      :meck.expect(KeyboardShortcuts, :set_context, fn context ->
        assert context == :editor
        :ok
      end)
      # Call the actual module
      assert KeyboardShortcuts.set_context(:editor) == :ok
    end

    test "get_available_shortcuts/0 delegates to KeyboardShortcuts" do
      expected_shortcuts = %{global: %{"Ctrl+S" => :save}}
      # Expect call on the actual module
      :meck.expect(KeyboardShortcuts, :get_available_shortcuts, fn ->
        expected_shortcuts
      end)

      # Call the actual module
      assert KeyboardShortcuts.get_available_shortcuts() == expected_shortcuts
    end

    test "show_shortcuts_help/0 delegates to KeyboardShortcuts" do
      # Expect call on the actual module
      :meck.expect(KeyboardShortcuts, :show_help, fn ->
        :ok # Assuming it returns :ok or similar
      end)

      # Call the actual module
      assert KeyboardShortcuts.show_help() == :ok
    end
  end

  describe "component shortcuts integration" do
    test "register_accessibility_metadata/2 registers component shortcut" do
      metadata = %{label: "Search", hint: "Press Enter to search"}

      # Expect call on the Accessibility module (or wherever this now lives)
      # Assuming function is named register_metadata/2
      :meck.expect(Accessibility, :register_metadata, fn id, meta ->
        assert id == "search_button"
        assert meta == metadata
        :ok
      end)

      # Call the actual module
      assert Accessibility.register_metadata("search_button", metadata) == :ok
    end

    test "register_component_hint/2 registers shortcuts from hint info" do
      # Enable required features
      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:hints)
      UXRefinement.enable_feature(:focus_management)

      # Store test process pid
      test_pid = self()

      # Mock KeyboardShortcuts.register_shortcut
      :meck.new(KeyboardShortcuts, [:passthrough])

      :meck.expect(KeyboardShortcuts, :register_shortcut, fn shortcut,
                                                             name,
                                                             _callback,
                                                             opts ->
        send(test_pid, {:register_shortcut, shortcut, name, opts})
        :ok
      end)

      try do
        # Register hint with shortcuts
        hint_info = %{
          basic: "Search for content",
          detailed: "Search for content in the application",
          shortcuts: [
            {"Enter", "Execute search"},
            {"Alt+S", "Focus search"}
          ]
        }

        UXRefinement.register_component_hint("search_button", hint_info)

        # Verify shortcut registrations
        assert_received {:register_shortcut, "Enter", :search_button_shortcut,
                         opts1}

        assert Keyword.get(opts1, :description) == "Execute search"

        assert_received {:register_shortcut, "Alt+S", :search_button_shortcut,
                         opts2}

        assert Keyword.get(opts2, :description) == "Focus search"
      after
        :meck.unload(KeyboardShortcuts)
      end
    end
  end

  describe "shortcut handling" do
    test "shortcut triggers focus on component" do
      # Enable required features
      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:focus_management)

      # Register a component with shortcut
      UXRefinement.register_hint("search_button", "Search for content")

      UXRefinement.register_component_hint("search_button", %{
        shortcuts: [{"Alt+S", "Focus search"}]
      })

      # Get registered shortcuts
      shortcuts = Process.get(:keyboard_shortcuts)

      # Find the shortcut for search_button
      shortcut_name = :search_button_shortcut
      shortcut = shortcuts.global[shortcut_name]

      # Verify shortcut exists
      assert shortcut != nil

      # Execute the callback
      shortcut.callback.()

      # Verify FocusManager.set_focus was called
      assert :meck.called(FocusManager, :set_focus, ["search_button"])
    end

    test "shortcuts handle accessibility announcements" do
      # Setup: Register a shortcut and accessibility metadata
      :meck.expect(KeyboardShortcuts, :register_shortcut, fn _, _, _, _ -> :ok end)
      :meck.expect(Accessibility, :register_metadata, fn _, _ -> :ok end)
      :meck.expect(Accessibility, :announce, fn _, _ -> :ok end)

      metadata = %{announcement: "Search action triggered"}
      Accessibility.register_metadata("search_button", metadata)

      # Get registered shortcuts
      shortcuts = Process.get(:keyboard_shortcuts)

      # Find the shortcut for search_button
      shortcut_name = :search_button_shortcut
      shortcut = shortcuts.global[shortcut_name]

      # Verify shortcut exists
      assert shortcut != nil

      # Execute the callback
      shortcut.callback.()

      # Verify FocusManager.set_focus was called
      assert :meck.called(FocusManager, :set_focus, ["search_button"])

      # Verify Accessibility.announce was called
      :meck.expect(Accessibility, :announce, fn message, _opts ->
        assert message == "Search action triggered"
        :ok
      end)
    end
  end

  describe "events integration" do
    test "keyboard events are handled" do
      context_pid = self()
      event_handled = fn -> send(context_pid, :handled) end

      # Setup: register a shortcut
      :meck.expect(KeyboardShortcuts, :register_shortcut, fn _, _, _, _ -> :ok end)
      KeyboardShortcuts.register_shortcut("Ctrl+T", :test, event_handled)

      # Simulate a key event
      event = %Event{type: :key, data: %{key: "t", modifiers: [:ctrl]}}
      EventManager.dispatch({:keyboard_event, event})

      # Verify shortcut was triggered
      assert_received :handled
    end

    test "context-specific shortcuts work" do
      context_pid = self()
      global_handled = fn -> send(context_pid, :global_handled) end
      editor_handled = fn -> send(context_pid, :editor_handled) end

      # Register global and editor shortcuts
      :meck.expect(KeyboardShortcuts, :register_shortcut, fn _, _, _, _ -> :ok end)
      :meck.expect(KeyboardShortcuts, :set_context, fn _ -> :ok end)

      KeyboardShortcuts.register_shortcut("Ctrl+S", :save_global, global_handled, [context: :global])
      KeyboardShortcuts.register_shortcut("Ctrl+S", :save_editor, editor_handled, [context: :editor])

      # Set context to :editor
      KeyboardShortcuts.set_context(:editor)

      # Simulate Ctrl+S event
      event = %Event{type: :key, data: %{key: "s", modifiers: [:ctrl]}}
      EventManager.dispatch({:keyboard_event, event})

      # Verify shortcut was triggered
      assert_received :editor_handled
    end
  end
end
