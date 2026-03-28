defmodule Raxol.Agent.Backend.Lumo do
  @moduledoc """
  Proton Lumo AI backend with U2L (User-to-LLM) encryption.

  Implements the full Proton Lumo wire protocol: per-request AES-256-GCM
  encryption of message turns, PGP-encrypted session key delivery, and
  SSE streaming with per-chunk decryption.

  ## Authentication

  Requires a Proton session. Set these environment variables:

      PROTON_UID=...           # Session UID (from browser or lumo-tamer)
      PROTON_ACCESS_TOKEN=...  # Bearer token

  Optional:

      PROTON_REFRESH_TOKEN=... # For automatic token refresh
      LUMO_NO_ENCRYPT=true     # Skip U2L encryption (for testing)

  ## Fallback

  If `LUMO_TAMER_URL` is set (e.g. `http://localhost:3000`), routes through
  lumo-tamer's OpenAI-compatible proxy instead of the direct Lumo API.
  This avoids the need for gpg and Proton session tokens.

  ## Requirements

  Direct mode requires `gpg` (GnuPG) for PGP encryption of the request key.
  """

  @behaviour Raxol.Agent.AIBackend

  alias Raxol.Agent.Backend.Lumo.Crypto

  @lumo_api "https://lumo.proton.me/api"
  @chat_endpoint "ai/v1/chat"
  @app_version "web-lumo@1.0.0"
  @default_timeout 60_000

  @default_tools ["proton_info"]
  @web_search_tools ["web_search", "weather", "stock", "cryptocurrency"]

  # -- AIBackend callbacks ---------------------------------------------------

  @impl true
  def complete(messages, opts \\ []) do
    case tamer_url() do
      nil -> direct_complete(messages, opts)
      url -> tamer_complete(url, messages, opts)
    end
  end

  @impl true
  def stream(messages, opts \\ []) do
    case tamer_url() do
      nil -> direct_stream(messages, opts)
      url -> tamer_stream(url, messages, opts)
    end
  end

  @impl true
  def available? do
    cond do
      tamer_url() ->
        Code.ensure_loaded?(Req)

      credentials() != nil ->
        Code.ensure_loaded?(Req) and Crypto.gpg_available?()

      true ->
        false
    end
  end

  @impl true
  def name, do: "Proton Lumo"

  @impl true
  def capabilities, do: [:completion, :streaming]

  # -- Direct Lumo API (with U2L encryption) ---------------------------------

  @spec direct_complete([map()], keyword()) ::
          {:ok, map()} | {:error, term()}
  defp direct_complete(messages, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    with {:ok, {uid, token}} <- require_credentials(),
         {:ok, payload} <- build_payload(messages, opts),
         {:ok, body} <- do_lumo_request(uid, token, payload, timeout) do
      {:ok, parse_complete_response(body)}
    end
  end

  @spec direct_stream([map()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  defp direct_stream(messages, opts) do
    with :ok <- ensure_loaded(Req),
         {:ok, {uid, token}} <- require_credentials(),
         {:ok, payload} <- build_payload(messages, opts) do
      timeout = Keyword.get(opts, :timeout, @default_timeout)
      caller = self()
      ref = make_ref()

      encryption =
        if encrypt?() do
          %{key: payload.__encryption_key, request_id: payload.__encryption_id}
        end

      task_pid =
        spawn_link(fn ->
          stream_lumo_request(uid, token, payload.body, timeout, caller, ref)
        end)

      stream =
        Stream.resource(
          fn ->
            %{
              ref: ref,
              task_pid: task_pid,
              buffer: "",
              encryption: encryption,
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

  @spec stream_next(map()) :: {[term()], map()} | {:halt, map()}
  defp stream_next(%{buffer: :halt} = state), do: {:halt, state}

  defp stream_next(%{ref: ref, buffer: buffer, encryption: enc} = state) do
    receive do
      {:sse_data, ^ref, data} ->
        {events, new_buffer} = parse_lumo_sse(buffer <> data, enc)

        chunks = for {:text_delta, text} <- events, do: {:chunk, text}

        new_content =
          state.content <> Enum.map_join(chunks, "", fn {:chunk, t} -> t end)

        {chunks, %{state | buffer: new_buffer, content: new_content}}

      {:sse_error, ^ref, error} ->
        {[{:error, error}], %{state | buffer: :halt}}

      {:sse_done, ^ref} ->
        done =
          {:done,
           %{
             content: state.content,
             usage: state.usage,
             metadata: %{backend: :lumo, provider: :proton, streamed: true}
           }}

        {[done], %{state | buffer: :halt}}
    after
      @default_timeout ->
        {:halt, state}
    end
  end

  # -- Request building ------------------------------------------------------

  @spec build_payload([map()], keyword()) ::
          {:ok, map()} | {:error, term()}
  defp build_payload(messages, opts) do
    turns = Enum.map(messages, &format_turn/1)

    tools =
      if Keyword.get(opts, :web_search, false),
        do: @default_tools ++ @web_search_tools,
        else: @default_tools

    if encrypt?() do
      build_encrypted_payload(turns, tools)
    else
      body = %{
        "Prompt" => %{
          "type" => "generation_request",
          "turns" => turns,
          "options" => %{"tools" => tools},
          "targets" => ["message"]
        }
      }

      {:ok, %{body: body, __encryption_key: nil, __encryption_id: nil}}
    end
  end

  @spec build_encrypted_payload([map()], [String.t()]) ::
          {:ok, map()} | {:error, term()}
  defp build_encrypted_payload(turns, tools) do
    key = Crypto.generate_request_key()
    request_id = Crypto.generate_request_id()

    encrypted_turns =
      Enum.map(turns, fn turn ->
        encrypted_content =
          Crypto.encrypt_turn_content(turn["content"] || "", key, request_id)

        Map.merge(turn, %{"content" => encrypted_content, "encrypted" => true})
      end)

    case Crypto.encrypt_request_key(key) do
      {:ok, encrypted_key_b64} ->
        body = %{
          "Prompt" => %{
            "type" => "generation_request",
            "turns" => encrypted_turns,
            "options" => %{"tools" => tools},
            "targets" => ["message"],
            "request_key" => encrypted_key_b64,
            "request_id" => request_id
          }
        }

        {:ok, %{body: body, __encryption_key: key, __encryption_id: request_id}}

      {:error, reason} ->
        {:error, {:pgp_encryption_failed, reason}}
    end
  end

  @spec format_turn(map()) :: map()
  defp format_turn(%{role: role, content: content}) do
    %{"role" => to_string(role), "content" => content}
  end

  # -- HTTP ------------------------------------------------------------------

  @spec do_lumo_request(String.t(), String.t(), map(), pos_integer()) ::
          {:ok, term()} | {:error, term()}
  defp do_lumo_request(uid, token, payload, timeout) do
    url = "#{@lumo_api}/#{@chat_endpoint}"

    case Req.post(url,
           json: payload.body,
           headers: lumo_headers(uid, token),
           receive_timeout: timeout
         ) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: 401}} ->
        maybe_refresh_and_retry(uid, payload, timeout)

      {:ok, %{status: status, body: body}} ->
        error_msg = if is_map(body), do: Map.get(body, "Error", ""), else: ""
        {:error, {:http_error, status, error_msg}}

      {:error, reason} ->
        {:error, {:request_failed, reason}}
    end
  end

  @spec stream_lumo_request(
          String.t(),
          String.t(),
          map(),
          pos_integer(),
          pid(),
          reference()
        ) :: :ok
  defp stream_lumo_request(uid, token, body, timeout, caller, ref) do
    url = "#{@lumo_api}/#{@chat_endpoint}"

    try do
      case Req.post(url,
             json: body,
             headers: lumo_headers(uid, token, stream: true),
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

  @spec lumo_headers(String.t(), String.t(), keyword()) :: [
          {String.t(), String.t()}
        ]
  defp lumo_headers(uid, token, opts \\ []) do
    base = [
      {"content-type", "application/json"},
      {"x-pm-uid", uid},
      {"x-pm-appversion", @app_version},
      {"authorization", "Bearer #{token}"}
    ]

    if Keyword.get(opts, :stream, false) do
      [{"accept", "text/event-stream"} | base]
    else
      base
    end
  end

  # -- SSE parsing -----------------------------------------------------------

  @spec parse_lumo_sse(binary(), map() | nil) :: {[term()], binary()}
  defp parse_lumo_sse(raw, encryption) do
    lines = String.split(raw, "\n")
    {complete, [buffer]} = Enum.split(lines, -1)

    events =
      complete
      |> Enum.filter(&String.starts_with?(&1, "data:"))
      |> Enum.flat_map(fn line ->
        json_str =
          String.replace_prefix(line, "data:", "") |> String.trim_leading()

        parse_lumo_event(json_str, encryption)
      end)

    {events, buffer}
  end

  @spec parse_lumo_event(binary(), map() | nil) :: [term()]
  defp parse_lumo_event(json_str, encryption) do
    case Jason.decode(json_str) do
      {:ok, %{"type" => "token_data", "target" => "message"} = msg} ->
        content = decrypt_content(msg, encryption)
        [{:text_delta, content}]

      {:ok, %{"type" => "done"}} ->
        [{:usage, %{}}]

      {:ok, %{"type" => type, "message" => message}}
      when type in ["error", "rejected", "harmful", "timeout"] ->
        [{:error, message}]

      {:ok, %{"type" => type}}
      when type in ["error", "rejected", "harmful", "timeout"] ->
        [{:error, type}]

      _ ->
        []
    end
  end

  @spec decrypt_content(map(), map() | nil) :: binary()
  defp decrypt_content(%{"content" => content, "encrypted" => true}, %{
         key: key,
         request_id: id
       })
       when is_binary(key) do
    case Crypto.decrypt_chunk(content, key, id) do
      {:ok, plaintext} -> plaintext
      {:error, _} -> content
    end
  end

  defp decrypt_content(%{"content" => content}, _encryption), do: content

  # -- Response parsing (non-streaming) --------------------------------------

  @spec parse_complete_response(term()) :: map()
  defp parse_complete_response(body) when is_binary(body) do
    %{
      content: body,
      usage: %{},
      metadata: %{backend: :lumo, provider: :proton}
    }
  end

  defp parse_complete_response(body) when is_map(body) do
    %{
      content: Map.get(body, "content", inspect(body)),
      usage: %{},
      metadata: %{backend: :lumo, provider: :proton}
    }
  end

  # -- Token refresh ---------------------------------------------------------

  @spec maybe_refresh_and_retry(String.t(), map(), pos_integer()) ::
          {:ok, term()} | {:error, term()}
  defp maybe_refresh_and_retry(uid, payload, timeout) do
    case refresh_token() do
      nil ->
        {:error,
         {:auth_expired, "Access token expired. Re-authenticate or set PROTON_REFRESH_TOKEN."}}

      refresh_tok ->
        case do_token_refresh(uid, refresh_tok) do
          {:ok, new_uid, new_token} ->
            System.put_env("PROTON_UID", new_uid)
            System.put_env("PROTON_ACCESS_TOKEN", new_token)
            do_lumo_request(new_uid, new_token, payload, timeout)

          {:error, reason} ->
            {:error, {:refresh_failed, reason}}
        end
    end
  end

  @spec do_token_refresh(String.t(), String.t()) ::
          {:ok, String.t(), String.t()} | {:error, String.t()}
  defp do_token_refresh(uid, refresh_tok) do
    body = %{
      "UID" => uid,
      "RefreshToken" => refresh_tok,
      "ResponseType" => "token",
      "GrantType" => "refresh_token",
      "RedirectURI" => "https://protonmail.com"
    }

    url = "https://account.proton.me/api/auth/refresh"

    headers = [
      {"content-type", "application/json"},
      {"x-pm-uid", uid},
      {"x-pm-appversion", @app_version}
    ]

    case Req.post(url, json: body, headers: headers) do
      {:ok, %{status: 200, body: resp}} ->
        {:ok, resp["UID"], resp["AccessToken"]}

      {:ok, %{status: status}} ->
        {:error, "refresh returned #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  # -- lumo-tamer fallback (OpenAI-compatible) -------------------------------

  @spec tamer_complete(String.t(), [map()], keyword()) ::
          {:ok, map()} | {:error, term()}
  defp tamer_complete(base_url, messages, opts) do
    Raxol.Agent.Backend.HTTP.complete(messages, tamer_opts(base_url, opts))
  end

  @spec tamer_stream(String.t(), [map()], keyword()) ::
          {:ok, Enumerable.t()} | {:error, term()}
  defp tamer_stream(base_url, messages, opts) do
    Raxol.Agent.Backend.HTTP.stream(messages, tamer_opts(base_url, opts))
  end

  @spec tamer_opts(String.t(), keyword()) :: keyword()
  defp tamer_opts(base_url, opts) do
    Keyword.merge(opts,
      provider: :openai,
      api_key: "unused",
      base_url: base_url,
      model: Keyword.get(opts, :model, "lumo")
    )
  end

  # -- Config helpers --------------------------------------------------------

  @spec credentials() :: {String.t(), String.t()} | nil
  defp credentials do
    uid = System.get_env("PROTON_UID")
    token = System.get_env("PROTON_ACCESS_TOKEN")

    if uid && token, do: {uid, token}
  end

  @spec require_credentials() ::
          {:ok, {String.t(), String.t()}} | {:error, :missing_credentials}
  defp require_credentials do
    case credentials() do
      nil -> {:error, :missing_credentials}
      {uid, token} -> {:ok, {uid, token}}
    end
  end

  @spec refresh_token() :: String.t() | nil
  defp refresh_token, do: System.get_env("PROTON_REFRESH_TOKEN")

  @spec tamer_url() :: String.t() | nil
  defp tamer_url, do: System.get_env("LUMO_TAMER_URL")

  @spec encrypt?() :: boolean()
  defp encrypt? do
    System.get_env("LUMO_NO_ENCRYPT") not in ["true", "1"]
  end

  defp ensure_loaded(mod) do
    if Code.ensure_loaded?(mod), do: :ok, else: {:error, :req_not_available}
  end
end
