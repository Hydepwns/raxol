defmodule Raxol.Telegram.Supervisor do
  @moduledoc """
  Top-level supervisor for the Telegram bridge.

  Starts the SessionRouter and optionally the Bot (polling handler).
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    app_module = Keyword.fetch!(opts, :app_module)

    children = [
      {Raxol.Telegram.SessionRouter, app_module: app_module}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
