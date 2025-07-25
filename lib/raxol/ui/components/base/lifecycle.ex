defmodule Raxol.UI.Components.Base.Lifecycle do
  @moduledoc """
  Provides component lifecycle hooks and management for UI components.

  This module handles:
  - Component mounting and initialization
  - Update propagation to components
  - Component unmounting and cleanup
  - Lifecycle event tracking
  """

  alias Raxol.UI.Components.Base.Component

  @doc """
  Mounts a component, initializing its state and triggering mount-time effects.

  ## Parameters

  * `component` - The component to mount
  * `props` - Initial properties for the component
  * `context` - The rendering context

  ## Returns

  The mounted component and any side effects
  """
  @spec mount(Component.t(), map(), map()) :: {Component.t(), list()}
  def mount(component, props \\ %{}, context \\ %{}) do
    # Apply initial props
    component = apply_props(component, props)

    # Call component's mount handler if it exists
    if function_exported?(component.__struct__, :mount, 2) do
      component.__struct__.mount(component, context)
    else
      {component, []}
    end
  end

  @doc """
  Updates a component with new props.

  ## Parameters

  * `component` - The component to update
  * `props` - New properties to apply
  * `context` - The rendering context

  ## Returns

  The updated component
  """
  @spec update(Component.t(), map(), map()) :: Component.t()
  def update(component, props, context \\ %{}) do
    # Apply the new props
    updated = apply_props(component, props)

    # Call component's update handler if it exists
    if function_exported?(component.__struct__, :update, 3) do
      component.__struct__.update(component, updated, context)
    else
      updated
    end
  end

  @doc """
  Unmounts a component, allowing it to clean up resources.

  ## Parameters

  * `component` - The component to unmount
  * `context` - The rendering context

  ## Returns

  The unmounted component and any cleanup effects
  """
  @spec unmount(Component.t(), map()) :: {Component.t(), list()}
  def unmount(component, context \\ %{}) do
    # Call component's unmount handler if it exists
    if function_exported?(component.__struct__, :unmount, 2) do
      component.__struct__.unmount(component, context)
    else
      {component, []}
    end
  end

  @doc """
  Renders a component, creating its view representation.

  This is a wrapper around the component's render function that ensures
  consistent handling of the rendering process.

  ## Parameters

  * `component` - The component to render
  * `context` - The rendering context

  ## Returns

  The rendered view representation and updated component state
  """
  @spec render(Component.t(), map()) :: {Component.t(), map()}
  def render(component, context) do
    # Call the component's render function
    if function_exported?(component.__struct__, :render, 2) do
      {updated_component, view} =
        component.__struct__.render(component, context)

      {updated_component, view}
    else
      {component, %{type: :unknown_component}}
    end
  end

  @doc """
  Processes an event on a component.

  ## Parameters

  * `component` - The component to process the event on
  * `event` - The event to process
  * `context` - The event context

  ## Returns

  `{:update, updated_component}` if the component state changed,
  `{:handled, component}` if the event was handled but state didn't change,
  `:passthrough` if the event wasn't handled by the component.
  """
  @spec process_event(Component.t(), map(), map()) ::
          {:update, Component.t()} | {:handled, Component.t()} | :passthrough
  def process_event(component, event, context) do
    # Process the event using the component's handler
    if function_exported?(component.__struct__, :handle_event, 3) do
      component.__struct__.handle_event(component, event, context)
    else
      :passthrough
    end
  end

  @doc """
  Adds a lifecycle event to the component for debugging purposes.

  ## Parameters

  * `component` - The component to add the event to
  * `event` - The lifecycle event to record

  ## Returns

  The component with the added lifecycle event
  """
  @spec add_lifecycle_event(Component.t(), term()) :: Component.t()
  def add_lifecycle_event(component, event) do
    lifecycle_events = Map.get(component, :__lifecycle_events__, [])

    Map.put(component, :__lifecycle_events__, [
      {event, System.system_time(:millisecond)} | lifecycle_events
    ])
  end

  @doc """
  Gets the lifecycle events recorded for a component.

  ## Parameters

  * `component` - The component to get events for

  ## Returns

  List of lifecycle events with timestamps
  """
  @spec get_lifecycle_events(Component.t()) :: [{term(), integer()}]
  def get_lifecycle_events(component) do
    Map.get(component, :__lifecycle_events__, [])
  end

  # Private helpers

  defp apply_props(component, props) do
    # Merge props into component, respecting component structure
    Map.merge(component, props)
  end
end
