defmodule Raxol.Core.Runtime.ProcessStore do
  @moduledoc """
  Replacement for Process dictionary usage.
  Provides a functional alternative using Agent for state storage.
  """

  use Agent

  @doc """
  Starts a new process store.
  """
  def start_link(initial_state \\ %{}) do
    Agent.start_link(fn -> initial_state end, name: __MODULE__)
  end

  @doc """
  Gets a value from the store.
  """
  def get(key, default \\ nil) do
    Agent.get(__MODULE__, &Map.get(&1, key, default))
  catch
    :exit, _ -> default
  end

  @doc """
  Gets all values from the store.
  """
  def get_all do
    Agent.get(__MODULE__, & &1)
  catch
    :exit, _ -> %{}
  end

  @doc """
  Puts a value in the store.
  """
  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  catch
    :exit, _ -> {:error, :not_started}
  end

  @doc """
  Deletes a value from the store.
  """
  def delete(key) do
    Agent.update(__MODULE__, &Map.delete(&1, key))
  catch
    :exit, _ -> {:error, :not_started}
  end

  @doc """
  Clears all values from the store.
  """
  def clear do
    Agent.update(__MODULE__, fn _ -> %{} end)
  catch
    :exit, _ -> {:error, :not_started}
  end

  @doc """
  Updates a value in the store using a function.
  """
  def update(key, default, fun) do
    Agent.update(__MODULE__, fn state ->
      Map.update(state, key, default, fun)
    end)
  catch
    :exit, _ -> {:error, :not_started}
  end

  @doc """
  Gets and updates a value atomically.
  """
  def get_and_update(key, fun) do
    Agent.get_and_update(__MODULE__, fn state ->
      case Map.fetch(state, key) do
        {:ok, value} ->
          case fun.(value) do
            {get_value, new_value} ->
              {get_value, Map.put(state, key, new_value)}

            :pop ->
              {value, Map.delete(state, key)}
          end

        :error ->
          case fun.(nil) do
            {get_value, new_value} ->
              {get_value, Map.put(state, key, new_value)}

            :pop ->
              {nil, state}
          end
      end
    end)
  catch
    :exit, _ -> nil
  end
end
