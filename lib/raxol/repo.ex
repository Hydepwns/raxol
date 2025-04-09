defmodule Raxol.Repo do
  use Ecto.Repo,
    otp_app: :raxol,
    adapter: Ecto.Adapters.Postgres,
    pool: DBConnection.Poolboy

  # def config do
  #   Application.get_env(:raxol, __MODULE__, [])
  # end
end
