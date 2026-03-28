defmodule Raxol.Agent.AIBackendTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.Backend.Mock

  describe "Mock backend" do
    test "returns default response" do
      {:ok, resp} = Mock.complete([%{role: :user, content: "hello"}])

      assert resp.content == "Mock response"
      assert resp.metadata.backend == :mock
    end

    test "returns configured static response" do
      {:ok, resp} =
        Mock.complete(
          [%{role: :user, content: "hello"}],
          response: "Custom reply"
        )

      assert resp.content == "Custom reply"
    end

    test "returns response from function" do
      counter = :counters.new(1, [:atomics])

      {:ok, resp} =
        Mock.complete(
          [%{role: :user, content: "hello"}],
          response_fn: fn ->
            :counters.add(counter, 1, 1)
            "Response #{:counters.get(counter, 1)}"
          end
        )

      assert resp.content == "Response 1"
    end

    test "returns configured error" do
      assert {:error, :rate_limited} =
               Mock.complete(
                 [%{role: :user, content: "hello"}],
                 error: :rate_limited
               )
    end

    test "tracks token usage" do
      {:ok, resp} =
        Mock.complete([
          %{role: :user, content: "hello world"}
        ])

      assert resp.usage.input_tokens > 0
      assert resp.usage.output_tokens >= 0
    end

    test "stream returns events" do
      {:ok, events} =
        Mock.stream(
          [%{role: :user, content: "hello"}],
          response: "streamed"
        )

      assert [{:chunk, "streamed"}, {:done, %{content: "streamed"}}] = events
    end

    test "reports availability and capabilities" do
      assert Mock.available?() == true
      assert Mock.name() == "Mock Backend"
      assert :completion in Mock.capabilities()
      assert :streaming in Mock.capabilities()
    end
  end
end
