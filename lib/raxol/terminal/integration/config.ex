defmodule Raxol.Terminal.Integration.Config do
  @moduledoc """
  Manages configuration for the terminal integration.
  """

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

  @doc """
  Returns the default configuration.
  """
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

  @doc """
  Updates the terminal configuration.

  Merges the provided `opts` into the current configuration and validates
  the result before applying.
  """
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

  @doc """
  Resets the configuration to default values.
  """
  def reset_config(%State{} = state) do
    default_config = Raxol.Terminal.Config.Defaults.generate_default_config()
    state = apply_config_changes(state, default_config)
    {:ok, state}
  end

  @doc """
  Gets a specific configuration value.
  """
  def get_config_value(%State{} = state, path) do
    get_in(state.config, path)
  end

  @doc """
  Sets a specific configuration value.
  """
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

  @doc """
  Updates the buffer manager configuration.
  """
  def update_buffer_manager(buffer_manager_state, config) do
    UnifiedManager.new(
      buffer_manager_state.width,
      buffer_manager_state.height,
      config.behavior.scrollback_limit,
      config.memory_limit
    )
  end

  @doc """
  Updates the scroll buffer configuration.
  """
  def update_scroll_buffer(scroll_buffer_state, config) do
    UnifiedScroll.set_max_height(
      scroll_buffer_state,
      config.behavior.scrollback_limit
    )
  end

  @doc """
  Updates the renderer configuration.
  """
  def update_renderer_config(renderer_state, config) do
    UnifiedRenderer.update_config(config.rendering)
    renderer_state
  end

  @doc """
  Validates the configuration.
  """
  def validate_config(config) do
    with :ok <- validate_behavior(config.behavior),
         :ok <- validate_memory_limit(config.memory_limit),
         :ok <- validate_rendering(config.rendering) do
    end
  end

  @doc """
  Applies configuration changes to the terminal state.
  """
  def apply_config_changes(%State{} = state, changes) do
    # Update other state fields
    state
    |> Map.merge(changes)
  end

  @doc """
  Gets emulator configuration.
  """
  def get_emulator_config(config) do
    config.emulator
  end

  # Private Functions

  defp validate_behavior(behavior) do
    with :ok <- validate_behavior_map(behavior),
         :ok <- validate_scrollback_limit(behavior),
         :ok <- validate_command_history_setting(behavior) do
      :ok
    end
  end

  defp validate_behavior_map(behavior) when not is_map(behavior), do: {:error, :invalid_behavior_config}
  defp validate_behavior_map(_behavior), do: :ok

  defp validate_scrollback_limit(%{scrollback_limit: limit}) when not is_integer(limit) or limit < 0 do
    {:error, :invalid_scrollback_limit}
  end
  defp validate_scrollback_limit(_behavior), do: :ok

  defp validate_command_history_setting(%{enable_command_history: setting}) when not is_boolean(setting) do
    {:error, :invalid_command_history_setting}
  end
  defp validate_command_history_setting(_behavior), do: :ok

  defp validate_memory_limit(memory_limit) do
    if is_integer(memory_limit) and memory_limit > 0 do
      :ok
    else
      {:error, :invalid_memory_limit}
    end
  end

  defp validate_rendering(rendering) do
    with :ok <- validate_rendering_map(rendering),
         :ok <- validate_fps(rendering),
         :ok <- validate_theme(rendering),
         :ok <- validate_font_settings(rendering) do
      :ok
    end
  end

  defp validate_rendering_map(rendering) when not is_map(rendering), do: {:error, :invalid_rendering_config}
  defp validate_rendering_map(_rendering), do: :ok

  defp validate_fps(%{fps: fps}) when not is_integer(fps) or fps < 1, do: {:error, :invalid_fps}
  defp validate_fps(_rendering), do: :ok

  defp validate_theme(%{theme: theme}) when not is_map(theme), do: {:error, :invalid_theme}
  defp validate_theme(_rendering), do: :ok

  defp validate_font_settings(%{font_settings: font_settings}) when not is_map(font_settings) do
    {:error, :invalid_font_settings}
  end
  defp validate_font_settings(_rendering), do: :ok
end
