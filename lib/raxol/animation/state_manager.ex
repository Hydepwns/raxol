defmodule Raxol.Animation.StateManager do
  @moduledoc '''
  Manages the state for the Raxol Animation Framework.

  This module encapsulates the storage and retrieval of animation settings,
  definitions, and active instances, currently using the process dictionary.
  '''

  require Raxol.Core.Runtime.Log

  @settings_key :animation_framework_settings
  @animations_key :animation_framework_animations
  @active_animations_key :animation_framework_active_animations

  @doc '''
  Initializes the animation state storage.
  '''
  def init(settings) do
    Process.put(@settings_key, settings)
    Process.put(@animations_key, %{})
    Process.put(@active_animations_key, %{})
    :ok
  end

  @doc '''
  Retrieves the animation framework settings.
  '''
  def get_settings do
    Process.get(@settings_key, %{})
  end

  @doc '''
  Stores an animation definition.
  '''
  def put_animation(animation) do
    animations = Process.get(@animations_key, %{})
    updated_animations = Map.put(animations, animation.name, animation)
    Process.put(@animations_key, updated_animations)
  end

  @doc '''
  Retrieves an animation definition by name.
  '''
  def get_animation(animation_name) do
    Process.get(@animations_key, %{})
    |> Map.get(animation_name)
  end

  @doc '''
  Stores an active animation instance for a given element.
  '''
  def put_active_animation(element_id, animation_name, instance) do
    active_animations = Process.get(@active_animations_key, %{})
    element_animations = Map.get(active_animations, element_id, %{})

    updated_element_animations =
      Map.put(element_animations, animation_name, instance)

    updated_active_animations =
      Map.put(active_animations, element_id, updated_element_animations)

    Process.put(@active_animations_key, updated_active_animations)
  end

  @doc '''
  Retrieves all active animations. Returns a map of `{element_id, %{animation_name => instance}}`.
  '''
  def get_active_animations do
    Process.get(@active_animations_key, %{})
  end

  @doc '''
  Removes a completed or stopped animation instance for a specific element.
  '''
  def remove_active_animation(element_id, animation_name) do
    active_animations = get_active_animations()
    element_animations = Map.get(active_animations, element_id, %{})
    updated_element_animations = Map.delete(element_animations, animation_name)

    updated_active_animations =
      if map_size(updated_element_animations) == 0 do
        Map.delete(active_animations, element_id)
      else
        Map.put(active_animations, element_id, updated_element_animations)
      end

    Process.put(@active_animations_key, updated_active_animations)
    :ok
  end

  @doc '''
  Clears all animation state (used primarily for testing or reset).
  '''
  def clear_all do
    Process.delete(@settings_key)
    Process.delete(@animations_key)
    Process.delete(@active_animations_key)
    :ok
  end
end
