defmodule Raxol.Endpoint do
  @moduledoc """
  Dev-only Phoenix endpoint for Tidewave MCP integration.

  Serves Tidewave at `localhost:4000/tidewave/mcp`, enabling Claude Code
  and other MCP clients to interact with the running BEAM via `project_eval`
  and custom Raxol headless session tools.
  """

  use Phoenix.Endpoint, otp_app: :raxol

  # Tidewave must be placed BEFORE request body parsing
  if Code.ensure_loaded?(Tidewave) do
    plug Tidewave
  end

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Jason

  plug :health_check
  plug :not_found

  defp health_check(%Plug.Conn{path_info: ["health"]} = conn, _opts) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(%{status: "ok"}))
    |> Plug.Conn.halt()
  end

  defp health_check(conn, _opts), do: conn

  defp not_found(%Plug.Conn{state: :sent} = conn, _opts), do: conn

  defp not_found(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(404, Jason.encode!(%{error: "not_found"}))
    |> Plug.Conn.halt()
  end
end
