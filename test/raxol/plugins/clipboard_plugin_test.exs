defmodule Raxol.Plugins.ClipboardPluginTest do
  use ExUnit.Case
  alias Raxol.Plugins.ClipboardPlugin

  describe "clipboard plugin" do
    test "initializes with default configuration" do
      {:ok, plugin} = ClipboardPlugin.init()

      assert plugin.name == "clipboard"
      assert plugin.version == "1.0.0"

      assert plugin.description ==
               "Provides clipboard functionality for copying and pasting text"

      assert plugin.enabled == true
      assert plugin.api_version == "1.0.0"
      assert plugin.selection_start == nil
      assert plugin.selection_end == nil
      assert plugin.is_selecting == false

      # Check default config
      assert plugin.config.copy_command == "copy"
      assert plugin.config.paste_command == "paste"
      assert plugin.config.selection_mode == "line"
      assert plugin.config.copy_notification == true
      assert plugin.config.paste_notification == true
      assert plugin.config.notification_duration == 2000

      # Check dependencies
      assert length(plugin.dependencies) == 1
      [dependency] = plugin.dependencies
      assert dependency["name"] == "notification"
      assert dependency["version"] == ">= 1.0.0"
      assert dependency["optional"] == true
    end

    test "initializes with custom configuration" do
      custom_config = %{
        copy_command: "cp",
        paste_command: "pt",
        selection_mode: "block",
        copy_notification: false,
        paste_notification: false,
        notification_duration: 1000
      }

      {:ok, plugin} = ClipboardPlugin.init(custom_config)

      # Check custom config
      assert plugin.config.copy_command == "cp"
      assert plugin.config.paste_command == "pt"
      assert plugin.config.selection_mode == "block"
      assert plugin.config.copy_notification == false
      assert plugin.config.paste_notification == false
      assert plugin.config.notification_duration == 1000
    end

    test "parses copy command correctly" do
      {:ok, plugin} = ClipboardPlugin.init()

      # Test with mode only
      assert {:ok, "line", nil, nil} =
               ClipboardPlugin.parse_copy_command("/copy line", "copy")

      # Test with mode and positions
      assert {:ok, "block", {10, 20}, {30, 40}} =
               ClipboardPlugin.parse_copy_command(
                 "/copy block 10,20 30,40",
                 "copy"
               )

      # Test with invalid format
      assert {:error, _} =
               ClipboardPlugin.parse_copy_command("/copy invalid", "copy")

      # Test with invalid position format
      assert {:error, _} =
               ClipboardPlugin.parse_copy_command(
                 "/copy line 10,20 invalid",
                 "copy"
               )
    end

    test "parses select command correctly" do
      {:ok, plugin} = ClipboardPlugin.init()

      # Test with mode only
      assert {:ok, "line", nil} =
               ClipboardPlugin.parse_select_command("/select line")

      # Test with mode and position
      assert {:ok, "block", {10, 20}} =
               ClipboardPlugin.parse_select_command("/select block 10,20")

      # Test with invalid format
      assert {:error, _} =
               ClipboardPlugin.parse_select_command("/select invalid")

      # Test with invalid position format
      assert {:error, _} =
               ClipboardPlugin.parse_select_command("/select line invalid")
    end

    test "parses end-select command correctly" do
      {:ok, plugin} = ClipboardPlugin.init()

      # Test with no position
      assert {:ok, nil} =
               ClipboardPlugin.parse_end_select_command("/end-select")

      # Test with position
      assert {:ok, {10, 20}} =
               ClipboardPlugin.parse_end_select_command("/end-select 10,20")

      # Test with invalid position format
      assert {:error, _} =
               ClipboardPlugin.parse_end_select_command("/end-select invalid")
    end

    test "handles selection start and end" do
      {:ok, plugin} = ClipboardPlugin.init()

      # Start selection
      {:ok, updated_plugin} =
        ClipboardPlugin.start_selection(plugin, "line", {10, 20})

      assert updated_plugin.selection_start == {10, 20}
      assert updated_plugin.selection_end == {10, 20}
      assert updated_plugin.is_selecting == true
      assert updated_plugin.config.selection_mode == "line"

      # Update selection
      {:ok, updated_plugin} =
        ClipboardPlugin.update_selection(updated_plugin, {30, 40})

      assert updated_plugin.selection_end == {30, 40}

      # End selection
      {:ok, updated_plugin} =
        ClipboardPlugin.end_selection(updated_plugin, {50, 60})

      assert updated_plugin.selection_end == {50, 60}
      assert updated_plugin.is_selecting == false
    end

    test "resets selection on resize" do
      {:ok, plugin} = ClipboardPlugin.init()

      # Start selection
      {:ok, plugin} = ClipboardPlugin.start_selection(plugin, "line", {10, 20})
      assert plugin.is_selecting == true

      # Handle resize
      {:ok, updated_plugin} = ClipboardPlugin.handle_resize(plugin, 80, 24)
      assert updated_plugin.selection_start == nil
      assert updated_plugin.selection_end == nil
      assert updated_plugin.is_selecting == false
    end

    test "handles mouse events for selection" do
      {:ok, plugin} = ClipboardPlugin.init()

      # Mouse down
      {:ok, updated_plugin} =
        ClipboardPlugin.handle_mouse(plugin, {:mouse_down, :left, 10, 20})

      assert updated_plugin.selection_start == {10, 20}
      assert updated_plugin.selection_end == {10, 20}
      assert updated_plugin.is_selecting == true

      # Mouse move
      {:ok, updated_plugin} =
        ClipboardPlugin.handle_mouse(updated_plugin, {:mouse_move, 30, 40})

      assert updated_plugin.selection_end == {30, 40}

      # Mouse up
      {:ok, updated_plugin} =
        ClipboardPlugin.handle_mouse(updated_plugin, {:mouse_up, :left, 50, 60})

      assert updated_plugin.selection_end == {50, 60}
      assert updated_plugin.is_selecting == false
    end
  end
end
