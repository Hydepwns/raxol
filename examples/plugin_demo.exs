defmodule Raxol.Examples.PluginDemo do
  # TODO: This example needs significant rework.
  # The Raxol runtime and plugin system have been refactored.
  # Plugin management (load, list, enable, disable, unload) should now
  # likely be handled via Raxol.Core.Runtime.Plugins.Manager, possibly
  # within a proper Raxol.App or by interacting with a started runtime.
  # The Emulator.* functions for plugin management used below are likely deprecated.
  @moduledoc """
  Example application that demonstrates how to use the Raxol terminal emulator with its plugin system.
  (Currently outdated due to refactoring)
  """

  alias Raxol.Terminal.Emulator
  # Plugin modules seem to still be in Raxol.Plugins.*
  alias Raxol.Plugins.{HyperlinkPlugin, ImagePlugin, ThemePlugin, SearchPlugin}

  def run do
    _output1 = IO.puts("Raxol Terminal Emulator Plugin Demo")
    _output2 = IO.puts("==================================")
    _output3 = IO.puts("")

    # Create a new terminal emulator
    emulator = Emulator.new(80, 24)
    _output4 = IO.puts("Created a new terminal emulator with dimensions 80x24")
    _output5 = IO.puts("")

    # Load plugins (Commented out - Use Core.Runtime.Plugins.Manager)
    # {:ok, emulator} = Emulator.load_plugin(emulator, HyperlinkPlugin)
    # {:ok, emulator} = Emulator.load_plugin(emulator, ImagePlugin)
    # {:ok, emulator} = Emulator.load_plugin(emulator, ThemePlugin)
    # {:ok, emulator} = Emulator.load_plugin(emulator, SearchPlugin)
    _output6 = IO.puts("Plugin loading commented out - needs update.")
    _output7 = IO.puts("")

    # List loaded plugins (Commented out - Use Core.Runtime.Plugins.Manager)
    # plugins = Emulator.list_plugins(emulator)
    _output8 = IO.puts("Listing plugins commented out - needs update.")
    # _plugins_list = Enum.each(plugins, fn plugin ->
    #   _plugin_info = IO.puts("  - #{plugin.name} (#{if plugin.enabled, do: "enabled", else: "disabled"})")
    # end)
    _output9 = IO.puts("")

    # Demonstrate hyperlink plugin
    _output10 = IO.puts("Demonstrating hyperlink plugin:")
    emulator = Emulator.write_string(emulator, "Visit https://example.com for more information.\n")
    _output11 = IO.puts("  - Wrote text with a URL")
    _output12 = IO.puts("")

    # Demonstrate theme plugin
    _output13 = IO.puts("Demonstrating theme plugin:")
    emulator = Emulator.process_input(emulator, "/theme solarized_dark")
    _output14 = IO.puts("  - Changed theme to solarized_dark")
    _output15 = IO.puts("")

    # Demonstrate search plugin
    _output16 = IO.puts("Demonstrating search plugin:")
    emulator = Emulator.process_input(emulator, "/search example")
    _output17 = IO.puts("  - Started search for 'example'")
    _output18 = IO.puts("")

    # Demonstrate image plugin
    _output19 = IO.puts("Demonstrating image plugin:")
    # Create a simple 1x1 pixel image in base64
    pixel_data = <<255, 0, 0>> # Red pixel
    base64_data = Base.encode64(pixel_data)
    image_marker = "<<IMAGE:#{base64_data}:1:1:1>>"
    emulator = Emulator.write_string(emulator, "Displaying a red pixel: #{image_marker}\n")
    _output20 = IO.puts("  - Wrote text with an image marker")
    _output21 = IO.puts("")

    # Demonstrate plugin management (Commented out - Use Core.Runtime.Plugins.Manager)
    _output22 = IO.puts("Demonstrating plugin management (Commented out - needs update):")
    # {:ok, emulator} = Emulator.disable_plugin(emulator, "hyperlink")
    _output23 = IO.puts("  - Disabling hyperlink plugin (commented out)")

    emulator = Emulator.write_string(emulator, "This URL should not be clickable: https://example.com\n")
    _output24 = IO.puts("  - Wrote text with a URL (hyperlink plugin disabled)")

    # {:ok, emulator} = Emulator.enable_plugin(emulator, "hyperlink")
    _output25 = IO.puts("  - Re-enabling hyperlink plugin (commented out)")

    emulator = Emulator.write_string(emulator, "This URL should be clickable: https://example.com\n")
    _output26 = IO.puts("  - Wrote text with a URL (hyperlink plugin enabled)")
    _output27 = IO.puts("")

    # Demonstrate plugin unloading (Commented out - Use Core.Runtime.Plugins.Manager)
    _output28 = IO.puts("Demonstrating plugin unloading (Commented out - needs update):")
    # {:ok, emulator} = Emulator.unload_plugin(emulator, "image")
    _output29 = IO.puts("  - Unloading image plugin (commented out)")

    # plugins = Emulator.list_plugins(emulator)
    _output30 = IO.puts("  - Listing remaining plugins (commented out)")
    # _final_plugins = Enum.each(plugins, fn plugin ->
    #   _plugin_info = IO.puts("    - #{plugin.name}")
    # end)
    _output31 = IO.puts("")

    _final_message = IO.puts("Plugin demo completed successfully!")
  end
end

# Run the demo
_demo_result = Raxol.Examples.PluginDemo.run()
