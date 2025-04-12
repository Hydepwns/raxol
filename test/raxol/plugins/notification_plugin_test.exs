defmodule Raxol.Plugins.NotificationPluginTest do
  use ExUnit.Case
  alias Raxol.Plugins.NotificationPlugin

  test "initializes with default configuration" do
    {:ok, plugin} = NotificationPlugin.init()
    assert plugin.name == "notification"
    assert plugin.enabled == true
    assert plugin.config.style == "minimal"
    assert plugin.notifications == []
  end

  test "shows notification" do
    {:ok, plugin} = NotificationPlugin.init()

    {:ok, updated_plugin, display} =
      NotificationPlugin.handle_input(plugin, "/notify success Test")

    assert length(updated_plugin.notifications) == 1
    assert String.contains?(display, "[SUCCESS]")
  end

  test "updates configuration" do
    {:ok, plugin} = NotificationPlugin.init()

    {:ok, updated_plugin} =
      NotificationPlugin.handle_input(plugin, "/notify-config style banner")

    assert updated_plugin.config.style == "banner"
  end
end
