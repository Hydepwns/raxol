defmodule Raxol.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("No preferences file found, using defaults.")

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
          # Start the Dynamic Supervisor for Raxol applications
          Raxol.DynamicSupervisor,
          # Start the UserPreferences GenServer
          Raxol.Core.UserPreferences,
          # Start the Terminal Driver
          # Dispatcher PID is not available at startup; passing nil for now.
          {Raxol.Terminal.Driver, nil}
          # Add other core persistent processes here if needed (e.g., PluginManager, TerminalDriver? Check ARCHITECTURE)
        ]
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
  require Logger

  def start_link(_args) do
    Logger.info("Starting MockApplicationSupervisor for testing")
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_args) do
    Logger.info(
      "Initializing MockApplicationSupervisor with Phoenix PubSub and Repo"
    )

    # Add Phoenix.PubSub child spec for tests, using the conventional name
    pubsub_child_spec = {Phoenix.PubSub, name: Raxol.PubSub}
    # Add Raxol.Repo child spec for tests
    repo_child_spec = Raxol.Repo
    children = [pubsub_child_spec, repo_child_spec]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
