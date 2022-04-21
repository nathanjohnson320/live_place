defmodule LivePlace.Repo do
  use Ecto.Repo,
    otp_app: :live_place,
    adapter: Ecto.Adapters.SQLite3
end
