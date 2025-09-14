defmodule Raxol.Application do
  @moduledoc """
  Main application module for Raxol terminal emulator.

  Handles application startup, supervision tree initialization,
  and core system configuration.
  """

  use Application
  require Raxol.Core.Runtime.Log

  @impl Application
  def start(_type, _args) do
    Raxol.Core.Runtime.Log.info_with_context(
      "No preferences file found, using defaults.",
      %{}
    )

    children = get_children_for_env(Mix.env())

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Raxol.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp get_children_for_env(:test) do
    # Minimal children for test environment
    # Tests can start their own processes as needed
    []
  end

  defp get_children_for_env(_env) do
    # Use real version for dev/prod
    core_children = [
      # Start the Ecto Repo
      Raxol.Repo,
      # Start Phoenix PubSub
      {Phoenix.PubSub, name: Raxol.PubSub},
      # Start the RaxolWeb Endpoint
      RaxolWeb.Endpoint,
      # Start RaxolWeb Telemetry
      RaxolWeb.Telemetry,
      # Start Rate Limit Manager
      RaxolWeb.RateLimitManager,
      # Start the Dynamic Supervisor for Raxol applications
      Raxol.DynamicSupervisor,
      # Start the ErrorRecovery GenServer
      Raxol.Core.ErrorRecovery,
      # Start the UserPreferences GenServer
      Raxol.Core.UserPreferences,
      # Start the Performance Profiler
      Raxol.Core.Performance.Profiler,
      # Start the Performance Monitor
      Raxol.Core.Performance.Monitor,
      # Start the Terminal Sync System
      {Raxol.Terminal.Sync.System, []},
      # Start the Terminal Supervisor
      {Raxol.Terminal.Supervisor, []}
    ]

    core_children ++ get_terminal_driver_children()
  end

  defp get_terminal_driver_children do
    case IO.ANSI.enabled?() do
      true ->
        [
          # Start the Terminal Driver only if in a TTY
          {Raxol.Terminal.Driver, nil}
        ]

      false ->
        Raxol.Core.Runtime.Log.warning_with_context(
          "[Raxol.Application] Not attached to a TTY. Terminal driver will not be started.",
          %{}
        )

        []
    end
  end
end
