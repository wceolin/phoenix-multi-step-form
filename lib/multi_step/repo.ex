defmodule MultiStep.Repo do
  use Ecto.Repo,
    otp_app: :multi_step,
    adapter: Ecto.Adapters.Postgres
end
