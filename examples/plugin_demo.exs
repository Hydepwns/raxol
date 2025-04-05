defmodule Raxol.Examples.PluginDemo do
  @moduledoc """
  Example application that demonstrates how to use the Raxol terminal emulator with its plugin system.
  """

  alias Raxol.Terminal.Emulator
  alias Raxol.Plugins.{HyperlinkPlugin, ImagePlugin, ThemePlugin, SearchPlugin}

  def run do
    IO.puts("Raxol Terminal Emulator Plugin Demo")
    IO.puts("==================================")
    IO.puts("")

    # Create a new terminal emulator
    emulator = Emulator.new(80, 24)
    IO.puts("Created a new terminal emulator with dimensions 80x24")
    IO.puts("")

    # Load plugins
    {:ok, emulator} = Emulator.load_plugin(emulator, HyperlinkPlugin)
    {:ok, emulator} = Emulator.load_plugin(emulator, ImagePlugin)
    {:ok, emulator} = Emulator.load_plugin(emulator, ThemePlugin)
    {:ok, emulator} = Emulator.load_plugin(emulator, SearchPlugin)
    IO.puts("Loaded plugins: hyperlink, image, theme, search")
    IO.puts("")

    # List loaded plugins
    plugins = Emulator.list_plugins(emulator)
    IO.puts("Loaded plugins:")
    Enum.each(plugins, fn plugin ->
      IO.puts("  - #{plugin.name} (#{if plugin.enabled, do: "enabled", else: "disabled"})")
    end)
    IO.puts("")

    # Demonstrate hyperlink plugin
    IO.puts("Demonstrating hyperlink plugin:")
    emulator = Emulator.write_string(emulator, "Visit https://example.com for more information.\n")
    IO.puts("  - Wrote text with a URL")
    IO.puts("")

    # Demonstrate theme plugin
    IO.puts("Demonstrating theme plugin:")
    emulator = Emulator.process_input(emulator, "/theme solarized_dark")
    IO.puts("  - Changed theme to solarized_dark")
    IO.puts("")

    # Demonstrate search plugin
    IO.puts("Demonstrating search plugin:")
    emulator = Emulator.process_input(emulator, "/search example")
    IO.puts("  - Started search for 'example'")
    IO.puts("")

    # Demonstrate image plugin
    IO.puts("Demonstrating image plugin:")
    # Create a simple 1x1 pixel image in base64
    pixel_data = <<255, 0, 0>> # Red pixel
    base64_data = Base.encode64(pixel_data)
    image_marker = "<<IMAGE:#{base64_data}:1:1:1>>"
    emulator = Emulator.write_string(emulator, "Displaying a red pixel: #{image_marker}\n")
    IO.puts("  - Wrote text with an image marker")
    IO.puts("")

    # Demonstrate plugin management
    IO.puts("Demonstrating plugin management:")
    {:ok, emulator} = Emulator.disable_plugin(emulator, "hyperlink")
    IO.puts("  - Disabled hyperlink plugin")
    
    emulator = Emulator.write_string(emulator, "This URL should not be clickable: https://example.com\n")
    IO.puts("  - Wrote text with a URL (hyperlink plugin disabled)")
    
    {:ok, emulator} = Emulator.enable_plugin(emulator, "hyperlink")
    IO.puts("  - Re-enabled hyperlink plugin")
    
    emulator = Emulator.write_string(emulator, "This URL should be clickable: https://example.com\n")
    IO.puts("  - Wrote text with a URL (hyperlink plugin enabled)")
    IO.puts("")

    # Demonstrate plugin unloading
    IO.puts("Demonstrating plugin unloading:")
    {:ok, emulator} = Emulator.unload_plugin(emulator, "image")
    IO.puts("  - Unloaded image plugin")
    
    plugins = Emulator.list_plugins(emulator)
    IO.puts("  - Remaining plugins: #{length(plugins)}")
    Enum.each(plugins, fn plugin ->
      IO.puts("    - #{plugin.name}")
    end)
    IO.puts("")

    IO.puts("Plugin demo completed successfully!")
  end
end

# Run the demo
Raxol.Examples.PluginDemo.run() 