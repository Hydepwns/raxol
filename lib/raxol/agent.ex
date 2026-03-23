defmodule Raxol.Agent do
  @moduledoc """
  Thin layer over `Raxol.Core.Runtime.Application` for building AI agents.

  Agents implement the same TEA callbacks (`init/1`, `update/2`, `view/1`)
  as any Raxol app. Input comes from LLMs, tools, or other agents instead
  of a keyboard. OTP provides supervision, crash isolation, and hot reload.

  `view/1` is optional -- headless agents skip rendering entirely.

  ## Example

      defmodule MyAgent do
        use Raxol.Agent

        def init(_context) do
          %{findings: [], status: :idle}
        end

        def update({:agent_message, _from, {:analyze, file}}, model) do
          {%{model | status: :working}, Command.async(fn sender ->
            result = do_analysis(file)
            sender.({:analysis_done, result})
          end)}
        end

        def update({:command_result, {:analysis_done, result}}, model) do
          {%{model | findings: [result | model.findings], status: :idle}, Command.none()}
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Raxol.Core.Runtime.Application

      import Raxol.Core.Renderer.View, except: [view: 1]
      alias Raxol.Core.Events.Event
      alias Raxol.Core.Runtime.Command

      def init(_), do: %{}
      def update(_, state), do: {state, Command.none()}
      def subscribe(_), do: []
      def subscriptions(_), do: []
      def handle_event(_), do: nil
      def handle_tick(model), do: {model, []}
      def handle_message(_, model), do: {model, []}
      def terminate(_, _), do: :ok

      defoverridable init: 1,
                     update: 2,
                     subscribe: 1,
                     subscriptions: 1,
                     handle_event: 1,
                     handle_tick: 1,
                     handle_message: 2,
                     terminate: 2

      @doc false
      def async(fun), do: Command.async(fun)

      @doc false
      def shell(command, opts \\ []), do: Command.shell(command, opts)

      @doc false
      def send_agent(target, message), do: Command.send_agent(target, message)
    end
  end
end
