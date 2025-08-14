defmodule Raxol.Svelte.Slots do
  @moduledoc """
  Refactored Svelte-style slot system with GenServer-based state management.
  
  This module provides the same slot composition functionality as the original
  but uses supervised state management instead of Process dictionary.
  
  ## Migration Notes
  
  Component slot tracking has been moved to Svelte.ComponentState.Server,
  eliminating Process dictionary usage while maintaining full functionality.
  """
  
  # Suppress warnings for template-used functions and macro-generated GenServer callbacks
  @compile {:no_warn_unused, [{:_sorted_data, 3}]}
  @compile {:no_warn_undefined, [{:handle_cast, 2}, {:code_change, 3}, {:terminate, 2}]}
  
  alias Raxol.Svelte.ComponentState.Server
  
  # Ensure server is started
  defp ensure_server_started do
    case Process.whereis(Server) do
      nil ->
        {:ok, _pid} = Server.start_link()
        :ok
      _pid ->
        :ok
    end
  end
  
  defmacro __using__(_opts) do
    quote do
      import Raxol.Svelte.Slots
      
      @slots %{}
      @slot_props %{}
      @before_compile Raxol.Svelte.Slots
    end
  end
  
  @doc """
  Define a slot with optional default content and props.
  """
  defmacro slot(name \\ :default, opts \\ []) do
    quote do
      render_slot(unquote(name), unquote(opts))
    end
  end
  
  @doc """
  Define a scoped slot that passes data to the slot content.
  """
  defmacro scoped_slot(name, data, do: default_content) do
    quote do
      render_scoped_slot(unquote(name), unquote(data), unquote(default_content))
    end
  end
  
  @doc """
  Check if a slot has been provided by the parent.
  """
  def has_slot?(name \\ :default) do
    ensure_server_started()
    slots = Server.get_current_slots()
    Map.has_key?(slots, name)
  end
  
  @doc """
  Get the names of all available slots.
  """
  def slot_names do
    ensure_server_started()
    slots = Server.get_current_slots()
    Map.keys(slots)
  end
  
  @doc """
  Sets the current component slots (for advanced usage).
  """
  def set_current_slots(slots) do
    ensure_server_started()
    Server.set_current_slots(slots)
  end
  
  @doc """
  Gets the current component slots (for advanced usage).
  """
  def get_current_slots do
    ensure_server_started()
    Server.get_current_slots()
  end
  
  @doc """
  Executes a function with specific slots set for the duration.
  """
  def with_slots(slots, fun) when is_function(fun, 0) do
    ensure_server_started()
    Server.with_slots(slots, fun)
  end
  
  defmacro __before_compile__(_env) do
    quote do
      def init(opts) do
        # Initialize component state if needed
        {:ok, opts}
      end
      
      defp render_slot(name, opts \\ []) do
        slots = get_slots()
        default_content = Keyword.get(opts, :default, nil)
        
        case Map.get(slots, name) do
          nil ->
            # No slot provided, use default
            default_content
            
          slot_content ->
            # Render slot content
            render_slot_content(slot_content, %{})
        end
      end
      
      defp render_scoped_slot(name, data, default_content) do
        slots = get_slots()
        
        case Map.get(slots, name) do
          nil ->
            # No slot provided, use default
            default_content
            
          slot_content ->
            # Render slot content with scoped data
            render_slot_content(slot_content, data)
        end
      end
      
      defp get_slots do
        Raxol.Svelte.Slots.ensure_server_started()
        Raxol.Svelte.ComponentState.Server.get_current_slots()
      end
      
      defp extract_slots_from_props(props) do
        # Extract slot content from component props
        slots = %{}
        
        # Look for :slots key in props
        case Map.get(props, :slots) do
          nil -> slots
          slot_map when is_map(slot_map) -> slot_map
          _ -> slots
        end
      end
      
      defp render_slot_content(content, props) when is_function(content) do
        # Slot content is a function - call it with props
        content.(props)
      end
      
      defp render_slot_content(content, _props) do
        # Slot content is static
        content
      end
      
      # Refactored render function that uses GenServer instead of Process dictionary
      defp render_with_slots(assigns) do
        Raxol.Svelte.Slots.ensure_server_started()
        slots = assigns[:slots] || %{}
        
        Raxol.Svelte.ComponentState.Server.with_slots(slots, fn ->
          render(assigns)
        end)
      end
      
      defoverridable init: 1
    end
  end
  
  @doc """
  Wrapper function to ensure server is started for external calls.
  """
  def start_server do
    case Process.whereis(Server) do
      nil ->
        {:ok, _pid} = Server.start_link()
        :ok
      _pid ->
        :ok
    end
  end
end