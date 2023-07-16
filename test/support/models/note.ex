defmodule ChangesetHelpers.Note do
  use Ecto.Schema

  schema "notes" do
    field(:text, :string)
    belongs_to(:user, ChangesetHelpers.User)
  end
end
