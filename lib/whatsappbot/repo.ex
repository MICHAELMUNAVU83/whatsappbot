defmodule Whatsappbot.Repo do
  use Ecto.Repo,
    otp_app: :whatsappbot,
    adapter: Ecto.Adapters.Postgres
end
