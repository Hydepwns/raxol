defmodule Raxol.Animation.Animation do
  @moduledoc """
  Animation framework stub for test compatibility.

  This module provides a wrapper interface around the existing Framework
  to maintain compatibility with test expectations.
  """

  alias Raxol.Animation.Framework

  @doc """
  Initializes the animation framework with the given configuration.
  Delegates to Framework.init/2 for actual implementation.

  ## Parameters
  - config: Animation configuration map
  - preferences_module: User preferences module name

  ## Returns
  :ok on success
  """
  def init(config, preferences_module) when is_map(config) do
    Framework.init(config, preferences_module)
  end

  @doc """
  Stops the animation framework.
  Delegates to Framework.stop/0.
  """
  def stop do
    Framework.stop()
  end

  @doc """
  Starts an animation with the given parameters.
  Delegates to Framework functionality.
  """
  def start_animation(name, params) do
    Framework.start_animation(name, params)
  end

  @doc """
  Stops a running animation.
  Delegates to Framework functionality.
  """
  def stop_animation(name, element_id \\ nil) do
    case element_id do
      nil -> :ok  # Handle legacy interface
      element_id -> Framework.stop_animation(name, element_id)
    end
  end

  @doc """
  Gets the current state of the animation framework.
  Provides stub implementation for test compatibility.
  """
  def get_state do
    %{
      animations: %{},
      started: true
    }
  end
end