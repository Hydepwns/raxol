defmodule RaxolPlaygroundWeb.CapabilitiesController do
  @moduledoc """
  Machine-readable endpoints for agent discovery.
  /.well-known/raxol.json -- capability manifest
  /api/capabilities -- detailed capabilities
  /llms.txt -- LLM-friendly project summary
  """
  use RaxolPlaygroundWeb, :controller

  @llms_txt_path Path.join(:code.priv_dir(:raxol_playground), "static/llms.txt")

  def manifest(conn, _params) do
    json(conn, %{
      name: "raxol",
      description: "Multi-surface runtime for Elixir on OTP",
      version: raxol_version(),
      surfaces: ["terminal", "liveview", "ssh", "mcp", "telegram", "watch"],
      links: %{
        homepage: "https://raxol.io",
        skill: "https://raxol.io/skill.md",
        llms_txt: "https://raxol.io/llms.txt",
        capabilities: "https://raxol.io/api/capabilities",
        playground: "https://raxol.io/playground",
        ssh: "ssh -p 2222 playground@raxol.io",
        docs: "https://hexdocs.pm/raxol",
        github: "https://github.com/DROOdotFOO/raxol",
        hex: "https://hex.pm/packages/raxol"
      },
      packages: package_list(),
      mcp: %{
        command: "mix",
        args: ["mcp.server"],
        tools: [
          "raxol_start",
          "raxol_screenshot",
          "raxol_send_key",
          "raxol_get_model",
          "raxol_stop",
          "raxol_list"
        ]
      }
    })
  end

  def capabilities(conn, _params) do
    components = Raxol.Playground.Catalog.list_components()
    categories = Raxol.Playground.Catalog.list_categories()

    json(conn, %{
      surfaces: surfaces(),
      agent: agent_capabilities(),
      packages: package_list(),
      widgets: %{
        count: length(components),
        categories: Enum.map(categories, &to_string/1),
        names: Enum.map(components, & &1.name)
      }
    })
  end

  def llms_txt(conn, _params) do
    content =
      case File.read(@llms_txt_path) do
        {:ok, data} -> data
        {:error, _} -> "# Raxol\n\nllms.txt not found."
      end

    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, content)
  end

  defp raxol_version do
    case :application.get_key(:raxol, :vsn) do
      {:ok, vsn} -> to_string(vsn)
      _ -> "2.4.0"
    end
  end

  defp surfaces do
    [
      %{name: "terminal", transport: "termbox2 NIF", dep: "raxol_terminal"},
      %{name: "liveview", transport: "Phoenix PubSub", dep: "raxol_liveview"},
      %{name: "ssh", transport: "Erlang :ssh", dep: "raxol (built-in)"},
      %{name: "mcp", transport: "stdio JSON-RPC", dep: "raxol_mcp"},
      %{name: "telegram", transport: "Telegex HTTP", dep: "raxol_telegram"},
      %{name: "watch", transport: "APNS/FCM push", dep: "raxol_watch"}
    ]
  end

  defp agent_capabilities do
    %{
      models: ["TEA (message-driven)", "Process (tick-driven)"],
      commands: ["shell", "async", "send_agent"],
      strategies: ["Strategy.Direct", "Strategy.ReAct"],
      payments: ["x402", "MPP", "Xochi"],
      backends: ["Anthropic", "OpenAI", "Ollama", "Groq", "Kimi", "Lumo", "Mock"]
    }
  end

  defp package_list do
    [
      %{name: "raxol", dep: "{:raxol, \"~> 2.4\"}", purpose: "Full framework"},
      %{name: "raxol_agent", dep: "{:raxol_agent, \"~> 2.4\"}", purpose: "AI agents"},
      %{name: "raxol_mcp", dep: "{:raxol_mcp, \"~> 2.4\"}", purpose: "MCP server"},
      %{name: "raxol_payments", dep: "{:raxol_payments, \"~> 0.1\"}", purpose: "Agent commerce"},
      %{name: "raxol_liveview", dep: "{:raxol_liveview, \"~> 2.4\"}", purpose: "LiveView bridge"},
      %{name: "raxol_sensor", dep: "{:raxol_sensor, \"~> 2.4\"}", purpose: "Sensor fusion"},
      %{name: "raxol_terminal", dep: "{:raxol_terminal, \"~> 2.4\"}", purpose: "Terminal emulation"},
      %{name: "raxol_core", dep: "{:raxol_core, \"~> 2.4\"}", purpose: "Behaviours, events"},
      %{name: "raxol_plugin", dep: "{:raxol_plugin, \"~> 2.4\"}", purpose: "Plugin SDK"},
      %{name: "raxol_speech", dep: "{:raxol_speech, \"~> 0.1\"}", purpose: "TTS/STT"},
      %{name: "raxol_telegram", dep: "{:raxol_telegram, \"~> 0.1\"}", purpose: "Telegram bot"},
      %{name: "raxol_watch", dep: "{:raxol_watch, \"~> 0.1\"}", purpose: "Push notifications"}
    ]
  end
end
