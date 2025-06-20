defmodule Raxol.Application do
  use Application
  @behaviour Application
  require Raxol.Core.Runtime.Log

  @impl true
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
          # Start the Dynamic Supervisor for Raxol applications
          Raxol.DynamicSupervisor,
          # Start the UserPreferences GenServer
          Raxol.Core.UserPreferences
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
  use Supervisor
  @behaviour Supervisor
  require Raxol.Core.Runtime.Log

  def start_link(_args) do
    Raxol.Core.Runtime.Log.info_with_context(
      "Starting MockApplicationSupervisor for testing",
      %{}
    )

    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Raxol.Core.Runtime.Log.info_with_context(
      "Initializing MockApplicationSupervisor with Phoenix PubSub and Repo",
      %{}
    )

    # Add Phoenix.PubSub child spec for tests, using the conventional name
    pubsub_child_spec = {Phoenix.PubSub, name: Raxol.PubSub}
    # Add Raxol.Repo child spec for tests
    repo_child_spec = Raxol.Repo
    # Add UserPreferences for tests, ensuring it starts in test mode
    user_preferences_child_spec =
      {Raxol.Core.UserPreferences, [test_mode?: true]}

    # Add Accounts for tests
    accounts_child_spec = Raxol.Accounts

    children = [
      pubsub_child_spec,
      repo_child_spec,
      user_preferences_child_spec,
      accounts_child_spec
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
