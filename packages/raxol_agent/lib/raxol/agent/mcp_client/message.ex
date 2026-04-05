defmodule Raxol.Agent.McpClient.Message do
  @moduledoc """
  JSON-RPC 2.0 message encoding/decoding for MCP.

  This module delegates to `Raxol.MCP.Protocol`. Use `Raxol.MCP.Protocol`
  directly for new code.
  """

  @compile {:no_warn_undefined, Raxol.MCP.Protocol}

  defdelegate request(id, method, params \\ %{}), to: Raxol.MCP.Protocol
  defdelegate notification(method, params \\ %{}), to: Raxol.MCP.Protocol
  defdelegate encode(message), to: Raxol.MCP.Protocol
  defdelegate decode(json), to: Raxol.MCP.Protocol
  defdelegate response?(msg), to: Raxol.MCP.Protocol
  defdelegate error?(msg), to: Raxol.MCP.Protocol
  defdelegate notification?(msg), to: Raxol.MCP.Protocol
end
