defmodule Raxol.Web.Auth.Manager do
  @moduledoc """
  Manages authentication state and operations for the Raxol application.
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
       tokens: %{},
       opts: opts
     }}
  end

  # Server callbacks

  def handle_call({:validate_token, token}, _from, state) do
    case get_in(state, [:tokens, token]) do
      nil -> {:reply, {:error, :invalid_token}, state}
      session -> {:reply, {:ok, session}, state}
    end
  end

  def handle_call({:register_token, token, session_data}, _from, state) do
    new_state = put_in(state, [:tokens, token], session_data)
    {:reply, :ok, new_state}
  end

  def handle_call({:invalidate_token, token}, _from, state) do
    new_state = %{state | tokens: Map.delete(state.tokens, token)}
    {:reply, :ok, new_state}
  end

  def handle_call(:get_sessions, _from, state) do
    {:reply, state.sessions, state}
  end
end
