defmodule Raxol.Plugins.Examples.RainbowThemePlugin do
  @moduledoc """
  Example plugin demonstrating the Plugin System v2.0 capabilities.

  This plugin adds a rainbow theme to the terminal with animated color transitions.
  It showcases:
  - Plugin manifest structure
  - Hook implementations
  - Hot-reload support
  - Configuration management
  - Event handling
  """

  @behaviour Raxol.Plugins.Plugin

  # Plugin manifest
  def manifest do
    %{
      name: "rainbow_theme",
      version: "1.0.0",
      description: "Adds rainbow color themes with animated transitions",
      author: "Raxol Team",
      license: "MIT",

      # Dependencies
      dependencies: %{
        "core_themes" => "~> 1.0"
      },

      # Required Raxol version
      raxol_version: "~> 1.5",

      # Plugin capabilities
      capabilities: [:themes, :animations, :commands],

      # Entry point
      main_module: __MODULE__,

      # Hooks this plugin implements
      hooks: [:on_load, :on_unload, :on_command, :on_theme_change],

      # Configuration schema
      config_schema: %{
        animation_speed: {:integer, default: 100},
        color_palette:
          {:list,
           default: [:red, :orange, :yellow, :green, :blue, :indigo, :violet]},
        auto_rotate: {:boolean, default: true},
        rotation_interval: {:integer, default: 5000}
      }
    }
  end

  # Plugin state
  defmodule State do
    defstruct [
      :config,
      :current_index,
      :animation_timer,
      :palette,
      :active
    ]
  end

  @impl true
  def init(config) do
    state = %State{
      config: config,
      current_index: 0,
      animation_timer: nil,
      palette: build_palette(config.color_palette),
      active: false
    }

    {:ok, state}
  end

  @impl true
  def get_api_version, do: "1.5.4"

  @impl true
  def get_dependencies do
    [
      %{name: "core_themes", version: "~> 1.0", optional: false}
    ]
  end

  @impl true
  def cleanup(state) do
    stop_animation(state)
    unregister_commands()
    :ok
  end

  @impl true
  def handle_input(state, _input), do: {:ok, state}

  @impl true
  def handle_output(state, _output), do: {:ok, state}

  @impl true
  def handle_mouse(state, _event, _emulator_state), do: {:ok, state}

  @impl true
  def handle_resize(state, _width, _height), do: {:ok, state}

  @impl true
  def handle_render(state), do: {:ok, state}

  @impl true
  def handle_cells(_cell, _emulator_state, state), do: {:cont, state}

  def on_load(state) do
    # Register commands
    register_commands()

    # Start animation if auto_rotate is enabled
    state =
      if state.config.auto_rotate do
        start_animation(state)
      else
        state
      end

    {:ok, %{state | active: true}}
  end

  def on_unload(state) do
    # Stop animation
    state = stop_animation(state)

    # Unregister commands
    unregister_commands()

    {:ok, %{state | active: false}}
  end

  def on_command("rainbow", args, state) do
    case args do
      ["start"] ->
        state = start_animation(state)
        {:ok, "Rainbow animation started", state}

      ["stop"] ->
        state = stop_animation(state)
        {:ok, "Rainbow animation stopped", state}

      ["speed", speed_str] ->
        case Integer.parse(speed_str) do
          {speed, _} when speed > 0 ->
            new_config = %{state.config | animation_speed: speed}
            state = %{state | config: new_config}

            state =
              if state.animation_timer,
                do: restart_animation(state),
                else: state

            {:ok, "Animation speed set to #{speed}ms", state}

          _ ->
            {:error, "Invalid speed value", state}
        end

      ["palette" | colors] ->
        palette_atoms = Enum.map(colors, &String.to_atom/1)
        new_config = %{state.config | color_palette: palette_atoms}

        state = %{
          state
          | config: new_config,
            palette: build_palette(palette_atoms)
        }

        {:ok, "Color palette updated", state}

      ["next"] ->
        state = rotate_color(state)
        {:ok, "Rotated to next color", state}

      _ ->
        help_text = """
        Rainbow Theme Plugin Commands:
        - rainbow start              Start color animation
        - rainbow stop               Stop color animation
        - rainbow speed <ms>         Set animation speed
        - rainbow palette <colors>   Set color palette
        - rainbow next              Rotate to next color
        """

        {:ok, help_text, state}
    end
  end

  def on_theme_change(theme_name, state) do
    # React to theme changes from other plugins
    if theme_name == "rainbow" do
      state = start_animation(state)
      {:ok, state}
    else
      state = stop_animation(state)
      {:ok, state}
    end
  end

  def handle_event({:timer, :rotate}, state) do
    state = rotate_color(state)
    schedule_next_rotation(state)
    {:ok, state}
  end

  def handle_event(_event, state) do
    {:ok, state}
  end

  # Hot-reload support
  def migrate_state(old_version, old_state, new_config) do
    # Handle state migration between versions
    case {old_version, manifest().version} do
      {"0.9.0", "1.0.0"} ->
        # Migrate from 0.9.0 to 1.0.0
        new_state = %State{
          config: new_config,
          current_index: Map.get(old_state, :current_index, 0),
          animation_timer: Map.get(old_state, :animation_timer),
          palette: build_palette(new_config.color_palette),
          active: Map.get(old_state, :active, false)
        }

        {:ok, new_state}

      _ ->
        # Default migration: reinitialize
        init(new_config)
    end
  end

  # Private functions

  defp register_commands do
    # Register with command system
    :ok = Raxol.Commands.register("rainbow", __MODULE__)
  end

  defp unregister_commands do
    # Unregister from command system
    :ok = Raxol.Commands.unregister("rainbow")
  end

  defp build_palette(color_list) do
    color_list
    |> Enum.map(&color_to_rgb/1)
    |> Enum.with_index()
    |> Map.new(fn {color, index} -> {index, color} end)
  end

  defp color_to_rgb(color) do
    case color do
      :red -> {255, 0, 0}
      :orange -> {255, 165, 0}
      :yellow -> {255, 255, 0}
      :green -> {0, 255, 0}
      :blue -> {0, 0, 255}
      :indigo -> {75, 0, 130}
      :violet -> {238, 130, 238}
      # Default gray
      _ -> {128, 128, 128}
    end
  end

  defp start_animation(state) do
    # Ensure no duplicate timers
    state = stop_animation(state)

    timer_ref = schedule_next_rotation(state)
    %{state | animation_timer: timer_ref}
  end

  defp stop_animation(state) do
    if state.animation_timer do
      Process.cancel_timer(state.animation_timer)
    end

    %{state | animation_timer: nil}
  end

  defp restart_animation(state) do
    state
    |> stop_animation()
    |> start_animation()
  end

  defp schedule_next_rotation(state) do
    Process.send_after(self(), {:timer, :rotate}, state.config.animation_speed)
  end

  defp rotate_color(state) do
    next_index = rem(state.current_index + 1, map_size(state.palette))
    color = Map.get(state.palette, next_index)

    # Apply the color to the terminal
    apply_color_theme(color)

    %{state | current_index: next_index}
  end

  defp apply_color_theme({r, g, b}) do
    # Create a theme with the current rainbow color
    theme = %{
      background: :default,
      foreground: {r, g, b},
      cursor: {r, g, b},
      # With alpha
      selection: {r, g, b, 64}
    }

    # Apply through the theme system
    :ok = Raxol.Themes.apply_theme(theme)
  end
