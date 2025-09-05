defmodule Raxol.Test.Integration.HierarchySetup do
  @moduledoc """
  Handles setup of component hierarchies for integration testing.

  This module provides functions for:
  - Setting up parent-child component relationships
  - Managing component mounting in ComponentManager
  - Establishing proper state references between components
  """

  alias Raxol.Core.Runtime.ComponentManager

  @doc """
  Sets up a parent-child component hierarchy for testing.

  Returns the initialized parent and child test component structs with proper event routing.
  """
  def setup_component_hierarchy(a, b, opts \\ [])

  def setup_component_hierarchy(parent_module, child_modules, opts)
      when is_atom(parent_module) and is_list(child_modules) do
    # Handle list of child modules (for broadcast tests)
    parent = create_test_component(parent_module)

    # Check if child_ids are provided for unique IDs
    child_ids = Keyword.get(opts, :child_ids, [])

    children = create_children_with_ids(child_modules, child_ids)

    setup_component_hierarchy(parent, children, opts)
  end

  def setup_component_hierarchy(parent_module, child_module, opts)
      when is_atom(parent_module) and is_atom(child_module) do
    button_attrs = Keyword.get(opts, :button_attrs, %{})

    parent = create_test_component(parent_module)
    child = create_test_component(child_module, button_attrs)

    setup_component_hierarchy(parent, child, opts)
  end

  def setup_component_hierarchy(parent_struct, child_structs, opts)
      when is_map(parent_struct) and is_list(child_structs) do
    # Update the :state fields to reference each other
    child_ids = Enum.map(child_structs, & &1.state.id)
    parent_state = Map.put(parent_struct.state, :children, child_ids)

    # Update each child to reference the parent
    updated_children =
      Enum.map(child_structs, fn child ->
        child_state = Map.put(child.state, :parent_id, parent_state.id)
        %{child | state: child_state}
      end)

    # Update parent with child states in child_states field
    child_states_map =
      Enum.reduce(updated_children, %{}, fn child, acc ->
        Map.put(acc, child.state.id, child.state)
      end)

    parent_state = Map.put(parent_state, :child_states, child_states_map)
    parent_struct = %{parent_struct | state: parent_state}

    # Optionally mount components in ComponentManager if requested
    mount_in_manager = Keyword.get(opts, :mount_in_manager, false)

    # Mount components if requested
    mount_components_conditionally(
      mount_in_manager,
      parent_struct,
      parent_state,
      updated_children
    )
  end

  defp mount_components_conditionally(
         false,
         parent_struct,
         _parent_state,
         updated_children
       ) do
    {:ok, parent_struct, updated_children}
  end

  defp mount_components_conditionally(
         true,
         parent_struct,
         parent_state,
         updated_children
       ) do
    # Mount parent first
    case ComponentManager.mount(parent_struct.module, parent_state) do
      {:ok, parent_id} ->
        parent_struct = %{
          parent_struct
          | state: Map.put(parent_state, :component_manager_id, parent_id)
        }

        # Mount all children and update parent's child_states
        {mounted_children, updated_parent_state} =
          Enum.map_reduce(updated_children, parent_struct.state, fn child,
                                                                    parent_state ->
            case ComponentManager.mount(child.module, child.state) do
              {:ok, child_id} ->
                # Use the actual ComponentManager key as component_manager_id
                updated_child_state =
                  Map.put(child.state, :component_manager_id, child_id)

                updated_child = %{
                  child
                  | state: updated_child_state
                }

                # Immediately update the state in the ComponentManager
                ComponentManager.set_component_state(
                  child_id,
                  updated_child_state
                )

                # Update parent's child_states map with the new child state
                updated_parent_state =
                  Map.put(
                    parent_state,
                    :child_states,
                    Map.put(
                      parent_state.child_states,
                      child.state.id,
                      updated_child.state
                    )
                  )

                {updated_child, updated_parent_state}

              {:error, reason} ->
                IO.puts(
                  "Failed to mount child #{inspect(child.state.id)}: #{inspect(reason)}"
                )

                {child, parent_state}
            end
          end)

        # Update parent struct with new state that includes updated child_states
        parent_struct = %{parent_struct | state: updated_parent_state}

        {:ok, parent_struct, mounted_children}

      {:error, _reason} ->
        {:ok, parent_struct, updated_children}
    end
  end

  def setup_component_hierarchy(parent_struct, child_struct, opts)
      when is_map(parent_struct) and is_map(child_struct) do
    # Update the :state fields to reference each other
    parent_state =
      Map.put(parent_struct.state, :children, [child_struct.state.id])

    child_state = Map.put(child_struct.state, :parent_id, parent_state.id)

    # Update parent with child state in child_states field
    parent_state =
      Map.put(parent_state, :child_states, %{
        child_struct.state.id => child_state
      })

    # Update the test component structs
    parent_struct = %{parent_struct | state: parent_state}
    child_struct = %{child_struct | state: child_state}

    # Optionally mount components in ComponentManager if requested
    mount_in_manager = Keyword.get(opts, :mount_in_manager, false)

    maybe_mount_components(
      parent_struct,
      parent_state,
      child_struct,
      child_state,
      mount_in_manager
    )
  end

  @doc """
  Sets up a parent-child component hierarchy and mounts components in ComponentManager.

  This is a convenience function that combines setup_component_hierarchy with mounting.
  """
  def setup_component_hierarchy_with_mounting(
        parent_module,
        child_modules,
        opts \\ []
      )

  def setup_component_hierarchy_with_mounting(
        parent_module,
        child_modules,
        opts
      )
      when is_list(child_modules) do
    {:ok, parent_struct, mounted_children} =
      setup_component_hierarchy(
        parent_module,
        child_modules,
        Keyword.put(opts, :mount_in_manager, true)
      )

    # Get the mounted state from ComponentManager for parent
    parent_mounted_state =
      ComponentManager.get_component(parent_struct.state.component_manager_id).state

    # Get the mounted state from ComponentManager for each child
    # IO.puts("DEBUG: Getting mounted state for children...")

    # IO.puts(
    #   "DEBUG: mounted_children have component_manager_id: #{inspect(Enum.map(mounted_children, fn c -> c.state.component_manager_id end))}"
    # )

    mounted_children_with_state =
      Enum.map(mounted_children, fn child ->
        # IO.puts(
        #   "DEBUG: Processing child #{inspect(child.state.id)} with component_manager_id: #{inspect(child.state.component_manager_id)}"
        # )

        get_child_with_mounted_state(child)
      end)

    # Update parent's child_states map with the mounted child states
    updated_child_states =
      Enum.reduce(
        mounted_children_with_state,
        parent_mounted_state.child_states,
        fn child, acc ->
          Map.put(acc, child.state.id, child.state)
        end
      )

    parent_struct_with_mounted_state = %{
      parent_struct
      | state: %{parent_mounted_state | child_states: updated_child_states}
    }

    # Set up parent/child references
    mounted_children_with_parent =
      Enum.map(mounted_children_with_state, fn child ->
        Map.put(child, :parent, parent_struct_with_mounted_state)
      end)

    parent_struct_with_children =
      Map.put(
        parent_struct_with_mounted_state,
        :children,
        mounted_children_with_parent
      )

    {:ok, parent_struct_with_children, mounted_children_with_parent}
  end

  def setup_component_hierarchy_with_mounting(parent_module, child_module, opts) do
    {:ok, parent_struct, child_struct} =
      setup_component_hierarchy(
        parent_module,
        child_module,
        Keyword.put(opts, :mount_in_manager, true)
      )

    # Get the mounted components from ComponentManager
    parent_mounted =
      ComponentManager.get_component(parent_struct.state.component_manager_id)

    child_mounted =
      ComponentManager.get_component(child_struct.state.component_manager_id)

    # Debug output
    # IO.puts("DEBUG: parent_mounted = #{inspect(parent_mounted)}")
    # IO.puts("DEBUG: child_mounted = #{inspect(child_mounted)}")
    # IO.puts("DEBUG: child_mounted.state = #{inspect(child_mounted.state)}")

    # IO.puts(
    #   "DEBUG: child_mounted.state.mounted = #{inspect(child_mounted.state.mounted)}"
    # )

    # Update parent's child_states with the child's mounted state (including component_manager_id)
    updated_parent_state =
      Map.put(
        parent_mounted.state,
        :child_states,
        Map.put(
          parent_mounted.state.child_states,
          child_mounted.state.id,
          child_mounted.state
        )
      )

    # Update parent component in ComponentManager with the new state
    ComponentManager.set_component_state(
      parent_struct.state.component_manager_id,
      updated_parent_state
    )

    # Get the updated parent from ComponentManager
    updated_parent_mounted =
      ComponentManager.get_component(parent_struct.state.component_manager_id)

    # Create proper child struct with mounted state
    child_struct_with_mounted_state = %{
      child_struct
      | state: child_mounted.state
    }

    # Create proper parent struct with mounted state
    parent_struct_with_mounted_state = %{
      parent_struct
      | state: updated_parent_mounted.state
    }

    # Set up parent/child references
    child_struct_with_parent =
      Map.put(
        child_struct_with_mounted_state,
        :parent,
        parent_struct_with_mounted_state
      )

    parent_struct_with_child =
      Map.put(parent_struct_with_mounted_state, :children, [
        child_struct_with_parent
      ])

    {:ok, parent_struct_with_child, child_struct_with_parent}
  end

  # Private helper functions

  defp create_children_with_ids(child_modules, child_ids) do
    create_children_with_ids_conditional(
      child_ids != [] and length(child_ids) == length(child_modules),
      child_modules,
      child_ids
    )
  end

  defp create_children_with_ids_conditional(true, child_modules, child_ids) do
    # Create children with specific IDs
    Enum.zip(child_modules, child_ids)
    |> Enum.map(fn {module, id} ->
      create_test_component(module, %{id: id})
    end)
  end

  defp create_children_with_ids_conditional(false, child_modules, _child_ids) do
    # Create children with default IDs
    Enum.map(child_modules, &create_test_component/1)
  end

  defp get_child_with_mounted_state(child) do
    get_child_by_manager_id(child.state.component_manager_id, child)
  end

  defp get_child_by_manager_id(nil, child) do
    # If child doesn't have component_manager_id, try to find it by ID
    all_components = ComponentManager.get_all_components()

    # IO.puts(
    #   "DEBUG: All components in manager: #{inspect(Map.keys(all_components))}"
    # )

    child_component =
      Enum.find_value(all_components, fn {_manager_id, comp} ->
        find_child_by_id(comp.state.id == child.state.id, comp)
      end)

    get_child_from_found_component(child_component, child)
  end

  defp get_child_by_manager_id(component_manager_id, child) do
    child_mounted = ComponentManager.get_component(component_manager_id)

    # IO.puts(
    #   "DEBUG: Found child by component_manager_id: #{inspect(child_mounted.state.component_manager_id)}"
    # )

    %{child | state: child_mounted.state}
  end

  defp find_child_by_id(true, comp), do: comp
  defp find_child_by_id(false, _comp), do: nil

  defp get_child_from_found_component(nil, child) do
    # IO.puts(
    #   "DEBUG: Could not find child #{inspect(child.state.id)} in ComponentManager"
    # )

    child
  end

  defp get_child_from_found_component(child_component, child) do
    # IO.puts(
    #   "DEBUG: Found child by ID: #{inspect(child_component.state.component_manager_id)}"
    # )

    %{child | state: child_component.state}
  end

  defp mount_single_component_pair(
         false,
         parent_struct,
         _parent_state,
         child_struct,
         _child_state
       ) do
    {:ok, parent_struct, child_struct}
  end

  defp mount_single_component_pair(
         true,
         parent_struct,
         parent_state,
         child_struct,
         child_state
       ) do
    case ComponentManager.mount(parent_struct.module, parent_state) do
      {:ok, parent_id} ->
        case ComponentManager.mount(child_struct.module, child_state) do
          {:ok, child_id} ->
            # Get the mounted states from ComponentManager
            parent_mounted = ComponentManager.get_component(parent_id)
            child_mounted = ComponentManager.get_component(child_id)

            # Update the mounted states with component_manager_id
            updated_parent_state =
              Map.put(parent_mounted.state, :component_manager_id, parent_id)

            updated_child_state =
              Map.put(child_mounted.state, :component_manager_id, child_id)

            # Update the components in ComponentManager with the new states
            ComponentManager.set_component_state(
              parent_id,
              updated_parent_state
            )

            ComponentManager.set_component_state(
              child_id,
              updated_child_state
            )

            # Update the structs with the new states
            parent_struct = %{
              parent_struct
              | state: updated_parent_state
            }

            child_struct = %{
              child_struct
              | state: updated_child_state
            }

            {:ok, parent_struct, child_struct}

          {:error, reason} ->
            {:error, {:child_mount_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:parent_mount_failed, reason}}
    end
  end

  defp maybe_mount_components(
         parent_struct,
         parent_state,
         child_struct,
         child_state,
         mount_in_manager
       ) do
    mount_single_component_pair(
      mount_in_manager,
      parent_struct,
      parent_state,
      child_struct,
      child_state
    )
  end

  defp create_test_component(module, opts \\ %{}) do
    state = module.new(opts)

    %{
      module: module,
      state: state,
      subscriptions: []
    }
  end
end
