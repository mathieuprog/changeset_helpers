# ChangesetHelpers

This library provides a set of helper functions to work with Ecto Changesets.

### `raise_if_invalid_fields(changeset, keys)`

Raises if one of the given field has an invalid value.

```elixir
changeset
|> validate_required([:cardinal_direction])
|> validate_inclusion(:cardinal_direction, ["north", "east", "south", "west"])
|> raise_if_invalid_fields(cardinal_direction: :inclusion)
```

The second argument is a keyword list where the key is the schema field and the value is a validation name or list of validation names. In the example above, if you want to raise if any of the `:inclusion` and `:required` validations fail, you may pass `cardinal_direction: [:inclusion, :required]`.

### `put_assoc(changeset, keys, value)`

Puts the given nested association in the changeset through a given list of field names.

```elixir
ChangesetHelpers.put_assoc(account_changeset, [:user, :config, :address], address_changeset)
```

Instead of giving a Changeset or a schema as the third argument, a function may also be given in order to modify the
nested changeset in one go.

```elixir
ChangesetHelpers.put_assoc(account_changeset, [:user, :articles],
  &(Enum.concat(&1, [%Article{} |> Ecto.Changeset.change()])))
```

In the code above, we change a new empty Article, and add the changeset into the articles association (typically done when we want to add a new
row of form inputs to add an entity into a form handling a nested collection of entities).

### `put_assoc(changeset, keys, index, value)`

Puts the given nested association in the changeset through a given list of field names, at the given index.

### `change_assoc(struct_or_changeset, keys, changes \\ %{})`

Returns the nested association in a changeset. This function will first look into the changes and then fails back on
data wrapped in a changeset.

Changes may be added to the given changeset through the third argument.

A tuple is returned containing the modified root changeset and the changeset of the association.

```elixir
{account_changeset, address_changeset} =
  change_assoc(account_changeset, [:user, :user_config, :address], %{street: "Foo street"})
```

### `change_assoc(struct_or_changeset, keys, index, changes \\ %{})`

Returns the nested association in a changeset at the given index.

### `fetch_field(changeset, keys)`

Fetches the given nested field from changes or from the data.

```elixir
{:changes, street} =
  ChangesetHelpers.fetch_field(account_changeset, [:user, :config, :address, :street])
```

### `fetch_field!(changeset, keys)`

Same as `fetch_field/2` but returns the value or raises if the given nested key was not found.

```elixir
street = ChangesetHelpers.fetch_field!(account_changeset, [:user, :config, :address, :street])
```

### `fetch_change(changeset, keys)`

Fetches the given nested field from changes or from the data.

```elixir
{:ok, street} =
  ChangesetHelpers.fetch_change(account_changeset, [:user, :config, :address, :street])
```

### `fetch_change!(changeset, keys)`

Same as `fetch_change/2` but returns the value or raises if the given nested key was not found.

```elixir
street = ChangesetHelpers.fetch_change!(account_changeset, [:user, :config, :address, :street])
```

### `diff_field(changeset1, changeset2, keys)`

This function allows checking if a given field is different in two changesets.

```elixir
{street_changed, street1, street2} =
  diff_field(account_changeset, new_account_changeset, [:user, :user_config, :address, :street])
```

### `add_error(changeset, keys, message, extra \\ [])`

Adds an error to the nested changeset.

```elixir
ChangesetHelpers.add_error(account_changeset, [:user, :articles, :error_key], "Some error")
```

## Installation

Add `changeset_helpers` for Elixir as a dependency in your `mix.exs` file:

```elixir
def deps do
  [
    {:changeset_helpers, "~> 0.10.0"}
  ]
end
```

## HexDocs

HexDocs documentation can be found at [https://hexdocs.pm/changeset_helpers](https://hexdocs.pm/changeset_helpers).
