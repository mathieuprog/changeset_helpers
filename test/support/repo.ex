defmodule ChangesetHelpers.Repo do
  use Ecto.Repo,
    otp_app: :changeset_helpers,
    adapter: Ecto.Adapters.Postgres
end
