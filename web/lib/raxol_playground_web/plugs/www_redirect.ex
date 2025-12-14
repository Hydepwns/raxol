defmodule RaxolPlaygroundWeb.Plugs.WwwRedirect do
  @moduledoc """
  Redirects www subdomain requests to the non-www domain.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(%{host: "www." <> rest} = conn, _opts) do
    url = %{
      scheme: get_scheme(conn),
      host: rest,
      port: get_port(conn),
      path: conn.request_path,
      query: conn.query_string
    }
    |> build_url()

    conn
    |> put_resp_header("location", url)
    |> send_resp(301, "")
    |> halt()
  end

  def call(conn, _opts), do: conn

  defp get_scheme(conn) do
    case get_req_header(conn, "x-forwarded-proto") do
      [proto | _] -> proto
      [] -> to_string(conn.scheme)
    end
  end

  defp get_port(conn) do
    case get_req_header(conn, "x-forwarded-port") do
      [port | _] -> String.to_integer(port)
      [] -> conn.port
    end
  end

  defp build_url(%{scheme: scheme, host: host, port: port, path: path, query: query}) do
    base = "#{scheme}://#{host}"

    base =
      case {scheme, port} do
        {"https", 443} -> base
        {"http", 80} -> base
        {_, port} -> "#{base}:#{port}"
      end

    base = base <> path

    case query do
      "" -> base
      query -> base <> "?" <> query
    end
  end
end
