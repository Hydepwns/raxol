defmodule Raxol.Agent.ContextCompactor do
  @moduledoc """
  Token-aware message history compaction for agent sessions.

  When an agent's conversation history exceeds a token budget,
  older messages are summarized into a single system message
  while preserving recent messages verbatim.

  ## Usage

      config = %{max_tokens: 8_000, preserve_recent: 4}

      case ContextCompactor.compact(messages, config) do
        %{compacted: true, messages: compacted_messages} ->
          # Use compacted_messages for next LLM call
        %{compacted: false} ->
          # History is within budget, no changes needed
      end

  Token estimation uses a simple byte_size/4 heuristic (no tokenizer dependency).
  Summaries are generated purely from message metadata -- no LLM call required.
  """

  @type message :: %{role: atom(), content: String.t()}

  @type config :: %{
          max_tokens: pos_integer(),
          preserve_recent: pos_integer(),
          summary_max_tokens: pos_integer()
        }

  @type compaction_result :: %{
          messages: [message()],
          compacted: boolean(),
          original_tokens: non_neg_integer(),
          compacted_tokens: non_neg_integer(),
          summary: String.t() | nil
        }

  @type summary :: %{
          message_count: non_neg_integer(),
          role_counts: %{atom() => non_neg_integer()},
          recent_user_requests: [String.t()],
          key_topics: [String.t()],
          file_paths: [String.t()],
          pending_work: [String.t()]
        }

  @default_config %{
    max_tokens: 8_000,
    preserve_recent: 4,
    summary_max_tokens: 1_000
  }

  @file_path_regex ~r"(?:^|[\s\"'`(])([a-zA-Z_./][a-zA-Z0-9_./\-]*\.(?:ex|exs|erl|hrl|rs|ts|js|py|rb|go|md|json|toml|yaml|yml|sh|sql|html|css))\b"

  @pending_keywords ~w(todo next pending will should must need)

  @user_request_max_chars 200
  @message_overhead 4

  # -- Public API ---------------------------------------------------------------

  @doc """
  Estimate token count for a string or message list.

  Uses a byte_size/4 heuristic. Not exact, but sufficient for budget decisions.
  """
  @spec estimate_tokens(String.t()) :: non_neg_integer()
  def estimate_tokens(text) when is_binary(text) do
    div(byte_size(text), 4) + 1
  end

  @spec estimate_tokens([message()]) :: non_neg_integer()
  def estimate_tokens(messages) when is_list(messages) do
    Enum.reduce(messages, 0, fn msg, acc ->
      acc + estimate_tokens(message_content(msg)) + @message_overhead
    end)
  end

  @doc """
  Check if compaction is needed for the given messages.
  """
  @spec needs_compaction?([message()], config()) :: boolean()
  def needs_compaction?(messages, config \\ @default_config) do
    estimate_tokens(messages) > config.max_tokens
  end

  @doc """
  Compact messages if over token budget.

  Splits system messages from conversation, preserves the last N non-system
  messages verbatim, and summarizes the rest into a continuation system message.

  Returns a `compaction_result` map. If no compaction was needed, `compacted`
  is `false` and messages are returned unchanged.
  """
  @spec compact([message()], config()) :: compaction_result()
  def compact(messages, config \\ @default_config)

  def compact([], _config) do
    %{
      messages: [],
      compacted: false,
      original_tokens: 0,
      compacted_tokens: 0,
      summary: nil
    }
  end

  def compact(messages, config) do
    total = estimate_tokens(messages)

    if total <= config.max_tokens do
      %{
        messages: messages,
        compacted: false,
        original_tokens: total,
        compacted_tokens: total,
        summary: nil
      }
    else
      do_compact(messages, config, total)
    end
  end

  @doc """
  Build a structured summary from a list of messages.

  Extracts metadata (role counts, file paths, recent requests, pending work)
  without requiring an LLM call.
  """
  @spec build_summary([message()]) :: summary()
  def build_summary(messages) when is_list(messages) do
    %{
      message_count: length(messages),
      role_counts: count_by_role(messages),
      recent_user_requests: extract_recent_user(messages, 3),
      key_topics: extract_topics(messages),
      file_paths: extract_file_paths(messages),
      pending_work: extract_pending(messages)
    }
  end

  @doc """
  Format a summary struct into a human-readable continuation message.
  """
  @spec format_continuation(summary()) :: String.t()
  def format_continuation(summary) do
    role_desc = format_role_counts(summary.role_counts)

    header = [
      "[Session compacted] This conversation continues from a previous exchange.",
      "Summary of #{summary.message_count} earlier messages (#{role_desc}):"
    ]

    body =
      []
      |> maybe_add_section("Pending", summary.pending_work)
      |> maybe_add_section("Files discussed", summary.file_paths)
      |> maybe_add_section("Recent requests", summary.recent_user_requests)

    (header ++ body)
    |> Enum.join("\n\n")
    |> then(&(&1 <> "\n\nRecent messages are preserved verbatim below."))
  end

  # -- Private: Compaction -------------------------------------------------------

  defp do_compact(messages, config, original_tokens) do
    {system_msgs, non_system} = Enum.split_with(messages, &(&1.role == :system))

    {compactable, preserved} =
      split_preserve(non_system, config.preserve_recent)

    if compactable == [] do
      %{
        messages: messages,
        compacted: false,
        original_tokens: original_tokens,
        compacted_tokens: original_tokens,
        summary: nil
      }
    else
      summary = build_summary(compactable)
      continuation = format_continuation(summary)

      # Truncate summary if it exceeds the summary token budget
      continuation = truncate_to_tokens(continuation, config.summary_max_tokens)

      summary_msg = %{role: :system, content: continuation}
      compacted = system_msgs ++ [summary_msg] ++ preserved

      %{
        messages: compacted,
        compacted: true,
        original_tokens: original_tokens,
        compacted_tokens: estimate_tokens(compacted),
        summary: continuation
      }
    end
  end

  # -- Private: Summary Extraction -----------------------------------------------

  defp count_by_role(messages) do
    Enum.frequencies_by(messages, & &1.role)
  end

  defp extract_recent_user(messages, n) do
    messages
    |> Enum.filter(&(&1.role == :user))
    |> Enum.take(-n)
    |> Enum.map(fn msg ->
      msg |> message_content() |> truncate(@user_request_max_chars)
    end)
  end

  defp extract_file_paths(messages) do
    messages
    |> Enum.flat_map(fn msg ->
      Regex.scan(@file_path_regex, message_content(msg), capture: :all_but_first)
    end)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.take(20)
  end

  defp extract_pending(messages) do
    messages
    |> Enum.filter(&(&1.role == :assistant))
    |> Enum.take(-3)
    |> Enum.flat_map(fn msg ->
      msg
      |> message_content()
      |> String.split("\n")
      |> Enum.filter(&line_has_pending_keyword?/1)
      |> Enum.map(&String.trim/1)
      |> Enum.take(3)
    end)
    |> Enum.uniq()
    |> Enum.take(5)
  end

  defp line_has_pending_keyword?(line) do
    lower = String.downcase(line)
    Enum.any?(@pending_keywords, &String.contains?(lower, &1))
  end

  defp extract_topics(messages) do
    messages
    |> Enum.flat_map(fn msg ->
      msg
      |> message_content()
      |> String.split(~r/[\s,.:;!?\[\](){}<>]+/)
      |> Enum.filter(&(String.length(&1) > 4))
      |> Enum.map(&String.downcase/1)
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_word, count} -> -count end)
    |> Enum.take(10)
    |> Enum.map(fn {word, _count} -> word end)
  end

  # -- Private: Formatting -------------------------------------------------------

  defp format_role_counts(counts) do
    counts
    |> Enum.sort()
    |> Enum.map_join(", ", fn {role, count} -> "#{count} #{role}" end)
  end

  defp maybe_add_section(sections, _label, []), do: sections

  defp maybe_add_section(sections, "Files discussed", items) do
    ["Files discussed: #{Enum.join(items, ", ")}" | sections]
  end

  defp maybe_add_section(sections, label, items) do
    bullet_list = Enum.map_join(items, "\n", &("- " <> &1))
    ["#{label}:\n#{bullet_list}" | sections]
  end

  # -- Private: Helpers -----------------------------------------------------------

  defp message_content(%{content: content}) when is_binary(content), do: content
  defp message_content(_), do: ""

  defp truncate(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end

  defp split_preserve(list, n) do
    len = length(list)

    if len <= n do
      {[], list}
    else
      Enum.split(list, len - n)
    end
  end

  defp truncate_to_tokens(text, max_tokens) do
    if estimate_tokens(text) > max_tokens do
      max_bytes = (max_tokens - 1) * 4
      String.slice(text, 0, max_bytes)
    else
      text
    end
  end
end
