defmodule ChangesetHelpers.Address do
  use Ecto.Schema

  schema "addresses" do
    field(:street, :string)
  end
end
