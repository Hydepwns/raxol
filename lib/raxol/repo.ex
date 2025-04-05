defmodule Raxol.Repo do
  use Ecto.Repo,
    otp_app: :raxol,
    adapter: Ecto.Adapters.Postgres
end 