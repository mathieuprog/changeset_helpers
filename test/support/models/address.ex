defmodule ChangesetHelpers.Address do
  use Ecto.Schema

  schema "addresses" do
    field(:street, :string)
    field(:city, :string)
  end
end
