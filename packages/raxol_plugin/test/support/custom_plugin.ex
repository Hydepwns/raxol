defmodule Raxol.Plugin.Test.CustomPlugin do
  @moduledoc false
  use Raxol.Plugin

  @impl true
  def init(config) do
    {:ok, %{config: config, enabled: false, events: []}}
  end

  @impl true
  def enable(state) do
    {:ok, %{state | enabled: true}}
  end

  @impl true
  def disable(state) do
    {:ok, %{state | enabled: false}}
  end

  @impl true
  def filter_event(:blocked, _state), do: :halt

  def filter_event(event, state) do
    {:ok, %{event: event, from: state}}
  end

  @impl true
  def handle_command(:greet, [name], state) do
    {:ok, state, "Hello, #{name}!"}
  end

  def handle_command(:fail, _args, state) do
    {:error, :intentional_failure, state}
  end

  def handle_command(_cmd, _args, state) do
    {:ok, state, :unknown}
  end

  @impl true
  def get_commands do
    [{:greet, :handle_greet, 1}, {:fail, :handle_fail, 0}]
  end

  @impl true
  def terminate(_reason, _state), do: :cleaned_up
end
