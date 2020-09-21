defmodule ChangesetHelpers.Article do
  use Ecto.Schema

  schema "articles" do
    field(:title, :string)
    belongs_to(:user, ChangesetHelpers.User)
    has_many(:comments, ChangesetHelpers.Comment)
  end
end
