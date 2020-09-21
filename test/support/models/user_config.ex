defmodule ChangesetHelpers.UserConfig do
  use Ecto.Schema

  schema "users_configs" do
    belongs_to(:address, ChangesetHelpers.Address)
  end
end
