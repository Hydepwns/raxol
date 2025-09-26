defmodule Raxol.Web.Supervisor do
  @moduledoc """
  Web supervisor for Raxol web interface components.

  This supervisor manages web-related processes including the WebManager.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Raxol.Web.WebManager, []}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
