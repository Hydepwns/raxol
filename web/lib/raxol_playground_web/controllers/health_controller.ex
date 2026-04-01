defmodule RaxolPlaygroundWeb.HealthController do
  use RaxolPlaygroundWeb, :controller

  @memory_warn_mb String.to_integer(
                    System.get_env("HEALTH_MEMORY_WARN_MB") || "500"
                  )
  @memory_crit_mb String.to_integer(
                    System.get_env("HEALTH_MEMORY_CRIT_MB") || "900"
                  )

  def check(conn, _params) do
    checks = %{
      pubsub: check_pubsub(),
      memory: check_memory(),
      ssh: check_ssh()
    }

    all_ok = Enum.all?(checks, fn {_k, v} -> v in ["ok", "not_configured"] end)

    status = %{
      status: if(all_ok, do: "healthy", else: "degraded"),
      version: Application.spec(:raxol_playground, :vsn) |> to_string(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: checks
    }

    http_status = if all_ok, do: 200, else: 503

    conn
    |> put_status(http_status)
    |> put_resp_content_type("application/json")
    |> json(status)
  end

  defp check_pubsub do
    case Process.whereis(Raxol.PubSub) do
      nil -> "down"
      pid when is_pid(pid) -> if Process.alive?(pid), do: "ok", else: "down"
    end
  rescue
    _ -> "error"
  end

  defp check_ssh do
    if System.get_env("RAXOL_SSH_PLAYGROUND") == "true" do
      port = String.to_integer(System.get_env("RAXOL_SSH_PORT") || "2222")

      case :gen_tcp.connect(~c"127.0.0.1", port, [], 2_000) do
        {:ok, socket} ->
          :gen_tcp.close(socket)
          "ok"

        {:error, _} ->
          "down"
      end
    else
      "not_configured"
    end
  rescue
    _ -> "error"
  end

  defp check_memory do
    total_mb = :erlang.memory(:total) / 1_048_576

    cond do
      total_mb > @memory_crit_mb -> "critical"
      total_mb > @memory_warn_mb -> "warning"
      true -> "ok"
    end
  end
end
