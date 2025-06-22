defmodule Raxol.Core.KeyboardShortcutsTest do
  @moduledoc """
  Tests for the keyboard shortcuts system, including initialization,
  registration, unregistration, context management, and event handling.
  """
  # Must be false due to Process dictionary usage
  use ExUnit.Case, async: false
  import Raxol.Guards

  alias Raxol.Core.Events.Manager, as: EventManager
  alias Raxol.Core.KeyboardShortcuts

  setup do
    # Initialize event manager for tests
    EventManager.init()

    # Initialize KeyboardShortcuts
    KeyboardShortcuts.init()

    on_exit(fn ->
      # Clean up
      KeyboardShortcuts.cleanup()
      if Process.whereis(EventManager), do: EventManager.cleanup()
    end)

    :ok
  end

  describe "init/0" do
    test "initializes keyboard shortcuts registry" do
      # Re-init for test coverage
      KeyboardShortcuts.init()

      # Check registry structure
      shortcuts = Process.get(:keyboard_shortcuts)
      assert shortcuts != nil
      assert Map.has_key?(shortcuts, :global)
      assert Map.has_key?(shortcuts, :contexts)
      assert map?(shortcuts.global)
      assert map?(shortcuts.contexts)
    end
  end

  describe "cleanup/0" do
    test "cleans up keyboard shortcuts registry" do
      # Ensure we have registry
      assert Process.get(:keyboard_shortcuts) != nil

      # Clean up
      KeyboardShortcuts.cleanup()

      # Check registry is removed
      assert Process.get(:keyboard_shortcuts) == nil
    end
  end

  describe "register_shortcut/4" do
    test "registers global shortcut" do
      # Store test process pid
      test_pid = self()

      # Register a global shortcut
      callback = fn -> send(test_pid, :shortcut_triggered) end

      assert :ok =
               KeyboardShortcuts.register_shortcut("Ctrl+S", :save, callback,
                 description: "Save document"
               )

      # Check registry
      shortcuts = Process.get(:keyboard_shortcuts)
      assert Map.has_key?(shortcuts.global, :save)

      # Check shortcut definition
      shortcut = shortcuts.global.save
      assert shortcut.name == :save
      assert shortcut.description == "Save document"
      assert shortcut.priority == :medium
      assert shortcut.callback == callback

      # Check key combo parsing
      key_combo = shortcut.key_combo
      assert key_combo.key == "s"
      assert key_combo.ctrl == true
      assert key_combo.alt == false
      assert key_combo.shift == false
    end

    test "registers context-specific shortcut" do
      # Register a context-specific shortcut
      assert :ok =
               KeyboardShortcuts.register_shortcut(
                 "Alt+F",
                 :file_menu,
                 fn -> nil end,
                 context: :main_menu,
                 description: "Open file menu",
                 priority: :high
               )

      # Check registry
      shortcuts = Process.get(:keyboard_shortcuts)
      assert Map.has_key?(shortcuts.contexts, :main_menu)
      assert Map.has_key?(shortcuts.contexts.main_menu, :file_menu)

      # Check shortcut definition
      shortcut = shortcuts.contexts.main_menu.file_menu
      assert shortcut.name == :file_menu
      assert shortcut.description == "Open file menu"
      assert shortcut.priority == :high

      # Check key combo parsing
      key_combo = shortcut.key_combo
      assert key_combo.key == "f"
      assert key_combo.ctrl == false
      assert key_combo.alt == true
      assert key_combo.shift == false
    end

    test "handles complex key combinations" do
      # Register with complex key combo
      assert :ok =
               KeyboardShortcuts.register_shortcut(
                 "Ctrl+Shift+Alt+X",
                 :complex,
                 fn -> nil end
               )

      # Check registry
      shortcuts = Process.get(:keyboard_shortcuts)
      assert Map.has_key?(shortcuts.global, :complex)

      # Check key combo parsing
      key_combo = shortcuts.global.complex.key_combo
      assert key_combo.key == "x"
      assert key_combo.ctrl == true
      assert key_combo.alt == true
      assert key_combo.shift == true
    end
  end

  describe "unregister_shortcut/2" do
    test "unregisters global shortcut" do
      # Register a shortcut
      KeyboardShortcuts.register_shortcut("Ctrl+S", :save, fn -> nil end)

      # Verify it exists
      shortcuts = Process.get(:keyboard_shortcuts)
      assert Map.has_key?(shortcuts.global, :save)

      # Unregister it
      assert :ok = KeyboardShortcuts.unregister_shortcut(:save)

      # Check it's gone
      shortcuts = Process.get(:keyboard_shortcuts)
      refute Map.has_key?(shortcuts.global, :save)
    end

    test "unregisters context-specific shortcut" do
      # Register a context-specific shortcut
      KeyboardShortcuts.register_shortcut("Alt+F", :file_menu, fn -> nil end,
        context: :main_menu
      )

      # Verify it exists
      shortcuts = Process.get(:keyboard_shortcuts)
      assert Map.has_key?(shortcuts.contexts, :main_menu)
      assert Map.has_key?(shortcuts.contexts.main_menu, :file_menu)

      # Unregister it
      assert :ok = KeyboardShortcuts.unregister_shortcut(:file_menu, :main_menu)

      # Check it's gone
      shortcuts = Process.get(:keyboard_shortcuts)
      assert Map.has_key?(shortcuts.contexts, :main_menu)
      refute Map.has_key?(shortcuts.contexts.main_menu, :file_menu)
    end
  end

  describe "set_context/1 and get_current_context/0" do
    test "sets and gets current context" do
      # Default should be :global
      assert KeyboardShortcuts.get_current_context() == :global

      # Set context
      assert :ok = KeyboardShortcuts.set_context(:editor)

      # Get context
      assert KeyboardShortcuts.get_current_context() == :editor
    end
  end

  describe "get_shortcuts_for_context/1" do
    test "gets global shortcuts" do
      # Register some global shortcuts
      KeyboardShortcuts.register_shortcut("Ctrl+S", :save, fn -> nil end,
        description: "Save document"
      )

      KeyboardShortcuts.register_shortcut("Ctrl+O", :open, fn -> nil end,
        description: "Open document"
      )

      # Get shortcuts
      shortcuts = KeyboardShortcuts.get_shortcuts_for_context(:global)

      # Check results
      assert length(shortcuts) == 2

      # Find save shortcut
      save_shortcut = Enum.find(shortcuts, fn s -> s.name == :save end)
      assert save_shortcut != nil
      assert save_shortcut.key_combo == "Ctrl+S"
      assert save_shortcut.description == "Save document"

      # Find open shortcut
      open_shortcut = Enum.find(shortcuts, fn s -> s.name == :open end)
      assert open_shortcut != nil
      assert open_shortcut.key_combo == "Ctrl+O"
      assert open_shortcut.description == "Open document"
    end

    test "gets context-specific shortcuts" do
      # Register global shortcut
      KeyboardShortcuts.register_shortcut("Ctrl+S", :save, fn -> nil end,
        description: "Save document"
      )

      # Register context-specific shortcuts
      KeyboardShortcuts.register_shortcut("Alt+F", :file_menu, fn -> nil end,
        context: :main_menu,
        description: "Open file menu"
      )

      KeyboardShortcuts.register_shortcut("Alt+E", :edit_menu, fn -> nil end,
        context: :main_menu,
        description: "Open edit menu"
      )

      # Get shortcuts for context
      shortcuts = KeyboardShortcuts.get_shortcuts_for_context(:main_menu)

      # Check results - should include global and context-specific
      assert length(shortcuts) == 3

      # Check for global shortcut
      save_shortcut = Enum.find(shortcuts, fn s -> s.name == :save end)
      assert save_shortcut != nil

      # Check for context-specific shortcuts
      file_menu_shortcut =
        Enum.find(shortcuts, fn s -> s.name == :file_menu end)

      assert file_menu_shortcut != nil
      assert file_menu_shortcut.key_combo == "Alt+F"

      edit_menu_shortcut =
        Enum.find(shortcuts, fn s -> s.name == :edit_menu end)

      assert edit_menu_shortcut != nil
      assert edit_menu_shortcut.key_combo == "Alt+E"
    end

    test "gets shortcuts for current context when nil is passed" do
      # Register global shortcut
      KeyboardShortcuts.register_shortcut("Ctrl+S", :save, fn -> nil end)

      # Register context-specific shortcut
      KeyboardShortcuts.register_shortcut("Alt+F", :file_menu, fn -> nil end,
        context: :main_menu
      )

      # Set current context
      KeyboardShortcuts.set_context(:main_menu)

      # Get shortcuts for current context (nil)
      shortcuts = KeyboardShortcuts.get_shortcuts_for_context()

      # Should include both global and context-specific
      assert length(shortcuts) == 2
    end
  end

  describe "show_shortcuts_help/0" do
    test "generates help message for shortcuts" do
      # Register some shortcuts
      KeyboardShortcuts.register_shortcut("Ctrl+S", :save, fn -> nil end,
        description: "Save document"
      )

      KeyboardShortcuts.register_shortcut("Ctrl+O", :open, fn -> nil end,
        description: "Open document"
      )

      # Show help
      {:ok, help_message} = KeyboardShortcuts.show_shortcuts_help()

      # Check help message content
      assert String.contains?(
               help_message,
               "Available keyboard shortcuts for Global"
             )

      assert String.contains?(help_message, "Ctrl+S: Save document")
      assert String.contains?(help_message, "Ctrl+O: Open document")
    end
  end

  describe "trigger_shortcut/2" do
    test "triggers shortcut callback" do
      # Store test process pid
      test_pid = self()

      # Register a global shortcut
      KeyboardShortcuts.register_shortcut("Ctrl+S", :save, fn ->
        send(test_pid, :save_triggered)
      end)

      # Trigger shortcut
      assert :ok = KeyboardShortcuts.trigger_shortcut(:save)

      # Check callback was called
      assert_received :save_triggered
    end

    test "returns error for non-existent shortcut" do
      # Trigger non-existent shortcut
      assert {:error, :shortcut_not_found} =
               KeyboardShortcuts.trigger_shortcut(:nonexistent)
    end

    test "finds shortcut in specified context" do
      # Store test process pid
      test_pid = self()

      # Register a context-specific shortcut
      KeyboardShortcuts.register_shortcut(
        "Alt+F",
        :file_menu,
        fn ->
          send(test_pid, :file_menu_triggered)
        end,
        context: :main_menu
      )

      # Trigger shortcut in context
      assert :ok = KeyboardShortcuts.trigger_shortcut(:file_menu, :main_menu)

      # Check callback was called
      assert_received :file_menu_triggered
    end

    test "finds shortcut in current context when nil is passed" do
      # Store test process pid
      test_pid = self()

      # Register a context-specific shortcut
      KeyboardShortcuts.register_shortcut(
        "Alt+F",
        :file_menu,
        fn ->
          send(test_pid, :file_menu_triggered)
        end,
        context: :main_menu
      )

      # Set current context
      KeyboardShortcuts.set_context(:main_menu)

      # Trigger shortcut in current context (nil)
      assert :ok = KeyboardShortcuts.trigger_shortcut(:file_menu)

      # Check callback was called
      assert_received :file_menu_triggered
    end
  end

  describe "handle_keyboard_event/1" do
    test "executes callback for matching shortcut" do
      # Store test process pid
      test_pid = self()

      # Register a global shortcut
      KeyboardShortcuts.register_shortcut("Ctrl+S", :save, fn ->
        send(test_pid, :save_triggered)
      end)

      # Dispatch keyboard event
      EventManager.dispatch({:keyboard_event, {:key, "s", [:ctrl]}})

      # Check callback was called
      assert_received :save_triggered
    end

    test "handles context-specific shortcuts" do
      # Store test process pid
      test_pid = self()

      # Register a context-specific shortcut
      KeyboardShortcuts.register_shortcut(
        "Alt+F",
        :file_menu,
        fn ->
          send(test_pid, :file_menu_triggered)
        end,
        context: :main_menu
      )

      # Set current context
      KeyboardShortcuts.set_context(:main_menu)

      # Dispatch keyboard event
      EventManager.dispatch({:keyboard_event, {:key, "f", [:alt]}})

      # Check callback was called
      assert_received :file_menu_triggered
    end

    test "handles multiple modifiers" do
      # Store test process pid
      test_pid = self()

      # Register a shortcut with multiple modifiers
      KeyboardShortcuts.register_shortcut("Ctrl+Shift+X", :cut, fn ->
        send(test_pid, :cut_triggered)
      end)

      # Dispatch keyboard event with multiple modifiers
      EventManager.dispatch({:keyboard_event, {:key, "x", [:ctrl, :shift]}})

      # Check callback was called
      assert_received :cut_triggered
    end

    test "context shortcuts override global shortcuts with same name" do
      # Store test process pid
      test_pid = self()

      # Register global shortcut
      KeyboardShortcuts.register_shortcut("Ctrl+S", :save, fn ->
        send(test_pid, :global_save_triggered)
      end)

      # Register context shortcut with same name
      KeyboardShortcuts.register_shortcut(
        "Alt+S",
        :save,
        fn ->
          send(test_pid, :context_save_triggered)
        end,
        context: :editor
      )

      # Set context
      KeyboardShortcuts.set_context(:editor)

      # Dispatch keyboard event matching context shortcut
      EventManager.dispatch({:keyboard_event, {:key, "s", [:alt]}})

      # Should trigger context version
      assert_received :context_save_triggered
      refute_received :global_save_triggered
    end

    test "respects priority order for shortcuts" do
      # Store test process pid
      test_pid = self()

      # Register low priority shortcut
      KeyboardShortcuts.register_shortcut(
        "Ctrl+P",
        :print_low,
        fn ->
          send(test_pid, :print_low_triggered)
        end,
        priority: :low
      )

      # Register high priority shortcut with same key combo
      KeyboardShortcuts.register_shortcut(
        "Ctrl+P",
        :print_high,
        fn ->
          send(test_pid, :print_high_triggered)
        end,
        priority: :high,
        context: :editor
      )

      # Set context
      KeyboardShortcuts.set_context(:editor)

      # Dispatch keyboard event
      EventManager.dispatch({:keyboard_event, {:key, "p", [:ctrl]}})

      # Should trigger high priority first
      assert_received :print_high_triggered
    end
  end
end
