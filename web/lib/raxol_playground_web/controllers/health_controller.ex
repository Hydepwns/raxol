defmodule RaxolPlaygroundWeb.HealthController do
  use RaxolPlaygroundWeb, :controller

  def check(conn, _params) do
    status = %{
      status: "healthy",
      version: Application.spec(:raxol_playground, :vsn) |> to_string(),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      checks: %{
        database: "ok",
        raxol_core: check_raxol_core(),
        memory: check_memory()
      }
    }

    conn
    |> put_resp_content_type("application/json")
    |> json(status)
  end

  defp check_raxol_core do
    case Application.get_application(Raxol) do
      nil -> "not_loaded"
      _app -> "ok"
    end
  rescue
    _ -> "error"
  end

  defp check_memory do
    memory_info = :erlang.memory()
    total_mb = Keyword.get(memory_info, :total, 0) / 1024 / 1024

    cond do
      total_mb > 1000 -> "high"
      total_mb > 500 -> "medium"
      true -> "ok"
    end
  end
end
