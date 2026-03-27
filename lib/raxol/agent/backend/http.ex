defmodule Raxol.Agent.Backend.HTTP do
  @moduledoc """
  HTTP-based AI backend using Req.

  Supports Claude (Anthropic), GPT (OpenAI-compatible), and Ollama APIs.
  The provider is auto-detected from the base URL or can be set explicitly.

  ## Configuration

      opts = [
        api_key: "sk-...",
        base_url: "https://api.anthropic.com",
        model: "claude-sonnet-4-20250514",
        provider: :anthropic,  # or :openai, :ollama (auto-detected if omitted)
        timeout: 30_000
      ]
  """

  @behaviour Raxol.Agent.AIBackend

  require Raxol.Core.Runtime.Log

  @default_timeout 30_000
  @default_max_tokens 1_024
  @anthropic_api_version "2023-06-01"
  @default_ollama_port "11434"

  @impl true
  def complete(messages, opts \\ []) do
    provider = detect_provider(opts)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    {url, headers, body} = build_request(provider, messages, opts)

    case do_request(url, headers, body, timeout) do
      {:ok, response_body} ->
        {:ok, parse_response(provider, response_body)}

      {:error, _} = error ->
        error
    end
  end

  @impl true
  def available? do
    Code.ensure_loaded?(Req)
  end

  @impl true
  def name, do: "HTTP Backend"

  @impl true
  def capabilities, do: [:completion, :streaming]

  @impl true
  def stream(messages, opts \\ []) do
    if not available?() do
      {:error, :req_not_available}
    else
      provider = detect_provider(opts)
      timeout = Keyword.get(opts, :timeout, @default_timeout)
      {url, headers, body} = build_request(provider, messages, opts)
      body = Map.put(body, :stream, true)

      caller = self()
      ref = make_ref()

      task_pid =
        spawn_link(fn ->
          stream_request(url, headers, body, timeout, caller, ref)
        end)

      stream =
        Stream.resource(
          fn ->
            %{
              ref: ref,
              task_pid: task_pid,
              buffer: "",
              provider: provider,
              content: "",
              usage: %{}
            }
          end,
          &stream_next/1,
          fn %{task_pid: pid} ->
            if Process.alive?(pid), do: Process.exit(pid, :normal)
          end
        )

      {:ok, stream}
    end
  end

  defp stream_request(url, headers, body, timeout, caller, ref) do
    try do
      case Req.post(url,
             json: body,
             headers: headers,
             receive_timeout: timeout,
             into: fn {:data, data}, {req, resp} ->
               send(caller, {:sse_data, ref, data})
               {:cont, {req, resp}}
             end
           ) do
        {:ok, %{status: status}} when status in 200..299 ->
          :ok

        {:ok, %{status: status}} ->
          send(caller, {:sse_error, ref, "HTTP #{status}"})

        {:error, reason} ->
          send(caller, {:sse_error, ref, inspect(reason)})
      end
    rescue
      e -> send(caller, {:sse_error, ref, Exception.message(e)})
    end

    send(caller, {:sse_done, ref})
  end

  defp stream_next(%{buffer: :halt} = state), do: {:halt, state}

  defp stream_next(%{ref: ref, buffer: buffer, provider: provider} = state) do
    receive do
      {:sse_data, ^ref, data} ->
        {events, new_buffer} = parse_sse(buffer <> data, provider)

        chunks = for {:text_delta, text} <- events, do: {:chunk, text}

        new_content =
          state.content <> Enum.map_join(chunks, "", fn {:chunk, t} -> t end)

        new_usage =
          case Enum.find(events, &match?({:usage, _}, &1)) do
            {:usage, u} -> u
            nil -> state.usage
          end

        {chunks,
         %{state | buffer: new_buffer, content: new_content, usage: new_usage}}

      {:sse_error, ^ref, error} ->
        {[{:error, error}], %{state | buffer: :halt}}

      {:sse_done, ^ref} ->
        done =
          {:done,
           %{
             content: state.content,
             usage: state.usage,
             metadata: %{
               backend: :http,
               provider: state.provider,
               streamed: true
             }
           }}

        {[done], %{state | buffer: :halt}}
    after
      60_000 ->
        {:halt, state}
    end
  end

  # -- SSE parsing -------------------------------------------------------------

  defp parse_sse(raw, :ollama) do
    lines = String.split(raw, "\n")
    {complete, [buffer]} = Enum.split(lines, -1)

    events =
      complete
      |> Enum.reject(&(&1 == ""))
      |> Enum.flat_map(fn line ->
        case Jason.decode(line) do
          {:ok, %{"done" => true}} -> [{:usage, %{}}]
          {:ok, %{"message" => %{"content" => text}}} -> [{:text_delta, text}]
          _ -> []
        end
      end)

    {events, buffer}
  end

  defp parse_sse(raw, provider) when provider in [:anthropic, :openai] do
    parts = String.split(raw, "\n\n")

    case parts do
      [single] ->
        {[], single}

      multiple ->
        {complete, [buffer]} = Enum.split(multiple, -1)

        events =
          complete
          |> Enum.reject(&(&1 == ""))
          |> Enum.flat_map(&parse_sse_event(&1, provider))

        {events, buffer}
    end
  end

  defp parse_sse_event(event_text, :anthropic) do
    data_line =
      event_text
      |> String.split("\n")
      |> Enum.find(&String.starts_with?(&1, "data: "))

    with "data: " <> json <- data_line,
         {:ok, parsed} <- Jason.decode(json) do
      case parsed do
        %{"type" => "content_block_delta", "delta" => %{"text" => text}} ->
          [{:text_delta, text}]

        %{"type" => "message_delta", "usage" => usage} ->
          [{:usage, usage}]

        _ ->
          []
      end
    else
      _ -> []
    end
  end

  defp parse_sse_event(event_text, :openai) do
    data_line =
      event_text
      |> String.split("\n")
      |> Enum.find(&String.starts_with?(&1, "data: "))

    with "data: " <> data <- data_line do
      if data == "[DONE]" do
        [{:usage, %{}}]
      else
        case Jason.decode(data) do
          {:ok, %{"choices" => [%{"delta" => %{"content" => text}} | _]}}
          when is_binary(text) ->
            [{:text_delta, text}]

          _ ->
            []
        end
      end
    else
      _ -> []
    end
  end

  # -- Request building -------------------------------------------------------

  defp build_request(:anthropic, messages, opts) do
    base_url = Keyword.get(opts, :base_url, "https://api.anthropic.com")
    api_key = Keyword.fetch!(opts, :api_key)
    model = Keyword.get(opts, :model, "claude-sonnet-4-20250514")

    {system_msgs, chat_msgs} = split_system_messages(messages)
    system_text = Enum.map_join(system_msgs, "\n", & &1.content)

    url = "#{base_url}/v1/messages"

    headers = [
      {"x-api-key", api_key},
      {"anthropic-version", @anthropic_api_version},
      {"content-type", "application/json"}
    ]

    body = %{
      model: model,
      max_tokens: Keyword.get(opts, :max_tokens, @default_max_tokens),
      messages: Enum.map(chat_msgs, &format_message/1)
    }

    body =
      if system_text != "", do: Map.put(body, :system, system_text), else: body

    {url, headers, body}
  end

  defp build_request(:openai, messages, opts) do
    base_url = Keyword.get(opts, :base_url, "https://api.openai.com")
    api_key = Keyword.fetch!(opts, :api_key)
    model = Keyword.get(opts, :model, "gpt-4o")

    url = "#{base_url}/v1/chat/completions"

    headers = [
      {"authorization", "Bearer #{api_key}"},
      {"content-type", "application/json"}
    ]

    body = %{
      model: model,
      messages: Enum.map(messages, &format_message/1),
      max_tokens: Keyword.get(opts, :max_tokens, @default_max_tokens)
    }

    {url, headers, body}
  end

  defp build_request(:ollama, messages, opts) do
    base_url = Keyword.get(opts, :base_url, "http://localhost:11434")
    model = Keyword.get(opts, :model, "llama3")

    url = "#{base_url}/api/chat"
    headers = [{"content-type", "application/json"}]

    body = %{
      model: model,
      messages: Enum.map(messages, &format_message/1),
      stream: false
    }

    {url, headers, body}
  end

  # -- Response parsing -------------------------------------------------------

  defp parse_response(
         :anthropic,
         %{"content" => [%{"text" => text} | _]} = body
       ) do
    %{
      content: text,
      usage: Map.get(body, "usage", %{}),
      metadata: %{
        backend: :http,
        provider: :anthropic,
        model: Map.get(body, "model"),
        stop_reason: Map.get(body, "stop_reason")
      }
    }
  end

  defp parse_response(
         :openai,
         %{"choices" => [%{"message" => %{"content" => text}} | _]} = body
       ) do
    %{
      content: text,
      usage: Map.get(body, "usage", %{}),
      metadata: %{
        backend: :http,
        provider: :openai,
        model: Map.get(body, "model")
      }
    }
  end

  defp parse_response(:ollama, %{"message" => %{"content" => text}} = body) do
    %{
      content: text,
      usage: %{},
      metadata: %{
        backend: :http,
        provider: :ollama,
        model: Map.get(body, "model"),
        eval_duration: Map.get(body, "eval_duration")
      }
    }
  end

  defp parse_response(_provider, body) do
    %{
      content: inspect(body),
      usage: %{},
      metadata: %{backend: :http, raw: true}
    }
  end

  # -- Helpers ----------------------------------------------------------------

  defp do_request(url, headers, body, timeout) do
    if Code.ensure_loaded?(Req) do
      case Req.post(url, json: body, headers: headers, receive_timeout: timeout) do
        {:ok, %{status: status, body: resp_body}} when status in 200..299 ->
          {:ok, resp_body}

        {:ok, %{status: status, body: resp_body}} ->
          {:error, {:http_error, status, resp_body}}

        {:error, reason} ->
          {:error, {:request_failed, reason}}
      end
    else
      {:error, :req_not_available}
    end
  end

  defp detect_provider(opts) do
    case Keyword.get(opts, :provider) do
      nil ->
        base_url = Keyword.get(opts, :base_url, "")

        cond do
          String.contains?(base_url, "anthropic") ->
            :anthropic

          String.contains?(base_url, "ollama") or
              String.contains?(base_url, @default_ollama_port) ->
            :ollama

          true ->
            :openai
        end

      provider ->
        provider
    end
  end

  defp split_system_messages(messages) do
    Enum.split_with(messages, fn msg -> msg.role == :system end)
  end

  defp format_message(%{role: role, content: content}) do
    %{role: to_string(role), content: content}
  end
end
