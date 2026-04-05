defmodule RaxolMcp do
  @moduledoc """
  MCP (Model Context Protocol) server and client for Raxol.

  Provides a standalone MCP implementation with:

  - `Raxol.MCP.Protocol` -- JSON-RPC 2.0 encoding/decoding
  - `Raxol.MCP.Registry` -- ETS-backed tool/resource registration
  - `Raxol.MCP.Server` -- transport-agnostic message router
  - `Raxol.MCP.Transport.Stdio` -- stdio transport for CLI tools
  - `Raxol.MCP.Transport.SSE` -- HTTP/SSE transport (Plug-based)
  - `Raxol.MCP.Client` -- client for consuming external MCP servers
  """

  @version Mix.Project.config()[:version]

  @doc "Returns the package version."
  @spec version() :: String.t()
  def version, do: @version
end
