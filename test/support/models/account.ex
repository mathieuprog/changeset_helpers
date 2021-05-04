defmodule ChangesetHelpers.Account do
  use Ecto.Schema

  schema "accounts" do
    field(:email, :string)
    field(:mobile, :string)
    belongs_to(:user, ChangesetHelpers.User)
  end
end
