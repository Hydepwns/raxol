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

    children =
      if Mix.env() == :test do
        # Use mock version for tests
        [
          # Use a mock version of the Terminal.Driver if in test env
          {Raxol.Test.MockApplicationSupervisor, []}
        ]
      else
        # Use real version for dev/prod
        [
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
          # Start the UserPreferences GenServer
          Raxol.Core.UserPreferences,
          # Start the Terminal Sync System
          {Raxol.Terminal.Sync.System, []},
          # Start the Terminal Supervisor
          {Raxol.Terminal.Supervisor, []}
        ] ++
          if IO.ANSI.enabled?() do
            [
              # Start the Terminal Driver only if in a TTY
              {Raxol.Terminal.Driver, nil}
            ]
          else
            Raxol.Core.Runtime.Log.warning_with_context(
              "[Raxol.Application] Not attached to a TTY. Terminal driver will not be started.",
              %{}
            )

            []
          end
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Raxol.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# Create a mock application supervisor for testing
defmodule Raxol.Test.MockApplicationSupervisor do
  @moduledoc """
  Mock application supervisor for testing purposes.

  Provides a simplified supervision tree for test environments
  without starting all production services.
  """

  use Supervisor
  require Raxol.Core.Runtime.Log

  def start_link(_args) do
    Raxol.Core.Runtime.Log.info_with_context(
      "Starting MockApplicationSupervisor for testing",
      %{}
    )

    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl Supervisor
  def init(_args) do
    Raxol.Core.Runtime.Log.info_with_context(
      "Initializing MockApplicationSupervisor with Phoenix PubSub and Repo",
      %{}
    )

    # Add Phoenix.PubSub child spec for tests, using the conventional name
    pubsub_child_spec = {Phoenix.PubSub, name: Raxol.PubSub}

    # Add Raxol.Repo child spec for tests only if database is enabled
    # repo_child_spec =
    #   if Application.get_env(:raxol, :database_enabled, false) do
    #     Raxol.Repo
    #   else
    #     nil
    #   end

    # Add UserPreferences for tests, ensuring it starts in test mode
    user_preferences_child_spec =
      {Raxol.Core.UserPreferences, [test_mode?: true]}

    # Add Accounts for tests
    accounts_child_spec = Raxol.Accounts

    # Add Terminal Sync System for tests
    sync_system_child_spec = {Raxol.Terminal.Sync.System, []}

    # Add Terminal Supervisor for tests
    terminal_supervisor_child_spec = {Raxol.Terminal.Supervisor, []}

    # Add Web Supervisor for tests (includes Presence and Session Manager)
    web_supervisor_child_spec = Raxol.Web.Supervisor

    # Add Rate Limit Manager for tests
    rate_limit_manager_child_spec = RaxolWeb.RateLimitManager

    children = [
      pubsub_child_spec,
      user_preferences_child_spec,
      accounts_child_spec,
      sync_system_child_spec,
      terminal_supervisor_child_spec,
      web_supervisor_child_spec,
      rate_limit_manager_child_spec
    ]

    # # Add repo_child_spec only if it's not nil
    # children =
    #   if repo_child_spec do
    #     [repo_child_spec | children]
    #   else
    #     children
    #   end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