end

defmodule Raxol.Plugins.Examples.RainbowThemePlugin.Tests do
  @moduledoc """
  Example tests for the Rainbow Theme Plugin.
  Demonstrates how to test plugins with the new system.
  """

  use ExUnit.Case, async: true

  alias Raxol.Plugins.Examples.RainbowThemePlugin

  setup do
    # Create a test configuration
    config = %{
      animation_speed: 50,
      color_palette: [:red, :green, :blue],
      auto_rotate: false,
      rotation_interval: 100
    }

    {:ok, state} = RainbowThemePlugin.init(config)
    %{state: state}
  end

  describe "plugin lifecycle" do
    test "initializes with correct state", %{state: state} do
      assert state.current_index == 0
      assert state.animation_timer == nil
      assert map_size(state.palette) == 3
      assert state.active == false
    end

    test "loads and activates plugin", %{state: state} do
      {:ok, loaded_state} = RainbowThemePlugin.on_load(state)
      assert loaded_state.active == true
    end

    test "unloads and deactivates plugin", %{state: state} do
      {:ok, loaded_state} = RainbowThemePlugin.on_load(state)
      {:ok, unloaded_state} = RainbowThemePlugin.on_unload(loaded_state)
      assert unloaded_state.active == false
    end
  end

  describe "commands" do
    test "starts animation", %{state: state} do
      {:ok, message, new_state} =
        RainbowThemePlugin.on_command("rainbow", ["start"], state)

      assert message == "Rainbow animation started"
      assert new_state.animation_timer != nil
    end

    test "stops animation", %{state: state} do
      {:ok, _, started_state} =
        RainbowThemePlugin.on_command("rainbow", ["start"], state)

      {:ok, message, stopped_state} =
        RainbowThemePlugin.on_command("rainbow", ["stop"], started_state)

      assert message == "Rainbow animation stopped"
      assert stopped_state.animation_timer == nil
    end

    test "changes animation speed", %{state: state} do
      {:ok, message, new_state} =
        RainbowThemePlugin.on_command("rainbow", ["speed", "200"], state)

      assert message == "Animation speed set to 200ms"
      assert new_state.config.animation_speed == 200
    end

    test "updates color palette", %{state: state} do
      {:ok, message, new_state} =
        RainbowThemePlugin.on_command(
          "rainbow",
          ["palette", "red", "blue"],
          state
        )

      assert message == "Color palette updated"
      assert new_state.config.color_palette == [:red, :blue]
      assert map_size(new_state.palette) == 2
    end
  end

  describe "state migration" do
    test "migrates from 0.9.0 to 1.0.0" do
      old_state = %{current_index: 5, active: true}

      new_config = %{
        animation_speed: 100,
        color_palette: [:red, :green],
        auto_rotate: true,
        rotation_interval: 1000
      }

      {:ok, migrated} =
        RainbowThemePlugin.migrate_state("0.9.0", old_state, new_config)

      assert migrated.current_index == 5
      assert migrated.active == true
      assert migrated.config == new_config
    end
  end
end
