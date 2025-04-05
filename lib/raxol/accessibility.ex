defmodule Raxol.Accessibility do
  @moduledoc """
  Accessibility features for terminal UI applications.
  
  This module provides accessibility features such as screen reader
  announcements, high contrast mode, and keyboard navigation to make
  terminal UI applications more accessible.
  
  ## Usage
  
  @example_code """
  # Initialize accessibility support in your application
  def init(_) do
    %{
      count: 0,
      accessibility: Raxol.Accessibility.new()
    }
  end
  
  # Make announcements in your update function
  def update(model, :increment) do
    new_count = model.count + 1
    
    # Update model and announce the change
    %{model | 
      count: new_count,
      accessibility: Raxol.Accessibility.announce(
        model.accessibility, 
        "Count incremented to \#{new_count}"
      )
    }
  end
  """
  
  @type t :: map()
  
  @doc """
  Creates a new accessibility state.
  
  ## Options
  
  * `:high_contrast` - Enable high contrast mode (default: false)
  * `:reduced_motion` - Reduce or eliminate animations (default: false)
  * `:screen_reader` - Enable screen reader support (default: true)
  * `:large_text` - Enable large text mode (default: false)
  
  ## Returns
  
  A new accessibility state map.
  
  ## Example
  
  ```elixir
  accessibility = Raxol.Accessibility.new(high_contrast: true)
  ```
  """
  def new(opts \\ []) do
    %{
      high_contrast: Keyword.get(opts, :high_contrast, false),
      reduced_motion: Keyword.get(opts, :reduced_motion, false),
      screen_reader: Keyword.get(opts, :screen_reader, true),
      large_text: Keyword.get(opts, :large_text, false),
      announcements: [],
      element_metadata: %{}
    }
  end
  
  @doc """
  Makes a screen reader announcement.
  
  ## Parameters
  
  * `accessibility` - The current accessibility state
  * `message` - The message to announce
  * `priority` - The announcement priority (:normal, :assertive)
  
  ## Returns
  
  Updated accessibility state.
  
  ## Example
  
  ```elixir
  accessibility = Raxol.Accessibility.announce(
    model.accessibility, 
    "File saved successfully"
  )
  ```
  """
  def announce(accessibility, message, priority \\ :normal) do
    announcement = %{
      message: message,
      priority: priority,
      timestamp: System.monotonic_time(:millisecond)
    }
    
    %{accessibility | announcements: [announcement | accessibility.announcements]}
  end
  
  @doc """
  Sets high contrast mode.
  
  ## Parameters
  
  * `accessibility` - The current accessibility state
  * `enabled` - Whether high contrast mode should be enabled
  
  ## Returns
  
  Updated accessibility state.
  
  ## Example
  
  ```elixir
  accessibility = Raxol.Accessibility.set_high_contrast(
    model.accessibility, 
    true
  )
  ```
  """
  def set_high_contrast(accessibility, enabled) when is_boolean(enabled) do
    %{accessibility | high_contrast: enabled}
  end
  
  @doc """
  Sets reduced motion mode.
  
  ## Parameters
  
  * `accessibility` - The current accessibility state
  * `enabled` - Whether reduced motion mode should be enabled
  
  ## Returns
  
  Updated accessibility state.
  
  ## Example
  
  ```elixir
  accessibility = Raxol.Accessibility.set_reduced_motion(
    model.accessibility, 
    true
  )
  ```
  """
  def set_reduced_motion(accessibility, enabled) when is_boolean(enabled) do
    %{accessibility | reduced_motion: enabled}
  end
  
  @doc """
  Sets large text mode.
  
  ## Parameters
  
  * `accessibility` - The current accessibility state
  * `enabled` - Whether large text mode should be enabled
  
  ## Returns
  
  Updated accessibility state.
  
  ## Example
  
  ```elixir
  accessibility = Raxol.Accessibility.set_large_text(
    model.accessibility, 
    true
  )
  ```
  """
  def set_large_text(accessibility, enabled) when is_boolean(enabled) do
    %{accessibility | large_text: enabled}
  end
  
  @doc """
  Registers metadata for an element to enhance screen reader experience.
  
  ## Parameters
  
  * `accessibility` - The current accessibility state
  * `element_id` - The element identifier (typically focus_key)
  * `metadata` - A map of metadata for the element
  
  ## Returns
  
  Updated accessibility state.
  
  ## Example
  
  ```elixir
  accessibility = Raxol.Accessibility.register_element_metadata(
    model.accessibility,
    "search_button",
    %{
      role: :button,
      label: "Search",
      announce: "Search for documents. Press Enter to activate."
    }
  )
  ```
  """
  def register_element_metadata(accessibility, element_id, metadata) when is_map(metadata) do
    updated_metadata = Map.put(accessibility.element_metadata, element_id, metadata)
    %{accessibility | element_metadata: updated_metadata}
  end
  
  @doc """
  Gets the metadata for an element.
  
  ## Parameters
  
  * `accessibility` - The current accessibility state
  * `element_id` - The element identifier (typically focus_key)
  
  ## Returns
  
  The element metadata or nil if not found.
  
  ## Example
  
  ```elixir
  metadata = Raxol.Accessibility.get_element_metadata(
    model.accessibility,
    "search_button"
  )
  ```
  """
  def get_element_metadata(accessibility, element_id) do
    Map.get(accessibility.element_metadata, element_id)
  end
  
  @doc """
  Gets the color scheme based on current accessibility settings.
  
  ## Parameters
  
  * `accessibility` - The current accessibility state
  
  ## Returns
  
  A color scheme map appropriate for the current settings.
  
  ## Example
  
  ```elixir
  colors = Raxol.Accessibility.get_color_scheme(model.accessibility)
  ```
  """
  def get_color_scheme(accessibility) do
    if accessibility.high_contrast do
      %{
        # High contrast color scheme
        background: :black,
        foreground: :white,
        primary: :yellow,
        secondary: :cyan,
        accent: :magenta,
        error: :red,
        success: :green,
        warning: :yellow,
        info: :cyan
      }
    else
      %{
        # Regular color scheme
        background: :black,
        foreground: :light_white,
        primary: :blue,
        secondary: :cyan,
        accent: :magenta,
        error: :red,
        success: :green,
        warning: :yellow,
        info: :cyan
      }
    end
  end
  
  @doc """
  Processes accessibility state for rendering.
  
  This function should be called just before rendering to handle
  accessibility-related tasks such as screen reader announcements.
  
  ## Parameters
  
  * `accessibility` - The current accessibility state
  
  ## Returns
  
  Updated accessibility state.
  
  ## Example
  
  ```elixir
  def render(model) do
    # Process accessibility state before rendering
    model = %{model | accessibility: Raxol.Accessibility.process(model.accessibility)}
    
    # Render the view
    view do
      # ... UI elements ...
    end
  end
  ```
  """
  def process(accessibility) do
    # Process announcements (in a real implementation, this would
    # interface with a screen reader or other accessibility API)
    process_announcements(accessibility)
    
    # Clear processed announcements
    %{accessibility | announcements: []}
  end
  
  # Private functions
  
  defp process_announcements(%{screen_reader: false} = _accessibility) do
    # Screen reader disabled, do nothing
    :ok
  end
  
  defp process_announcements(accessibility) do
    # Sort announcements by priority and recency
    sorted_announcements = 
      accessibility.announcements
      |> Enum.sort_by(fn %{priority: priority, timestamp: timestamp} ->
        priority_value = if priority == :assertive, do: 0, else: 1
        {priority_value, -timestamp}
      end)
    
    # Actually announce the messages (this is a placeholder)
    # In a real implementation, this would interface with a screen reader
    for %{message: message} <- sorted_announcements do
      # This is just a placeholder for demonstration
      if Mix.env() == :dev do
        IO.puts("SCREEN READER: #{message}")
      end
    end
    
    :ok
  end
end 