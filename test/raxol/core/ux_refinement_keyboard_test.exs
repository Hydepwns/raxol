defmodule Raxol.Core.UXRefinementKeyboardTest do
  use ExUnit.Case, async: true

  alias Raxol.Core.UXRefinement
  alias Raxol.Core.KeyboardShortcuts
  alias Raxol.Core.FocusManager
  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.Accessibility

  setup do
    # Initialize UX refinement
    UXRefinement.init()

    # Mock dependencies to avoid side effects
    :meck.new(FocusManager, [:passthrough])
    :meck.expect(FocusManager, :init, fn -> :ok end)
    :meck.expect(FocusManager, :register_focusable, fn _, _ -> :ok end)
    :meck.expect(FocusManager, :set_focus, fn _ -> :ok end)

    :meck.new(Accessibility, [:passthrough])
    :meck.expect(Accessibility, :enable, fn _ -> :ok end)
    :meck.expect(Accessibility, :announce, fn _, _ -> :ok end)
    :meck.expect(Accessibility, :register_element_metadata, fn _, _ -> :ok end)

    on_exit(fn ->
      # Clean up
      :meck.unload(FocusManager)
      :meck.unload(Accessibility)

      # Disable features
      UXRefinement.disable_feature(:keyboard_shortcuts)
      UXRefinement.disable_feature(:accessibility)
      UXRefinement.disable_feature(:focus_management)
      UXRefinement.disable_feature(:events)
    end)

    :ok
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
      # Enable keyboard shortcuts
      UXRefinement.enable_feature(:keyboard_shortcuts)

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
        # Register a shortcut
        callback = fn -> :ok end

        UXRefinement.register_shortcut("Ctrl+S", :save, callback,
          description: "Save document"
        )

        # Verify delegation
        assert_received {:register_shortcut, "Ctrl+S", :save,
                         [description: "Save document"]}
      after
        :meck.unload(KeyboardShortcuts)
      end
    end

    test "set_shortcuts_context/1 delegates to KeyboardShortcuts" do
      # Enable keyboard shortcuts
      UXRefinement.enable_feature(:keyboard_shortcuts)

      # Store test process pid
      test_pid = self()

      # Mock KeyboardShortcuts.set_context
      :meck.new(KeyboardShortcuts, [:passthrough])

      :meck.expect(KeyboardShortcuts, :set_context, fn context ->
        send(test_pid, {:set_context, context})
        :ok
      end)

      try do
        # Set context
        UXRefinement.set_shortcuts_context(:editor)

        # Verify delegation
        assert_received {:set_context, :editor}
      after
        :meck.unload(KeyboardShortcuts)
      end
    end

    test "get_available_shortcuts/0 delegates to KeyboardShortcuts" do
      # Enable keyboard shortcuts
      UXRefinement.enable_feature(:keyboard_shortcuts)

      # Mock KeyboardShortcuts.get_shortcuts_for_context
      mock_shortcuts = [
        %{name: :save, key_combo: "Ctrl+S", description: "Save document"}
      ]

      :meck.new(KeyboardShortcuts, [:passthrough])

      :meck.expect(KeyboardShortcuts, :get_shortcuts_for_context, fn ->
        mock_shortcuts
      end)

      try do
        # Get shortcuts
        shortcuts = UXRefinement.get_available_shortcuts()

        # Verify result
        assert shortcuts == mock_shortcuts
      after
        :meck.unload(KeyboardShortcuts)
      end
    end

    test "show_shortcuts_help/0 delegates to KeyboardShortcuts" do
      # Enable keyboard shortcuts
      UXRefinement.enable_feature(:keyboard_shortcuts)

      # Mock KeyboardShortcuts.show_shortcuts_help
      mock_result =
        {:ok, "Available keyboard shortcuts for Global:\nCtrl+S: Save document"}

      :meck.new(KeyboardShortcuts, [:passthrough])

      :meck.expect(KeyboardShortcuts, :show_shortcuts_help, fn ->
        mock_result
      end)

      try do
        # Show help
        result = UXRefinement.show_shortcuts_help()

        # Verify result
        assert result == mock_result
      after
        :meck.unload(KeyboardShortcuts)
      end
    end
  end

  describe "component shortcuts integration" do
    test "register_accessibility_metadata/2 registers component shortcut" do
      # Enable required features
      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:accessibility)
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
        # Register metadata with shortcut
        metadata = %{
          announce: "Search button. Press Enter to search.",
          role: :button,
          label: "Search",
          shortcut: "Alt+S"
        }

        UXRefinement.register_accessibility_metadata("search_button", metadata)

        # Verify shortcut registration
        assert_received {:register_shortcut, "Alt+S", :search_button_shortcut,
                         opts}

        assert Keyword.get(opts, :description) == "Focus Search"
      after
        :meck.unload(KeyboardShortcuts)
      end
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
      # Enable required features
      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:focus_management)
      UXRefinement.enable_feature(:accessibility)

      # Register a component with metadata
      metadata = %{
        announce: "Search button. Press Enter to search.",
        role: :button,
        label: "Search",
        shortcut: "Alt+S"
      }

      UXRefinement.register_accessibility_metadata("search_button", metadata)

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
      assert :meck.called(Accessibility, :announce, [
               "Search button. Press Enter to search.",
               [priority: :medium]
             ])
    end
  end

  describe "events integration" do
    test "keyboard events are handled" do
      # Enable required features
      UXRefinement.enable_feature(:keyboard_shortcuts)
      UXRefinement.enable_feature(:focus_management)

      # Store test process pid
      test_pid = self()

      # Register a test shortcut
      UXRefinement.register_shortcut("Ctrl+T", :test, fn ->
        send(test_pid, :test_shortcut_triggered)
      end)

      # Simulate keyboard event
      key_event = {:key, "t", [:ctrl]}
      EventManager.dispatch({:keyboard_event, key_event})

      # Verify shortcut was triggered
      assert_received :test_shortcut_triggered
    end

    test "context-specific shortcuts work" do
      # Enable required features
      UXRefinement.enable_feature(:keyboard_shortcuts)

      # Store test process pid
      test_pid = self()

      # Register context-specific shortcuts
      UXRefinement.register_shortcut(
        "Alt+E",
        :edit,
        fn ->
          send(test_pid, :edit_triggered)
        end,
        context: :editor
      )

      # Set context
      UXRefinement.set_shortcuts_context(:editor)

      # Simulate keyboard event
      key_event = {:key, "e", [:alt]}
      EventManager.dispatch({:keyboard_event, key_event})

      # Verify shortcut was triggered
      assert_received :edit_triggered
    end
  end
end
