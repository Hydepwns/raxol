defmodule Raxol.Agent.AIBackend do
  @moduledoc """
  Behaviour for pluggable AI model integration.

  Agents are backend-agnostic -- they call `complete/2` or `stream/2`
  and the backend handles the model-specific HTTP/inference details.

  Implementations:
  - `Raxol.Agent.Backend.HTTP` -- Req-based client for Claude, GPT, Ollama, Kimi
  - `Raxol.Agent.Backend.Lumo` -- Proton Lumo with U2L encryption (or lumo-tamer proxy)
  - `Raxol.Agent.Backend.Mock` -- Deterministic responses for testing
  """

  @type message :: %{role: :system | :user | :assistant, content: String.t()}
  @type response :: %{content: String.t(), usage: map(), metadata: map()}
  @type stream_event ::
          {:chunk, String.t()} | {:done, response()} | {:error, term()}

  @doc "Send messages and receive a complete response."
  @callback complete([message()], opts :: keyword()) ::
              {:ok, response()} | {:error, term()}

  @doc "Send messages and receive a stream of events."
  @callback stream([message()], opts :: keyword()) ::
              {:ok, Enumerable.t()} | {:error, term()}

  @doc "Check if the backend is currently available."
  @callback available?() :: boolean()

  @doc "Human-readable name of the backend."
  @callback name() :: String.t()

  @doc "List of supported capabilities."
  @callback capabilities() :: [:completion | :streaming | :tool_use | :vision]

  @optional_callbacks [stream: 2]
end
