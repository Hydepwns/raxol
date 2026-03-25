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
  def capabilities, do: [:completion]

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
