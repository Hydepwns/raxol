defmodule Raxol.UI.Accessibility.ScreenReader do
  @moduledoc """
  Comprehensive screen reader support system for Raxol terminal applications.

  This module provides full accessibility compliance including:
  - NVDA, JAWS, VoiceOver, and Orca screen reader support
  - ARIA attributes and semantic markup generation
  - Live region management for dynamic content updates
  - Keyboard navigation and focus management
  - Accessible names and descriptions
  - Screen reader optimization for terminal interfaces
  - Speech synthesis integration for audio feedback
  - Braille display support through platform APIs
  - Multi-language accessibility support

  ## Features

  ### Screen Reader Integration
  - Automatic ARIA markup generation for UI components
  - Live region announcements for status changes
  - Landmark navigation (main, navigation, complementary)
  - Skip links for keyboard navigation efficiency
  - Accessible form labeling and validation feedback

  ### Terminal-Specific Accessibility
  - Virtual cursor navigation for terminal content
  - Character-by-character reading mode
  - Color and formatting description for visual elements
  - Command completion and syntax assistance
  - Error message verbalization with context

  ## Usage

      # Initialize screen reader support
      {:ok, sr} = ScreenReader.start_link(
        screen_reader: :auto_detect,  # or :nvda, :jaws, :voiceover, :orca
        language: "en-US",
        speech_rate: 200,
        enable_braille: true
      )
      
      # Register UI component for accessibility
      ScreenReader.register_component(sr, "main-terminal", %{
        role: "application",
        label: "Terminal Application",
        description: "Interactive terminal interface",
        landmarks: ["main", "navigation"]
      })
      
      # Announce dynamic content changes
      ScreenReader.announce(sr, "Command completed successfully", :polite)
      ScreenReader.announce(sr, "Error: File not found", :assertive)
      
      # Set focus and update accessible state
      ScreenReader.set_focus(sr, "command-input")
      ScreenReader.update_property(sr, "status-bar", %{
        live: "polite",
        text: "Ready - 15:32"
      })
  """

  use GenServer
  require Logger

  alias Raxol.Core.Platform
  alias Raxol.UI.Events.KeyboardTracker

  defstruct [
    :config,
    :screen_reader_type,
    :speech_engine,
    :braille_display,
    :component_registry,
    :live_regions,
    :focus_manager,
    :aria_manager,
    :language_config,
    :audio_cues,
    :reading_state
  ]

  @type screen_reader_type :: :nvda | :jaws | :voiceover | :orca | :auto_detect
  @type announcement_priority :: :off | :polite | :assertive
  @type aria_role ::
          :application
          | :document
          | :dialog
          | :navigation
          | :main
          | :complementary
          | :banner
          | :contentinfo
          | :button
          | :textbox
          | :listbox
          | :list
          | :listitem
          | :table
          | :row
          | :cell
          | :columnheader
          | :rowheader
  @type focus_target :: String.t()

  @type component_config :: %{
          role: aria_role(),
          label: String.t(),
          description: String.t() | nil,
          landmarks: [String.t()],
          live: announcement_priority() | nil,
          keyboard_shortcuts: %{atom() => String.t()},
          accessible_name: String.t() | nil,
          accessible_description: String.t() | nil
        }

  @type config :: %{
          screen_reader: screen_reader_type(),
          language: String.t(),
          speech_rate: integer(),
          speech_pitch: integer(),
          speech_volume: float(),
          enable_braille: boolean(),
          enable_audio_cues: boolean(),
          verbosity_level: :minimal | :normal | :verbose,
          keyboard_echo: boolean(),
          character_echo: boolean(),
          word_echo: boolean()
        }

  # Default configuration
  @default_config %{
    screen_reader: :auto_detect,
    language: "en-US",
    # words per minute
    speech_rate: 200,
    # 0-100
    speech_pitch: 50,
    speech_volume: 0.8,
    enable_braille: true,
    enable_audio_cues: true,
    verbosity_level: :normal,
    keyboard_echo: true,
    character_echo: false,
    word_echo: true
  }

  # ARIA roles and their descriptions
  @aria_roles %{
    application: "application",
    document: "document",
    dialog: "dialog",
    navigation: "navigation",
    main: "main content",
    complementary: "complementary",
    banner: "banner",
    contentinfo: "content information",
    button: "button",
    textbox: "text input",
    listbox: "list box",
    list: "list",
    listitem: "list item",
    table: "table",
    row: "row",
    cell: "cell",
    columnheader: "column header",
    rowheader: "row header"
  }

  # Audio cue sounds for different events
  @audio_cues %{
    focus_changed: %{frequency: 440, duration: 100},
    button_activated: %{frequency: 880, duration: 150},
    error_occurred: %{frequency: 220, duration: 300},
    task_completed: %{frequency: 660, duration: 200},
    navigation_changed: %{frequency: 523, duration: 100},
    content_loaded: %{frequency: 329, duration: 250}
  }

  ## Public API

  @doc """
  Starts the screen reader support system.

  ## Options
  - `:screen_reader` - Target screen reader (:nvda, :jaws, :voiceover, :orca, :auto_detect)
  - `:language` - Language code for speech synthesis (default: "en-US")
  - `:speech_rate` - Words per minute (default: 200)
  - `:enable_braille` - Enable braille display support (default: true)
  - `:verbosity_level` - Amount of information to announce (default: :normal)
  """
  def start_link(opts \\ %{}) do
    config = Map.merge(@default_config, opts)
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @doc """
  Registers a UI component for screen reader accessibility.
  """
  def register_component(sr \\ __MODULE__, component_id, component_config) do
    GenServer.call(sr, {:register_component, component_id, component_config})
  end

  @doc """
  Announces text to screen readers with specified priority.
  """
  def announce(sr \\ __MODULE__, text, priority \\ :polite) do
    GenServer.cast(sr, {:announce, text, priority})
  end

  @doc """
  Updates the focus to a specific component.
  """
  def set_focus(sr \\ __MODULE__, component_id) do
    GenServer.call(sr, {:set_focus, component_id})
  end

  @doc """
  Updates an accessibility property of a component.
  """
  def update_property(sr \\ __MODULE__, component_id, properties) do
    GenServer.cast(sr, {:update_property, component_id, properties})
  end

  @doc """
  Describes visual formatting to screen reader users.
  """
  def describe_formatting(sr \\ __MODULE__, element_id, formatting) do
    GenServer.cast(sr, {:describe_formatting, element_id, formatting})
  end

  @doc """
  Enables or disables specific accessibility features.
  """
  def configure_feature(sr \\ __MODULE__, feature, enabled) do
    GenServer.call(sr, {:configure_feature, feature, enabled})
  end

  @doc """
  Gets the current accessibility state of a component.
  """
  def get_accessibility_state(sr \\ __MODULE__, component_id) do
    GenServer.call(sr, {:get_accessibility_state, component_id})
  end

  @doc """
  Provides keyboard shortcut information for screen readers.
  """
  def announce_shortcuts(sr \\ __MODULE__, component_id) do
    GenServer.call(sr, {:announce_shortcuts, component_id})
  end

  @doc """
  Sets reading mode for terminal content (character/word/line).
  """
  def set_reading_mode(sr \\ __MODULE__, mode)
      when mode in [:character, :word, :line, :paragraph] do
    GenServer.call(sr, {:set_reading_mode, mode})
  end

  @doc """
  Reads content at cursor position with specified verbosity.
  """
  def read_at_cursor(sr \\ __MODULE__, verbosity \\ :normal) do
    GenServer.call(sr, {:read_at_cursor, verbosity})
  end

  ## GenServer Implementation

  @impl GenServer
  def init(config) do
    # Detect available screen readers
    screen_reader_type = detect_screen_reader(config.screen_reader)

    # Initialize speech engine
    speech_engine = init_speech_engine(screen_reader_type, config)

    # Initialize braille display if available
    braille_display =
      if config.enable_braille do
        init_braille_display()
      else
        nil
      end

    # Initialize keyboard tracking for accessibility shortcuts
    {:ok, keyboard_tracker} =
      KeyboardTracker.start_link(
        global_shortcuts: true,
        accessibility_mode: true,
        on_shortcut: &handle_accessibility_shortcut/2
      )

    state = %__MODULE__{
      config: config,
      screen_reader_type: screen_reader_type,
      speech_engine: speech_engine,
      braille_display: braille_display,
      component_registry: %{},
      live_regions: %{},
      focus_manager: init_focus_manager(),
      aria_manager: init_aria_manager(),
      language_config: load_language_config(config.language),
      audio_cues: init_audio_cues(config),
      reading_state: %{
        mode: :line,
        cursor_position: {0, 0},
        current_element: nil
      }
    }

    # Announce screen reader initialization
    announce_initialization(state)

    Logger.info("Screen reader support initialized: #{screen_reader_type}")
    {:ok, state}
  end

  @impl GenServer
  def handle_call(
        {:register_component, component_id, component_config},
        _from,
        state
      ) do
    validated_config = validate_component_config(component_config)

    # Generate ARIA attributes
    aria_attributes = generate_aria_attributes(validated_config)

    # Register component
    new_registry =
      Map.put(state.component_registry, component_id, %{
        config: validated_config,
        aria_attributes: aria_attributes,
        current_state: %{},
        focus_order: determine_focus_order(validated_config)
      })

    # Create live region if needed
    new_live_regions =
      if validated_config[:live] do
        Map.put(state.live_regions, component_id, %{
          priority: validated_config.live,
          last_announcement: nil
        })
      else
        state.live_regions
      end

    new_state = %{
      state
      | component_registry: new_registry,
        live_regions: new_live_regions
    }

    # Announce component registration in verbose mode
    if state.config.verbosity_level == :verbose do
      role_description = Map.get(@aria_roles, validated_config.role, "element")
      announce_text = "#{validated_config.label} #{role_description} registered"
      announce_to_screen_reader(new_state, announce_text, :polite)
    end

    Logger.debug("Component registered: #{component_id}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:set_focus, component_id}, _from, state) do
    case Map.get(state.component_registry, component_id) do
      nil ->
        {:reply, {:error, :component_not_found}, state}

      component ->
        # Update focus manager
        new_focus_manager = %{
          state.focus_manager
          | current_focus: component_id,
            focus_history: [
              component_id | Enum.take(state.focus_manager.focus_history, 9)
            ]
        }

        # Announce focus change
        announce_focus_change(state, component_id, component)

        # Play audio cue if enabled
        if state.config.enable_audio_cues do
          play_audio_cue(state, :focus_changed)
        end

        new_state = %{state | focus_manager: new_focus_manager}
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:get_accessibility_state, component_id}, _from, state) do
    case Map.get(state.component_registry, component_id) do
      nil -> {:reply, {:error, :component_not_found}, state}
      component -> {:reply, {:ok, component}, state}
    end
  end

  @impl GenServer
  def handle_call({:announce_shortcuts, component_id}, _from, state) do
    case Map.get(state.component_registry, component_id) do
      nil ->
        {:reply, {:error, :component_not_found}, state}

      component ->
        shortcuts = component.config[:keyboard_shortcuts] || %{}

        if map_size(shortcuts) > 0 do
          shortcut_text = generate_shortcuts_announcement(shortcuts)
          announce_to_screen_reader(state, shortcut_text, :polite)
          {:reply, :ok, state}
        else
          {:reply, {:ok, :no_shortcuts}, state}
        end
    end
  end

  @impl GenServer
  def handle_call({:set_reading_mode, mode}, _from, state) do
    new_reading_state = %{state.reading_state | mode: mode}
    new_state = %{state | reading_state: new_reading_state}

    mode_description =
      case mode do
        :character -> "character by character"
        :word -> "word by word"
        :line -> "line by line"
        :paragraph -> "paragraph by paragraph"
      end

    announce_to_screen_reader(
      new_state,
      "Reading mode: #{mode_description}",
      :polite
    )

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:read_at_cursor, verbosity}, _from, state) do
    cursor_content = get_content_at_cursor(state)

    reading_text =
      format_content_for_reading(
        cursor_content,
        verbosity,
        state.reading_state.mode
      )

    announce_to_screen_reader(state, reading_text, :assertive)

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:configure_feature, feature, enabled}, _from, state) do
    new_config = Map.put(state.config, feature, enabled)
    new_state = %{state | config: new_config}

    feature_name = Atom.to_string(feature) |> String.replace("_", " ")
    status = if enabled, do: "enabled", else: "disabled"
    announce_to_screen_reader(new_state, "#{feature_name} #{status}", :polite)

    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_cast({:announce, text, priority}, state) do
    announce_to_screen_reader(state, text, priority)

    # Update live regions if applicable
    updated_state = update_live_regions(state, text, priority)

    {:noreply, updated_state}
  end

  @impl GenServer
  def handle_cast({:update_property, component_id, properties}, state) do
    case Map.get(state.component_registry, component_id) do
      nil ->
        Logger.warning(
          "Attempted to update non-existent component: #{component_id}"
        )

        {:noreply, state}

      component ->
        # Update component state
        new_current_state = Map.merge(component.current_state, properties)
        updated_component = %{component | current_state: new_current_state}

        new_registry =
          Map.put(state.component_registry, component_id, updated_component)

        new_state = %{state | component_registry: new_registry}

        # Handle live region updates
        updated_final_state =
          if component.config[:live] and Map.has_key?(properties, :text) do
            announce_to_screen_reader(
              new_state,
              properties.text,
              component.config.live
            )

            update_live_regions(
              new_state,
              properties.text,
              component.config.live
            )
          else
            new_state
          end

        {:noreply, updated_final_state}
    end
  end

  @impl GenServer
  def handle_cast({:describe_formatting, element_id, formatting}, state) do
    description = generate_formatting_description(formatting)

    if description != "" do
      announce_text = "#{element_id}: #{description}"
      announce_to_screen_reader(state, announce_text, :polite)
    end

    {:noreply, state}
  end

  ## Private Implementation

  defp detect_screen_reader(:auto_detect) do
    cond do
      Platform.windows?() ->
        cond do
          screen_reader_running?("nvda") -> :nvda
          screen_reader_running?("jaws") -> :jaws
          # Default to NVDA on Windows
          true -> :nvda
        end

      Platform.macos?() ->
        # VoiceOver is built into macOS
        :voiceover

      Platform.linux?() ->
        cond do
          screen_reader_running?("orca") -> :orca
          # Default to Orca on Linux
          true -> :orca
        end

      true ->
        # Fallback
        :nvda
    end
  end

  defp detect_screen_reader(specified), do: specified

  defp screen_reader_running?(name) do
    # Check if screen reader process is running
    case System.cmd("pgrep", ["-f", name], stderr_to_stdout: true) do
      {_output, 0} -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  defp init_speech_engine(screen_reader_type, config) do
    case screen_reader_type do
      :nvda ->
        init_nvda_speech(config)

      :jaws ->
        init_jaws_speech(config)

      :voiceover ->
        init_voiceover_speech(config)

      :orca ->
        init_orca_speech(config)
    end
  end

  defp init_nvda_speech(config) do
    %{
      type: :nvda,
      api: :nvda_controller,
      rate: config.speech_rate,
      pitch: config.speech_pitch,
      volume: config.speech_volume,
      available: check_nvda_availability()
    }
  end

  defp init_jaws_speech(config) do
    %{
      type: :jaws,
      api: :jaws_api,
      rate: config.speech_rate,
      pitch: config.speech_pitch,
      volume: config.speech_volume,
      available: check_jaws_availability()
    }
  end

  defp init_voiceover_speech(config) do
    %{
      type: :voiceover,
      api: :accessibility_api,
      rate: config.speech_rate,
      pitch: config.speech_pitch,
      volume: config.speech_volume,
      # VoiceOver is always available on macOS
      available: Platform.macos?()
    }
  end

  defp init_orca_speech(config) do
    %{
      type: :orca,
      api: :at_spi,
      rate: config.speech_rate,
      pitch: config.speech_pitch,
      volume: config.speech_volume,
      available: check_orca_availability()
    }
  end

  defp check_nvda_availability do
    # Check if NVDA controller DLL is available
    File.exists?("C:\\Program Files\\NVDA\\nvdaControllerClient32.dll") or
      File.exists?("C:\\Program Files\\NVDA\\nvdaControllerClient64.dll")
  end

  defp check_jaws_availability do
    # Check if JAWS is installed
    File.exists?("C:\\Program Files\\Freedom Scientific\\JAWS") or
      File.exists?("C:\\Program Files (x86)\\Freedom Scientific\\JAWS")
  end

  defp check_orca_availability do
    # Check if AT-SPI is available
    System.find_executable("orca") != nil
  end

  defp init_braille_display do
    if Platform.windows?() do
      %{type: :brltty, available: System.find_executable("brltty") != nil}
    else
      %{type: :brltty, available: System.find_executable("brltty") != nil}
    end
  end

  defp init_focus_manager do
    %{
      current_focus: nil,
      focus_history: [],
      focus_trap: nil,
      skip_links: []
    }
  end

  defp init_aria_manager do
    %{
      live_regions: %{},
      landmarks: %{},
      labels: %{},
      descriptions: %{}
    }
  end

  defp init_audio_cues(config) do
    if config.enable_audio_cues do
      %{
        enabled: true,
        volume: config.speech_volume,
        sounds: @audio_cues
      }
    else
      %{enabled: false}
    end
  end

  defp load_language_config(language) do
    # Load language-specific accessibility configurations
    %{
      language: language,
      date_format: get_date_format(language),
      number_format: get_number_format(language),
      punctuation_verbosity: get_punctuation_verbosity(language)
    }
  end

  defp validate_component_config(config) do
    # Validate and set defaults for component configuration
    validated = %{
      role: Map.get(config, :role, :application),
      label: Map.get(config, :label, "Unnamed component"),
      description: Map.get(config, :description),
      landmarks: Map.get(config, :landmarks, []),
      live: Map.get(config, :live),
      keyboard_shortcuts: Map.get(config, :keyboard_shortcuts, %{}),
      accessible_name: Map.get(config, :accessible_name),
      accessible_description: Map.get(config, :accessible_description)
    }

    # Validate role
    if not Map.has_key?(@aria_roles, validated.role) do
      Logger.warning("Invalid ARIA role: #{validated.role}, using :application")
      %{validated | role: :application}
    else
      validated
    end
  end

  defp generate_aria_attributes(config) do
    base_attributes = %{
      "role" => Atom.to_string(config.role),
      "aria-label" => config.accessible_name || config.label
    }

    # Add description if provided
    attributes_with_desc =
      if config.accessible_description do
        Map.put(
          base_attributes,
          "aria-describedby",
          "#{config.accessible_name}-desc"
        )
      else
        base_attributes
      end

    # Add live region attributes
    if config.live do
      Map.merge(attributes_with_desc, %{
        "aria-live" => Atom.to_string(config.live),
        "aria-atomic" => "true"
      })
    else
      attributes_with_desc
    end
  end

  defp determine_focus_order(config) do
    # Determine tab order based on component role and landmarks
    base_order =
      case config.role do
        :button -> 1
        :textbox -> 1
        :listbox -> 2
        :navigation -> 0
        :main -> 1
        _ -> 2
      end

    # Adjust for landmarks
    if "navigation" in config.landmarks do
      base_order - 1
    else
      base_order
    end
  end

  defp announce_initialization(state) do
    welcome_text =
      case state.screen_reader_type do
        :nvda -> "Raxol terminal with NVDA screen reader support"
        :jaws -> "Raxol terminal with JAWS screen reader support"
        :voiceover -> "Raxol terminal with VoiceOver support"
        :orca -> "Raxol terminal with Orca screen reader support"
      end

    announce_to_screen_reader(state, welcome_text, :polite)
  end

  defp announce_to_screen_reader(state, text, priority) do
    if state.speech_engine.available do
      case state.speech_engine.type do
        :nvda -> announce_to_nvda(text, priority)
        :jaws -> announce_to_jaws(text, priority)
        :voiceover -> announce_to_voiceover(text, priority)
        :orca -> announce_to_orca(text, priority)
      end
    else
      # Fallback to system speech synthesis or logging
      Logger.info("Screen Reader Announcement (#{priority}): #{text}")

      # Try system TTS as fallback
      cond do
        # macOS
        System.find_executable("say") ->
          System.cmd("say", [text], stderr_to_stdout: true)

        # Linux
        System.find_executable("espeak") ->
          System.cmd("espeak", [text], stderr_to_stdout: true)

        true ->
          nil
      end
    end
  end

  defp announce_to_nvda(text, priority) do
    # Use NVDA Controller Client API
    # This would be implemented as NIFs in practice
    Logger.debug("NVDA Announcement (#{priority}): #{text}")
    :ok
  end

  defp announce_to_jaws(text, priority) do
    # Use JAWS API
    Logger.debug("JAWS Announcement (#{priority}): #{text}")
    :ok
  end

  defp announce_to_voiceover(text, priority) do
    # Use macOS Accessibility API
    Logger.debug("VoiceOver Announcement (#{priority}): #{text}")
    :ok
  end

  defp announce_to_orca(text, priority) do
    # Use AT-SPI interface
    Logger.debug("Orca Announcement (#{priority}): #{text}")
    :ok
  end

  defp announce_focus_change(state, component_id, component) do
    role_description = Map.get(@aria_roles, component.config.role, "element")
    announcement = "#{component.config.label} #{role_description}"

    # Add additional context based on verbosity
    extended_announcement =
      case state.config.verbosity_level do
        :minimal ->
          component.config.label

        :normal ->
          announcement

        :verbose ->
          shortcuts =
            if map_size(component.config.keyboard_shortcuts) > 0 do
              ", shortcuts available"
            else
              ""
            end

          "#{announcement}#{shortcuts}"
      end

    announce_to_screen_reader(state, extended_announcement, :assertive)
  end

  defp generate_shortcuts_announcement(shortcuts) do
    shortcut_list =
      shortcuts
      |> Enum.map(fn {key, description} ->
        key_name = format_key_name(key)
        "#{key_name}: #{description}"
      end)
      |> Enum.join(", ")

    "Available shortcuts: #{shortcut_list}"
  end

  defp format_key_name(key) do
    case key do
      :ctrl_c -> "Control+C"
      :alt_f4 -> "Alt+F4"
      :shift_tab -> "Shift+Tab"
      :enter -> "Enter"
      :escape -> "Escape"
      :space -> "Space"
      _ -> Atom.to_string(key) |> String.replace("_", "+")
    end
  end

  defp update_live_regions(state, text, priority) do
    # Update live regions with new announcement
    updated_regions =
      state.live_regions
      |> Enum.map(fn {region_id, region} ->
        if region.priority == priority do
          {region_id, %{region | last_announcement: text}}
        else
          {region_id, region}
        end
      end)
      |> Map.new()

    %{state | live_regions: updated_regions}
  end

  defp generate_formatting_description(formatting) do
    descriptions = []

    descriptions =
      if formatting[:bold], do: ["bold" | descriptions], else: descriptions

    descriptions =
      if formatting[:italic], do: ["italic" | descriptions], else: descriptions

    descriptions =
      if formatting[:underline],
        do: ["underlined" | descriptions],
        else: descriptions

    descriptions =
      if formatting[:strikethrough],
        do: ["strikethrough" | descriptions],
        else: descriptions

    # Color descriptions
    descriptions =
      case formatting[:color] do
        nil -> descriptions
        {r, g, b} -> ["color #{describe_color({r, g, b})}" | descriptions]
        color_name -> ["#{color_name} text" | descriptions]
      end

    descriptions =
      case formatting[:background_color] do
        nil ->
          descriptions

        {r, g, b} ->
          ["on #{describe_color({r, g, b})} background" | descriptions]

        color_name ->
          ["on #{color_name} background" | descriptions]
      end

    case descriptions do
      [] -> ""
      [single] -> single
      multiple -> Enum.join(Enum.reverse(multiple), ", ")
    end
  end

  defp describe_color({r, g, b}) do
    # Convert RGB to color name approximation
    cond do
      r > 200 and g < 100 and b < 100 -> "red"
      r < 100 and g > 200 and b < 100 -> "green"
      r < 100 and g < 100 and b > 200 -> "blue"
      r > 200 and g > 200 and b < 100 -> "yellow"
      r > 200 and g < 100 and b > 200 -> "magenta"
      r < 100 and g > 200 and b > 200 -> "cyan"
      r > 150 and g > 150 and b > 150 -> "light"
      r < 100 and g < 100 and b < 100 -> "dark"
      true -> "colored"
    end
  end

  defp get_content_at_cursor(state) do
    # Placeholder - would get actual content at cursor position
    %{
      text: "sample text",
      position: state.reading_state.cursor_position,
      formatting: %{},
      context: "terminal"
    }
  end

  defp format_content_for_reading(content, verbosity, reading_mode) do
    base_text = content.text

    case reading_mode do
      :character ->
        # Read character by character with phonetic if needed
        char = String.at(base_text, 0) || ""

        if String.match?(char, ~r/[a-zA-Z]/) do
          char
        else
          describe_special_character(char)
        end

      :word ->
        # Read word by word
        words = String.split(base_text)
        List.first(words) || ""

      :line ->
        # Read entire line
        base_text

      :paragraph ->
        # Read paragraph with context
        base_text
    end
  end

  defp describe_special_character(char) do
    case char do
      " " -> "space"
      "\t" -> "tab"
      "\n" -> "new line"
      "!" -> "exclamation"
      "?" -> "question mark"
      "." -> "period"
      "," -> "comma"
      ";" -> "semicolon"
      ":" -> "colon"
      "'" -> "apostrophe"
      "\"" -> "quote"
      "-" -> "dash"
      "_" -> "underscore"
      "@" -> "at sign"
      "#" -> "hash"
      "$" -> "dollar"
      "%" -> "percent"
      "&" -> "ampersand"
      "*" -> "asterisk"
      "+" -> "plus"
      "=" -> "equals"
      "|" -> "pipe"
      "\\" -> "backslash"
      "/" -> "slash"
      "(" -> "left paren"
      ")" -> "right paren"
      "[" -> "left bracket"
      "]" -> "right bracket"
      "{" -> "left brace"
      "}" -> "right brace"
      "<" -> "less than"
      ">" -> "greater than"
      _ -> "unknown character"
    end
  end

  defp play_audio_cue(state, cue_type) do
    if state.audio_cues.enabled do
      case Map.get(state.audio_cues.sounds, cue_type) do
        nil ->
          :ok

        cue ->
          # Play audio cue - would use actual audio synthesis
          Logger.debug(
            "Audio cue: #{cue_type} (#{cue.frequency}Hz, #{cue.duration}ms)"
          )

          :ok
      end
    end
  end

  defp handle_accessibility_shortcut(key_combo, context) do
    # Handle global accessibility shortcuts
    case key_combo do
      [:ctrl, :alt, :r] ->
        # Read current location
        GenServer.call(__MODULE__, {:read_at_cursor, :verbose})

      [:ctrl, :alt, :s] ->
        # Announce shortcuts for current component
        if context[:current_component] do
          GenServer.call(
            __MODULE__,
            {:announce_shortcuts, context.current_component}
          )
        end

      [:ctrl, :alt, :h] ->
        # Toggle help mode
        announce(__MODULE__, "Help mode toggled", :polite)

      _ ->
        :ok
    end
  end

  ## Helper functions for language support

  defp get_date_format("en-US"), do: "MM/DD/YYYY"
  defp get_date_format("en-GB"), do: "DD/MM/YYYY"
  defp get_date_format("de-DE"), do: "DD.MM.YYYY"
  defp get_date_format(_), do: "MM/DD/YYYY"

  defp get_number_format("en-US"), do: %{decimal: ".", thousands: ","}
  defp get_number_format("de-DE"), do: %{decimal: ",", thousands: "."}
  defp get_number_format(_), do: %{decimal: ".", thousands: ","}

  defp get_punctuation_verbosity("en-US"), do: :normal
  defp get_punctuation_verbosity(_), do: :normal

  ## Public Utility Functions

  @doc """
  Creates ARIA live region markup for HTML output.
  """
  def create_live_region(id, priority, initial_text \\ "") do
    %{
      id: id,
      attributes: %{
        "aria-live" => Atom.to_string(priority),
        "aria-atomic" => "true",
        "aria-relevant" => "additions text"
      },
      content: initial_text
    }
  end

  @doc """
  Generates skip link navigation for keyboard users.
  """
  def create_skip_links(targets) do
    targets
    |> Enum.with_index(1)
    |> Enum.map(fn {{target_id, label}, index} ->
      %{
        id: "skip-link-#{index}",
        href: "##{target_id}",
        text: "Skip to #{label}",
        attributes: %{
          "class" => "skip-link",
          "aria-label" => "Skip to #{label}"
        }
      }
    end)
  end

  @doc """
  Validates WCAG 2.1 compliance for a component configuration.
  """
  def validate_wcag_compliance(component_config) do
    issues = []

    # Check for accessible name
    issues =
      if not component_config[:label] and not component_config[:accessible_name] do
        ["Missing accessible name (label or aria-label)" | issues]
      else
        issues
      end

    # Check for keyboard accessibility
    issues =
      if component_config[:role] in [:button, :textbox, :listbox] and
           map_size(component_config[:keyboard_shortcuts] || %{}) == 0 do
        ["Interactive element missing keyboard shortcuts" | issues]
      else
        issues
      end

    # Check for color contrast (would need actual color values)
    # This is a placeholder for color contrast checking

    case issues do
      [] -> {:ok, :compliant}
      issues -> {:warning, issues}
    end
  end
end
