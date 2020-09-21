defmodule ChangesetHelpers.Comment do
  use Ecto.Schema

  schema "comments" do
    field(:body, :string)
    belongs_to(:article, ChangesetHelpers.Article)
  end
end
