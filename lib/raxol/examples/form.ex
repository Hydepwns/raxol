defmodule Raxol.Examples.Form do
  @moduledoc """
  A simple form component for demonstrating button integration.
  This is a stub implementation for test compatibility.
  """

  use Raxol.Core.Behaviours.BaseManager


  @doc """
  Creates a new form instance.
  """
  def new(opts \\ %{}) do
    %{
      __struct__: __MODULE__,
      id: "form_#{:rand.uniform(100_000)}",
      children: [],
      state: %{submitted: false},
      props: opts
    }
  end

  # BaseManager provides start_link/1
  # Usage: Raxol.Examples.Form.start_link(name: __MODULE__, ...)

  # BaseManager callbacks
  @impl true
  def init_manager(opts) do
    {:ok, %{opts: opts, children: []}}
  end

  @impl true
  def handle_manager_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_manager_cast({:add_child, child}, state) do
    {:noreply, %{state | children: [child | state.children]}}
  end

  @doc """
  Render function for integration with the UI system.
  """
  def render(_state, _context) do
    %{
      type: :form,
      children: []
    }
  end
end
