defmodule Raxol.Agent.ContextCompactorTest do
  use ExUnit.Case, async: true

  alias Raxol.Agent.ContextCompactor

  # -- Token Estimation ---------------------------------------------------------

  describe "estimate_tokens/1 for strings" do
    test "empty string returns 1" do
      assert ContextCompactor.estimate_tokens("") == 1
    end

    test "short string uses byte_size/4 + 1" do
      # "hello" is 5 bytes -> 5/4 + 1 = 2
      assert ContextCompactor.estimate_tokens("hello") == 2
    end

    test "longer string scales proportionally" do
      text = String.duplicate("a", 400)
      # 400 bytes -> 400/4 + 1 = 101
      assert ContextCompactor.estimate_tokens(text) == 101
    end
  end

  describe "estimate_tokens/1 for message lists" do
    test "empty list returns 0" do
      assert ContextCompactor.estimate_tokens([]) == 0
    end

    test "single message includes content + overhead" do
      messages = [%{role: :user, content: "hello"}]
      # "hello" -> 2 tokens + 4 overhead = 6
      assert ContextCompactor.estimate_tokens(messages) == 6
    end

    test "multiple messages sum correctly" do
      messages = [
        %{role: :user, content: "hello"},
        %{role: :assistant, content: "world"}
      ]

      # Each message: 2 content + 4 overhead = 6, total = 12
      assert ContextCompactor.estimate_tokens(messages) == 12
    end

    test "handles missing content key gracefully" do
      messages = [%{role: :user}]
      # empty string -> 1 token + 4 overhead = 5
      assert ContextCompactor.estimate_tokens(messages) == 5
    end
  end

  # -- needs_compaction? ---------------------------------------------------------

  describe "needs_compaction?/2" do
    test "returns false when under budget" do
      messages = [%{role: :user, content: "short"}]
      config = %{max_tokens: 100, preserve_recent: 2, summary_max_tokens: 500}

      refute ContextCompactor.needs_compaction?(messages, config)
    end

    test "returns true when over budget" do
      messages = [%{role: :user, content: String.duplicate("x", 500)}]
      config = %{max_tokens: 50, preserve_recent: 2, summary_max_tokens: 500}

      assert ContextCompactor.needs_compaction?(messages, config)
    end

    test "returns false at exact threshold" do
      # 1 message with content "x" (4 bytes) -> 1+1=2 content tokens + 4 overhead = 6
      messages = [%{role: :user, content: "x"}]
      config = %{max_tokens: 6, preserve_recent: 2, summary_max_tokens: 500}

      refute ContextCompactor.needs_compaction?(messages, config)
    end
  end

  # -- compact/2 -----------------------------------------------------------------

  describe "compact/2" do
    test "returns unchanged when empty" do
      result = ContextCompactor.compact([])

      assert result.messages == []
      refute result.compacted
      assert result.original_tokens == 0
      assert result.summary == nil
    end

    test "returns unchanged when under budget" do
      messages = [
        %{role: :user, content: "hello"},
        %{role: :assistant, content: "hi there"}
      ]

      config = %{max_tokens: 10_000, preserve_recent: 4, summary_max_tokens: 1_000}
      result = ContextCompactor.compact(messages, config)

      assert result.messages == messages
      refute result.compacted
      assert result.summary == nil
    end

    test "compacts when over budget" do
      messages = build_long_conversation(20)
      config = %{max_tokens: 100, preserve_recent: 2, summary_max_tokens: 1_000}

      result = ContextCompactor.compact(messages, config)

      assert result.compacted
      assert result.compacted_tokens <= result.original_tokens
      assert result.summary != nil
      assert length(result.messages) < length(messages)
    end

    test "preserves last N non-system messages" do
      messages = [
        %{role: :user, content: "first question"},
        %{role: :assistant, content: "first answer"},
        %{role: :user, content: "second question"},
        %{role: :assistant, content: "second answer"},
        %{role: :user, content: "third question"},
        %{role: :assistant, content: String.duplicate("long answer ", 100)}
      ]

      config = %{max_tokens: 50, preserve_recent: 2, summary_max_tokens: 1_000}
      result = ContextCompactor.compact(messages, config)

      assert result.compacted

      # Last 2 non-system messages should be preserved verbatim
      non_system = Enum.reject(result.messages, &(&1.role == :system))
      assert length(non_system) == 2
      assert List.last(non_system).content == List.last(messages).content
    end

    test "preserves original system messages separately" do
      messages = [
        %{role: :system, content: "You are a helpful assistant."},
        %{role: :user, content: "first"},
        %{role: :assistant, content: String.duplicate("response ", 200)},
        %{role: :user, content: "second"},
        %{role: :assistant, content: String.duplicate("response ", 200)}
      ]

      config = %{max_tokens: 50, preserve_recent: 2, summary_max_tokens: 1_000}
      result = ContextCompactor.compact(messages, config)

      assert result.compacted

      system_msgs = Enum.filter(result.messages, &(&1.role == :system))
      # Original system message + compaction summary
      assert length(system_msgs) == 2
      assert hd(system_msgs).content == "You are a helpful assistant."
    end

    test "handles all messages within preserve window" do
      messages = [
        %{role: :user, content: String.duplicate("x", 500)},
        %{role: :assistant, content: String.duplicate("y", 500)}
      ]

      config = %{max_tokens: 50, preserve_recent: 4, summary_max_tokens: 1_000}
      result = ContextCompactor.compact(messages, config)

      # Can't compact -- all messages are within preserve window
      refute result.compacted
      assert result.messages == messages
    end

    test "multi-pass re-compaction works on already-compacted history" do
      # First compaction
      messages = build_long_conversation(20)
      config = %{max_tokens: 200, preserve_recent: 2, summary_max_tokens: 1_000}
      first = ContextCompactor.compact(messages, config)
      assert first.compacted

      # Add more messages to the compacted result
      extended =
        first.messages ++
          build_long_conversation(10)

      # Second compaction
      second = ContextCompactor.compact(extended, config)
      assert second.compacted
      assert second.compacted_tokens <= second.original_tokens
    end
  end

  # -- build_summary/1 -----------------------------------------------------------

  describe "build_summary/1" do
    test "counts roles correctly" do
      messages = [
        %{role: :user, content: "q1"},
        %{role: :assistant, content: "a1"},
        %{role: :user, content: "q2"},
        %{role: :assistant, content: "a2"},
        %{role: :assistant, content: "a3"}
      ]

      summary = ContextCompactor.build_summary(messages)

      assert summary.message_count == 5
      assert summary.role_counts == %{user: 2, assistant: 3}
    end

    test "extracts recent user requests" do
      messages = [
        %{role: :user, content: "first question"},
        %{role: :assistant, content: "answer"},
        %{role: :user, content: "second question"},
        %{role: :assistant, content: "answer"},
        %{role: :user, content: "third question"}
      ]

      summary = ContextCompactor.build_summary(messages)

      assert length(summary.recent_user_requests) == 3
      assert "first question" in summary.recent_user_requests
      assert "third question" in summary.recent_user_requests
    end

    test "truncates long user requests" do
      long_request = String.duplicate("word ", 100)

      messages = [%{role: :user, content: long_request}]
      summary = ContextCompactor.build_summary(messages)

      [truncated] = summary.recent_user_requests
      assert String.ends_with?(truncated, "...")
      assert String.length(truncated) <= 203
    end

    test "extracts file paths from content" do
      messages = [
        %{role: :user, content: "Look at lib/raxol/agent.ex and test/agent_test.exs"},
        %{role: :assistant, content: "I found issues in lib/raxol/core/runtime.ex"}
      ]

      summary = ContextCompactor.build_summary(messages)

      assert "lib/raxol/agent.ex" in summary.file_paths
      assert "test/agent_test.exs" in summary.file_paths
      assert "lib/raxol/core/runtime.ex" in summary.file_paths
    end

    test "detects pending work in assistant messages" do
      messages = [
        %{role: :assistant, content: "Done with analysis."},
        %{role: :assistant, content: "Next step is to review the command module."},
        %{role: :assistant, content: "We should also check the pending tests."}
      ]

      summary = ContextCompactor.build_summary(messages)

      assert length(summary.pending_work) > 0

      assert Enum.any?(summary.pending_work, fn item ->
               String.contains?(String.downcase(item), "next")
             end)
    end

    test "returns empty lists when no relevant content" do
      messages = [
        %{role: :user, content: "hi"},
        %{role: :assistant, content: "hello"}
      ]

      summary = ContextCompactor.build_summary(messages)

      assert summary.file_paths == []
      assert summary.pending_work == []
    end
  end

  # -- format_continuation/1 -----------------------------------------------------

  describe "format_continuation/1" do
    test "produces readable summary text" do
      summary = %{
        message_count: 8,
        role_counts: %{user: 3, assistant: 5},
        recent_user_requests: ["analyze agent.ex", "review tests"],
        file_paths: ["lib/raxol/agent.ex", "test/agent_test.exs"],
        pending_work: ["Next: review command module"]
      }

      text = ContextCompactor.format_continuation(summary)

      assert String.contains?(text, "[Session compacted]")
      assert String.contains?(text, "8 earlier messages")
      assert String.contains?(text, "analyze agent.ex")
      assert String.contains?(text, "lib/raxol/agent.ex")
      assert String.contains?(text, "review command module")
      assert String.contains?(text, "Recent messages are preserved verbatim below.")
    end

    test "omits empty sections" do
      summary = %{
        message_count: 2,
        role_counts: %{user: 1, assistant: 1},
        recent_user_requests: ["hello"],
        file_paths: [],
        pending_work: []
      }

      text = ContextCompactor.format_continuation(summary)

      refute String.contains?(text, "Files discussed")
      refute String.contains?(text, "Pending")
      assert String.contains?(text, "hello")
    end
  end

  # -- Helpers -------------------------------------------------------------------

  defp build_long_conversation(n) do
    Enum.flat_map(1..n, fn i ->
      [
        %{role: :user, content: "Question #{i}: " <> String.duplicate("detail ", 20)},
        %{role: :assistant, content: "Answer #{i}: " <> String.duplicate("explanation ", 30)}
      ]
    end)
  end
end
