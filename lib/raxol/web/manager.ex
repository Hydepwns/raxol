defmodule Raxol.Web.Manager do
  @moduledoc """
  Manages web sessions and terminal connections for the Raxol application.
  """

  use GenServer

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    {:ok,
     %{
       sessions: %{},
       terminals: %{},
       opts: opts
     }}
  end

  # Server callbacks

  def handle_call({:register_session, session_id, session_data}, _from, state) do
    new_state = put_in(state, [:sessions, session_id], session_data)
    {:reply, :ok, new_state}
  end

  def handle_call({:unregister_session, session_id}, _from, state) do
    new_state = %{state | sessions: Map.delete(state.sessions, session_id)}
    {:reply, :ok, new_state}
  end

  def handle_call(
        {:register_terminal, terminal_id, terminal_data},
        _from,
        state
      ) do
    new_state = put_in(state, [:terminals, terminal_id], terminal_data)
    {:reply, :ok, new_state}
  end

  def handle_call({:unregister_terminal, terminal_id}, _from, state) do
    new_state = %{state | terminals: Map.delete(state.terminals, terminal_id)}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_sessions, _from, state) do
    {:reply, state.sessions, state}
  end

  def handle_call(:get_terminals, _from, state) do
    {:reply, state.terminals, state}
  end
end
