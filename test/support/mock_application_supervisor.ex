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

    # Add ErrorRecovery for tests
    error_recovery_child_spec = Raxol.Core.ErrorRecovery

    # Add UserPreferences for tests, ensuring it starts in test mode
    user_preferences_child_spec =
      {Raxol.Core.UserPreferences, [test_mode?: true]}

    # Add Accounts for tests
    accounts_child_spec = Raxol.Accounts

    # Add sync system for tests
    sync_system_child_spec = Raxol.Terminal.Sync.System

    # Add TerminalSupervisor for tests
    terminal_supervisor_child_spec = Raxol.Terminal.Supervisor

    # Add WebSupervisor for tests (mock version)
    web_supervisor_child_spec = Raxol.Web.Supervisor

    # Add RateLimitManager for tests
    rate_limit_manager_child_spec = Raxol.Terminal.RateLimitManager

    children = [
      error_recovery_child_spec,
      pubsub_child_spec,
      user_preferences_child_spec,
      accounts_child_spec,
      sync_system_child_spec,
      terminal_supervisor_child_spec,
      web_supervisor_child_spec,
      rate_limit_manager_child_spec
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
