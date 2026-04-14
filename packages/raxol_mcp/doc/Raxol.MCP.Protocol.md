# `Raxol.MCP.Protocol`
[🔗](https://github.com/DROOdotFOO/raxol/blob/v2.4.0/lib/raxol/mcp/protocol.ex#L1)

JSON-RPC 2.0 message encoding/decoding for the Model Context Protocol.

Handles both client-side (requests, notifications) and server-side
(responses, error responses) message construction. All MCP communication
flows through this module.

# `error_response`

```elixir
@type error_response() :: %{
  jsonrpc: String.t(),
  id: pos_integer() | nil,
  error: %{code: integer(), message: String.t()}
}
```

# `notification`

```elixir
@type notification() :: %{jsonrpc: String.t(), method: String.t(), params: map()}
```

# `request`

```elixir
@type request() :: %{
  jsonrpc: String.t(),
  id: pos_integer(),
  method: String.t(),
  params: map()
}
```

# `response`

```elixir
@type response() :: %{jsonrpc: String.t(), id: pos_integer(), result: term()}
```

# `decode`

```elixir
@spec decode(String.t()) :: {:ok, map()} | {:error, term()}
```

Decode a JSON string into a message map with atom keys for known fields.

# `encode`

```elixir
@spec encode(map()) :: {:ok, iodata()} | {:error, term()}
```

Encode a message to a JSON string with newline delimiter.

# `encode!`

```elixir
@spec encode!(map()) :: iodata()
```

Encode a message, raising on failure.

Returns iodata (JSON + newline).

# `error?`

```elixir
@spec error?(map()) :: boolean()
```

Check if a decoded message is an error response.

# `error_response`

```elixir
@spec error_response(pos_integer() | nil, integer(), String.t(), term()) ::
  error_response()
```

Build a JSON-RPC error response.

# `internal_error`

```elixir
@spec internal_error() :: integer()
```

JSON-RPC internal error code (-32603).

# `invalid_params`

```elixir
@spec invalid_params() :: integer()
```

JSON-RPC invalid params code (-32602).

# `invalid_request`

```elixir
@spec invalid_request() :: integer()
```

JSON-RPC invalid request code (-32600).

# `mcp_protocol_version`

```elixir
@spec mcp_protocol_version() :: String.t()
```

MCP protocol version string.

# `method_not_found`

```elixir
@spec method_not_found() :: integer()
```

JSON-RPC method not found code (-32601).

# `notification`

```elixir
@spec notification(String.t(), map()) :: notification()
```

Build a JSON-RPC notification (no id, no response expected).

# `notification?`

```elixir
@spec notification?(map()) :: boolean()
```

Check if a decoded message is a notification (no id).

# `parse_error`

```elixir
@spec parse_error() :: integer()
```

JSON-RPC parse error code (-32700).

# `request`

```elixir
@spec request(pos_integer(), String.t(), map()) :: request()
```

Build a JSON-RPC request.

# `request?`

```elixir
@spec request?(map()) :: boolean()
```

Check if a decoded message is a request (has id + method).

# `response`

```elixir
@spec response(pos_integer(), term()) :: response()
```

Build a JSON-RPC success response.

# `response?`

```elixir
@spec response?(map()) :: boolean()
```

Check if a decoded message is a response (has id + result or error).

---

*Consult [api-reference.md](api-reference.md) for complete listing*
