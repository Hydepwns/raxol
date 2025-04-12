defmodule Raxol do
  @moduledoc """
  Raxol is a feature-rich terminal UI framework for Elixir.

  It provides a comprehensive set of components and tools for building
  beautiful, accessible, and responsive terminal applications.

  ## Features

  * **Modern Component Library**: A rich set of pre-built UI components like buttons,
    text inputs, tables, modals, and more.

  * **Accessibility Support**: Built-in features for screen readers, high contrast
    mode, and keyboard navigation.

  * **Theming System**: Customize the look and feel of your application with
    consistent theming.

  * **Responsive Layouts**: Create layouts that adapt to different terminal sizes.

  * **The Elm Architecture**: Follows TEA (The Elm Architecture) for predictable
    state management.

  * **Event Handling**: Comprehensive event system for keyboard, mouse, and terminal events.

  ## Getting Started

  To create a new Raxol application, you need to define three core functions:

  * `init/1`: Initializes your application state
  * `update/2`: Updates the state based on events
  * `render/1`: Renders the UI based on the current state

  Here's a simple counter example:

  ```elixir
  defmodule Counter do
    @behaviour Raxol.App

    alias Raxol.View
    alias Raxol.Components, as: C

    def init(_) do
      %{count: 0}
    end

    def update(model, msg) do
      case msg do
        :increment -> %{model | count: model.count + 1}
        :decrement -> %{model | count: model.count - 1}
        _ -> model
      end
    end

    def render(model) do
      View.view do
        View.panel [title: "Counter Example", border: true], fn ->
          View.column [padding: 1], fn ->
            View.text("Count: \#{model.count}")

            View.row [gap: 1], fn ->
              C.button([on_click: fn -> :decrement end], "-")
              C.button([on_click: fn -> :increment end], "+")
            end
          end
        end
      end
    end
  end

  # Start the application
  Raxol.run(Counter)
  ```

  ## Architecture

  Raxol is built on the Elm Architecture:

  1. **Model**: Your application state
  2. **Update**: Logic to update the state based on messages
  3. **View**: Pure functions to render UI based on the current state

  Messages can be generated by user interactions (like button clicks) or
  system events (like terminal resize).

  ## Components

  Raxol provides a rich set of built-in components in the Raxol.Components
  module. Common components include:

  * Buttons
  * Text inputs
  * Tables
  * Progress indicators
  * Modals
  * Dropdown menus
  * Tab bars

  Each component follows consistent patterns for styling and behavior.
  """

  alias Raxol.System.TerminalPlatform

  @doc """
  Runs a Raxol application.

  This function starts the Raxol runtime with the provided application module
  and options. The application module must implement the `Raxol.App` behaviour.

  ## Parameters

  * `app` - Module implementing the `Raxol.App` behaviour
  * `opts` - Additional options for the runtime

  ## Options

  * `:quit_keys` - List of keys that will quit the application (default: `[{:ctrl, ?c}]`)
  * `:fps` - Target frames per second (default: `60`)
  * `:title` - Terminal window title (default: `"Raxol Application"`)
  * `:font` - Terminal font (if supported)
  * `:font_size` - Terminal font size (if supported)
  * `:accessibility` - Accessibility options
    * `:screen_reader` - Enable screen reader support (default: `true`)
    * `:high_contrast` - Enable high contrast mode (default: `false`)
    * `:large_text` - Enable large text mode (default: `false`)

  ## Returns

  The return value of the application when it exits.

  ## Example

  ```elixir
  Raxol.run(MyApp, %{initial: "state"}, title: "My Application", fps: 30)
  ```
  """
  def run(app, opts \\ []) do
    Raxol.Runtime.run(app, opts)
  end

  @doc """
  Gracefully stops a running Raxol application.

  This function can be called from within your application to exit gracefully.

  ## Parameters

  * `return_value` - Value to return from the `Raxol.run/3` function

  ## Example

  ```elixir
  def update(model, :exit) do
    Raxol.stop(:normal)
    model
  end
  ```
  """
  def stop(return_value \\ :ok) do
    Raxol.Runtime.stop(return_value)
  end

  @doc """
  Returns the current version of Raxol.

  ## Returns

  A string representing the current version.

  ## Example

  ```elixir
  Raxol.version()
  # => "1.0.0"
  ```
  """
  def version do
    # Update this with each release
    "1.0.0"
  end

  @doc """
  Returns information about the terminal environment.

  This includes terminal size, color support, and other capabilities.

  ## Returns

  A map with terminal information.

  ## Example

  ```elixir
  Raxol.terminal_info()
  # => %{
  #      name: "iTerm2",
  #      version: "3.5.0",
  #      features: [:true_color, :unicode, :mouse, :clipboard],
  #      ...
  #    }
  ```
  """
  def terminal_info do
    TerminalPlatform.get_terminal_capabilities()
  end

  @doc """
  Sets the default theme for Raxol applications.

  This function sets the default theme that will be used by Raxol components.

  ## Parameters

  * `theme` - A theme created with `Raxol.Theme.new/1` or one of the built-in themes

  ## Example

  ```elixir
  # Use a built-in theme
  Raxol.set_theme(Raxol.Theme.dark())

  # Create and use a custom theme
  custom_theme = Raxol.Theme.new(name: "Custom", colors: %{primary: :green})
  Raxol.set_theme(custom_theme)
  ```
  """
  def set_theme(theme) do
    Application.put_env(:raxol, :theme, theme)
  end

  @doc """
  Gets the current default theme.

  ## Returns

  The current theme map.

  ## Example

  ```elixir
  theme = Raxol.current_theme()
  ```
  """
  def current_theme do
    Application.get_env(:raxol, :theme, Raxol.Theme.default())
  end

  @doc """
  Enables or disables accessibility features.

  ## Parameters

  * `features` - Map of accessibility features to enable/disable

  ## Options

  * `:screen_reader` - Enable screen reader support
  * `:high_contrast` - Enable high contrast mode
  * `:large_text` - Enable large text mode
  * `:reduced_motion` - Reduce or eliminate animations

  ## Example

  ```elixir
  Raxol.set_accessibility(screen_reader: true, high_contrast: true)
  ```
  """
  def set_accessibility(features) do
    current =
      Application.get_env(:raxol, :accessibility, %{
        screen_reader: true,
        high_contrast: false,
        large_text: false,
        reduced_motion: false
      })

    updated =
      Enum.reduce(features, current, fn {k, v}, acc ->
        Map.put(acc, k, v)
      end)

    Application.put_env(:raxol, :accessibility, updated)

    # If high contrast is enabled, switch to high contrast theme
    if Keyword.get(features, :high_contrast) do
      set_theme(Raxol.Theme.high_contrast())
    end
  end

  @doc """
  Gets the current accessibility settings.

  ## Returns

  A map of current accessibility settings.

  ## Example

  ```elixir
  settings = Raxol.accessibility_settings()
  if settings.high_contrast do
    # Do something for high contrast mode
  end
  ```
  """
  def accessibility_settings do
    Application.get_env(:raxol, :accessibility, %{
      screen_reader: true,
      high_contrast: false,
      large_text: false,
      reduced_motion: false
    })
  end
end
