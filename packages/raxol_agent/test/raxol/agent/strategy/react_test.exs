defmodule Raxol.Agent.Strategy.ReActTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.Strategy.ReAct

  defmodule AddNumbers do
    use Raxol.Agent.Action,
      name: "add_numbers",
      description: "Add two numbers",
      schema: [
        input: [
          a: [type: :integer, required: true, description: "First number"],
          b: [type: :integer, required: true, description: "Second number"]
        ]
      ]

    @impl true
    def run(%{a: a, b: b}, _ctx), do: {:ok, %{result: a + b}}
  end

  defmodule Multiply do
    use Raxol.Agent.Action,
      name: "multiply",
      description: "Multiply two numbers",
      schema: [
        input: [
          x: [type: :integer, required: true],
          y: [type: :integer, required: true]
        ]
      ]

    @impl true
    def run(%{x: x, y: y}, _ctx), do: {:ok, %{result: x * y}}
  end

  # A mock backend that returns tool_calls on first call, then a text answer
  defmodule SequenceMock do
    @behaviour Raxol.Agent.AIBackend

    @impl true
    def complete(_messages, opts) do
      # Use an agent process to track call count
      counter = Keyword.get(opts, :counter)

      if counter do
        count = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

        responses = Keyword.get(opts, :responses, [])

        case Enum.at(responses, count) do
          nil -> {:ok, %{content: "Done.", usage: %{}, metadata: %{}}}
          response -> {:ok, response}
        end
      else
        {:ok, %{content: "No counter configured.", usage: %{}, metadata: %{}}}
      end
    end

    @impl true
    def available?, do: true
    @impl true
    def name, do: "Sequence Mock"
    @impl true
    def capabilities, do: [:completion, :tool_use]
  end

  describe "execute/3" do
    test "returns final answer when LLM responds with text" do
      context = %{
        backend: Raxol.Agent.Backend.Mock,
        backend_opts: [response: "The answer is 42."],
        actions: [AddNumbers, Multiply]
      }

      assert {:ok, state} =
               ReAct.execute(
                 {nil, %{prompt: "What is the meaning of life?"}},
                 %{},
                 context
               )

      assert state.last_answer == "The answer is 42."
    end

    test "executes tool calls and feeds results back to LLM" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      responses = [
        # First call: LLM wants to use a tool
        %{
          content: "",
          tool_calls: [
            %{"id" => "call_1", "name" => "add_numbers", "arguments" => %{"a" => 3, "b" => 4}}
          ],
          usage: %{},
          metadata: %{}
        },
        # Second call: LLM provides final answer
        %{
          content: "The sum is 7.",
          usage: %{},
          metadata: %{}
        }
      ]

      context = %{
        backend: SequenceMock,
        backend_opts: [counter: counter, responses: responses],
        actions: [AddNumbers, Multiply]
      }

      assert {:ok, state} =
               ReAct.execute(
                 {nil, %{prompt: "Add 3 and 4"}},
                 %{},
                 context
               )

      assert state.last_answer == "The sum is 7."
      assert is_list(state.tool_results)
    end

    test "handles multiple tool calls in sequence" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      responses = [
        # First: add
        %{
          content: "",
          tool_calls: [
            %{"id" => "c1", "name" => "add_numbers", "arguments" => %{"a" => 1, "b" => 2}}
          ],
          usage: %{},
          metadata: %{}
        },
        # Second: multiply
        %{
          content: "",
          tool_calls: [
            %{"id" => "c2", "name" => "multiply", "arguments" => %{"x" => 3, "y" => 4}}
          ],
          usage: %{},
          metadata: %{}
        },
        # Third: final answer
        %{content: "1+2=3 and 3*4=12.", usage: %{}, metadata: %{}}
      ]

      context = %{
        backend: SequenceMock,
        backend_opts: [counter: counter, responses: responses],
        actions: [AddNumbers, Multiply]
      }

      assert {:ok, state} =
               ReAct.execute({nil, %{prompt: "Do math"}}, %{}, context)

      assert state.last_answer == "1+2=3 and 3*4=12."
    end

    test "respects max_iterations guard" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      # Always returns tool calls, never text -- should hit max iterations
      infinite_tool_call = %{
        content: "",
        tool_calls: [
          %{"id" => "c", "name" => "add_numbers", "arguments" => %{"a" => 1, "b" => 1}}
        ],
        usage: %{},
        metadata: %{}
      }

      responses = List.duplicate(infinite_tool_call, 5)

      context = %{
        backend: SequenceMock,
        backend_opts: [counter: counter, responses: responses],
        actions: [AddNumbers],
        max_iterations: 3
      }

      assert {:error, :max_iterations_reached} =
               ReAct.execute({nil, %{prompt: "Loop forever"}}, %{}, context)
    end

    test "handles backend error" do
      context = %{
        backend: Raxol.Agent.Backend.Mock,
        backend_opts: [error: :rate_limited],
        actions: [AddNumbers]
      }

      assert {:error, :rate_limited} =
               ReAct.execute({nil, %{prompt: "Will fail"}}, %{}, context)
    end

    test "handles unknown tool call gracefully" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      responses = [
        %{
          content: "",
          tool_calls: [
            %{"id" => "c", "name" => "nonexistent_tool", "arguments" => %{}}
          ],
          usage: %{},
          metadata: %{}
        },
        %{content: "OK, that tool didn't work.", usage: %{}, metadata: %{}}
      ]

      context = %{
        backend: SequenceMock,
        backend_opts: [counter: counter, responses: responses],
        actions: [AddNumbers]
      }

      assert {:ok, state} =
               ReAct.execute({nil, %{prompt: "Use a bad tool"}}, %{}, context)

      assert state.last_answer == "OK, that tool didn't work."
    end

    test "includes system prompt when provided" do
      context = %{
        backend: Raxol.Agent.Backend.Mock,
        backend_opts: [response: "Done."],
        actions: [],
        system_prompt: "You are a helpful assistant."
      }

      assert {:ok, _state} =
               ReAct.execute({nil, %{prompt: "Hello"}}, %{status: :idle}, context)
    end

    test "returns error when backend is missing from context" do
      context = %{actions: [AddNumbers]}

      assert {:error, {:missing_required_context, :backend}} =
               ReAct.execute({nil, %{prompt: "No backend"}}, %{}, context)
    end
  end
end
