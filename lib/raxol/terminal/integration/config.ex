defmodule Raxol.Terminal.Integration.Config do
  @moduledoc """
  Handles configuration management for the terminal integration.
  """

  require Raxol.Core.Runtime.Log

  alias Raxol.Terminal.Config
  alias Raxol.Terminal.Integration.State

  @doc """
  Updates the terminal configuration.

  Merges the provided `opts` into the current configuration and validates
  the result before applying.
  """
  def update_config(%State{} = state, opts) do
    # Merge the new options into the current config
    updated_config = Config.merge_opts(state.config, opts)

    # Validate the updated configuration
    case Config.validate_config(updated_config) do
      {:ok, validated_config} ->
        # Apply the validated, merged config
        state = apply_config_changes(state, validated_config)
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
    default_config = Defaults.generate_default_config()
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

    case Config.validate_config(updated_config) do
      {:ok, validated_config} ->
        state = apply_config_changes(state, validated_config)
        {:ok, state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp apply_config_changes(%State{} = state, new_config) do
    # Update buffer manager with new limits
    {:ok, buffer_manager} =
      state.buffer_manager
      |> update_buffer_manager(new_config)

    # Update renderer with new colors
    renderer =
      state.renderer
      |> update_renderer(new_config)

    # Update scroll buffer with new size
    scroll_buffer =
      state.scroll_buffer
      |> update_scroll_buffer(new_config)

    # Update command history with new size
    command_history =
      state.command_history
      |> update_command_history(new_config)

    # Update the state with all changes
    State.update(state, %{
      buffer_manager: buffer_manager,
      renderer: renderer,
      scroll_buffer: scroll_buffer,
      command_history: command_history,
      config: new_config
    })
  end

  defp update_buffer_manager(buffer_manager, config) do
    Raxol.Terminal.Buffer.Manager.update_limits(
      buffer_manager,
      config.behavior.scrollback_limit,
      config.memory_limit || 50 * 1024 * 1024
    )
  end

  defp update_renderer(renderer, config) do
    Raxol.Terminal.Renderer.update_colors(renderer, config.ansi.colors)
  end

  defp update_scroll_buffer(scroll_buffer, config) do
    Raxol.Terminal.Buffer.Scroll.update_size(scroll_buffer, config.behavior.scrollback_limit)
  end

  defp update_command_history(command_history, config) do
    Raxol.Terminal.Commands.History.update_size(
      command_history,
      (config.behavior.enable_command_history && 1000) || 0
    )
  end
end
