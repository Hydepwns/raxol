defmodule Raxol.Agent.UseProcess do
  @moduledoc """
  Convenience macro for agents running in the observe/think/act loop.

  Similar to `use Raxol.Agent` for TEA agents, this provides defaults
  and the `@behaviour` annotation for Process-based agents.

  ## Example

      defmodule MyProcessAgent do
        use Raxol.Agent.UseProcess

        @impl true
        def init(_opts), do: {:ok, %{count: 0}}

        @impl true
        def observe(events, state) do
          {:ok, %{event_count: length(events)}, state}
        end

        @impl true
        def think(%{event_count: n}, state) when n > 0 do
          {:act, :process_events, state}
        end

        def think(_obs, state), do: {:wait, state}

        @impl true
        def act(:process_events, state) do
          {:ok, %{state | count: state.count + 1}}
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Agent.ProcessBehaviour

      @impl true
      def init(_opts), do: {:ok, %{}}

      @impl true
      def observe(_events, state), do: {:ok, %{}, state}

      @impl true
      def think(_observation, state), do: {:wait, state}

      @impl true
      def act(_action, state), do: {:ok, state}

      @impl true
      def receive_directive(_directive, state), do: {:ok, state}

      @impl true
      def context_snapshot(state), do: state

      @impl true
      def restore_context(snapshot), do: {:ok, snapshot}

      @impl true
      def on_takeover(state), do: {:ok, state}

      @impl true
      def on_resume(state), do: {:ok, state}

      defoverridable init: 1,
                     observe: 2,
                     think: 2,
                     act: 2,
                     receive_directive: 2,
                     context_snapshot: 1,
                     restore_context: 1,
                     on_takeover: 1,
                     on_resume: 1
    end
  end
end
