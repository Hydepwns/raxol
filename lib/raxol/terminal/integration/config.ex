defmodule Raxol.Terminal.Integration.Config do
  @moduledoc '''
  Manages configuration for the terminal integration.
  '''

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.{
    Config,
    Buffer.UnifiedManager,
    Scroll.UnifiedScroll,
    Render.UnifiedRenderer
  }

  alias Raxol.Terminal.Integration.State

  @type t :: %__MODULE__{
          behavior: map(),
          memory_limit: integer(),
          rendering: map()
        }

  defstruct [
    :behavior,
    :memory_limit,
    :rendering
  ]

  @doc '''
  Returns the default configuration.
  '''
  def default_config do
    %__MODULE__{
      behavior: %{
        scrollback_limit: 1000,
        enable_command_history: true
      },
      # 50 MB
      memory_limit: 50 * 1024 * 1024,
      rendering: %{
        fps: 60,
        theme: %{
          foreground: :white,
          background: :black
        },
        font_settings: %{
          size: 12
        }
      }
    }
  end

  @doc '''
  Updates the terminal configuration.

  Merges the provided `opts` into the current configuration and validates
  the result before applying.
  '''
  def update_config(%State{} = state, opts) do
    # Merge the new options into the current config
    updated_config = Config.merge_opts(state.config, opts)

    # Validate the updated configuration
    case validate_config(updated_config) do
      :ok ->
        # Apply the validated, merged config
        state = apply_config_changes(state, updated_config)
        {:ok, state}

      {:error, reason} ->
        # Log the validation error
        Raxol.Core.Runtime.Log.error(
          "Terminal configuration update failed validation: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc '''
  Resets the configuration to default values.
  '''
  def reset_config(%State{} = state) do
    default_config = Raxol.Terminal.Config.Defaults.generate_default_config()
    state = apply_config_changes(state, default_config)
    {:ok, state}
  end

  @doc '''
  Gets a specific configuration value.
  '''
  def get_config_value(%State{} = state, path) do
    get_in(state.config, path)
  end

  @doc '''
  Sets a specific configuration value.
  '''
  def set_config_value(%State{} = state, path, value) do
    updated_config = put_in(state.config, path, value)

    case validate_config(updated_config) do
      :ok ->
        state = apply_config_changes(state, updated_config)
        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc '''
  Updates the buffer manager configuration.
  '''
  def update_buffer_manager(buffer_manager_state, config) do
    UnifiedManager.new(
      buffer_manager_state.width,
      buffer_manager_state.height,
      config.behavior.scrollback_limit,
      config.memory_limit
    )
  end

  @doc '''
  Updates the scroll buffer configuration.
  '''
  def update_scroll_buffer(scroll_buffer_state, config) do
    UnifiedScroll.set_max_height(
      scroll_buffer_state,
      config.behavior.scrollback_limit
    )
  end

  @doc '''
  Updates the renderer configuration.
  '''
  def update_renderer_config(renderer_state, config) do
    UnifiedRenderer.update_config(config.rendering)
    renderer_state
  end

  @doc '''
  Validates the configuration.
  '''
  def validate_config(config) do
    with :ok <- validate_behavior(config.behavior),
         :ok <- validate_memory_limit(config.memory_limit),
         :ok <- validate_rendering(config.rendering) do
      :ok
    end
  end

  @doc '''
  Applies configuration changes to the terminal state.
  '''
  def apply_config_changes(%State{} = state, changes) do
    # Update other state fields
    state
    |> Map.merge(changes)
  end

  @doc '''
  Gets emulator configuration.
  '''
  def get_emulator_config(config) do
    config.emulator
  end

  # Private Functions

  defp validate_behavior(behavior) do
    cond do
      !is_map(behavior) ->
        {:error, :invalid_behavior_config}

      !is_integer(behavior.scrollback_limit) or behavior.scrollback_limit < 0 ->
        {:error, :invalid_scrollback_limit}

      !is_boolean(behavior.enable_command_history) ->
        {:error, :invalid_command_history_setting}

      true ->
        :ok
    end
  end

  defp validate_memory_limit(memory_limit) do
    if is_integer(memory_limit) and memory_limit > 0 do
      :ok
    else
      {:error, :invalid_memory_limit}
    end
  end

  defp validate_rendering(rendering) do
    cond do
      !is_map(rendering) ->
        {:error, :invalid_rendering_config}

      !is_integer(rendering.fps) or rendering.fps < 1 ->
        {:error, :invalid_fps}

      !is_map(rendering.theme) ->
        {:error, :invalid_theme}

      !is_map(rendering.font_settings) ->
        {:error, :invalid_font_settings}

      true ->
        :ok
    end
  end
end
