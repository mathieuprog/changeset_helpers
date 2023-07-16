defmodule ChangesetHelpers.User do
  use Ecto.Schema

  schema "users" do
    field(:name, :string)
    has_many(:articles, ChangesetHelpers.Article)
    has_many(:notes, ChangesetHelpers.Note)
    belongs_to(:user_config, ChangesetHelpers.UserConfig)
  end
end
