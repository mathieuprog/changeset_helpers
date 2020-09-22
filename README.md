# ChangesetHelpers

This library provides a set of helper functions to work with Ecto Changesets.

### `put_assoc(changeset, keys, value)`

Puts the given nested association in the changeset through a given list of field names.

```
ChangesetHelpers.put_assoc(account_changeset, [:user, :config, :address], address_changeset)
```

Instead of giving a Changeset or a schema as the third argument, a function may also be given in order to modify the
nested changeset in one go.

```
ChangesetHelpers.put_assoc(account_changeset, [:user, :articles],
  &(Enum.concat(&1, [%Article{} |> Ecto.Changeset.change()])))
```

In the code above, we change a new empty Article, and add the changeset into the articles association (typically done when we want to add a new
article to a form).

### `change_assoc(struct_or_changeset, keys, changes \\ %{})`

Returns the nested association in a changeset. This function will first look into the changes and then fails back on
data wrapped in a changeset.

Changes may be added to the given changeset through the third argument.

A tuple is returned containing the modified root changeset and the changeset of the association.

```
{account_changeset, address_changeset} =
  change_assoc(account_changeset, [:user, :user_config, :address], %{street: "Foo street"})
```

### `diff_field(changeset1, changeset2, keys)`

This function allows checking if a given field is different in two changesets.

```
{street_changed, street1, street2} =
  diff_field(account_changeset, new_account_changeset, [:user, :user_config, :address, :street])
```

## Installation

Add `changeset_helpers` for Elixir as a dependency in your `mix.exs` file:

```elixir
def deps do
  [
    {:changeset_helpers, "~> 0.4.0"}
  ]
end
```

## HexDocs

HexDocs documentation can be found at [https://hexdocs.pm/changeset_helpers](https://hexdocs.pm/changeset_helpers).
