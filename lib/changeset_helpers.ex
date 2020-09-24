defmodule ChangesetHelpers do
  @moduledoc ~S"""
  Provides a set of helpers to work with Changesets.
  """

  @doc ~S"""
  Returns the nested association in a changeset. This function will first look into the changes and then fails back on
  data wrapped in a changeset.

  Changes may be added to the given changeset through the third argument.

  A tuple is returned containing the original changeset and the changeset of the association.

  ```elixir
  {account_changeset, address_changeset} =
    change_assoc(account_changeset, [:user, :config, :address], %{street: "Foo street"})
  ```
  """
  def change_assoc(struct_or_changeset, keys, changes \\ %{}) do
    keys = List.wrap(keys)

    changed_assoc = do_change_assoc(struct_or_changeset, keys, changes)

    {
      put_assoc(struct_or_changeset |> Ecto.Changeset.change(), keys, changed_assoc),
      changed_assoc
    }
  end

  defp do_change_assoc(%Ecto.Changeset{} = changeset, [key | []], changes) do
    Map.get(changeset.changes, key, Map.fetch!(changeset.data, key) |> load!(changeset.data))
    |> do_change_assoc(changes)
  end

  defp do_change_assoc(%{__meta__: _} = schema, [key | []], changes) do
    Map.fetch!(schema, key)
    |> load!(schema)
    |> do_change_assoc(changes)
  end

  defp do_change_assoc(%Ecto.Changeset{} = changeset, [key | tail_keys], changes) do
    Map.get(changeset.changes, key, Map.fetch!(changeset.data, key) |> load!(changeset.data))
    |> do_change_assoc(tail_keys, changes)
  end

  defp do_change_assoc(%{__meta__: _} = schema, [key | tail_keys], changes) do
    Map.fetch!(schema, key)
    |> load!(schema)
    |> do_change_assoc(tail_keys, changes)
  end

  defp do_change_assoc([], _changes), do: []

  defp do_change_assoc([%{__meta__: _} = schema | tail], changes) do
    [Ecto.Changeset.change(schema, changes) | do_change_assoc(tail, changes)]
  end

  defp do_change_assoc([%Ecto.Changeset{} = changeset | tail], changes) do
    [Ecto.Changeset.change(changeset, changes) | do_change_assoc(tail, changes)]
  end

  defp do_change_assoc(%{__meta__: _} = schema, changes) do
    Ecto.Changeset.change(schema, changes)
  end

  defp do_change_assoc(%Ecto.Changeset{} = changeset, changes) do
    Ecto.Changeset.change(changeset, changes)
  end

  @doc ~S"""
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

  In the code above, we add a new empty Article to the articles association (typically done when we want to add a new
  article to a form).
  """
  def put_assoc(changeset, keys, value) do
    do_put_assoc(changeset, List.wrap(keys), value)
  end

  defp do_put_assoc(changeset, [key | []], fun) when is_function(fun) do
    Ecto.Changeset.put_assoc(changeset, key, fun.(do_change_assoc(changeset, [key], %{})))
  end

  defp do_put_assoc(changeset, [key | []], value) do
    Ecto.Changeset.put_assoc(changeset, key, value)
  end

  defp do_put_assoc(changeset, [key | tail_keys], value) do
    Ecto.Changeset.put_assoc(
      changeset,
      key,
      do_put_assoc(do_change_assoc(changeset, [key], %{}), tail_keys, value)
    )
  end

  @doc ~S"""
  Fetches the given nested field from changes or from the data.

  While `fetch_change/2` only looks at the current changes to retrieve a value, this function looks at the changes and
  then falls back on the data, finally returning `:error` if no value is available.

  For relations, these functions will return the changeset original data with changes applied. To retrieve raw
  changesets, please use `fetch_change/2`.

  ```elixir
  {:changes, street} =
    ChangesetHelpers.fetch_field(account_changeset, [:user, :config, :address, :street])
  ```
  """
  def fetch_field(changeset, [key | []]) do
    Ecto.Changeset.fetch_field(changeset, key)
  end

  def fetch_field(changeset, [key | tail_keys]) do
    Map.get(changeset.changes, key, Map.fetch!(changeset.data, key) |> load!(changeset.data))
    |> Ecto.Changeset.change()
    |> fetch_field(tail_keys)
  end

  @doc ~S"""
  Same as `fetch_field/2` but returns the value or raises if the given nested key was not found.

  ```elixir
  street = ChangesetHelpers.fetch_field!(account_changeset, [:user, :config, :address, :street])
  ```
  """
  def fetch_field!(changeset, keys) do
    case fetch_field(changeset, keys) do
      {_, value} ->
        value

      :error ->
        raise KeyError, key: keys, term: changeset.data
    end
  end

  @doc ~S"""
  Fetches a nested change from the given changeset.

  This function only looks at the `:changes` field of the given `changeset` and returns `{:ok, value}` if the change is
  present or `:error` if it's not.

  ```elixir
  {:ok, street} =
    ChangesetHelpers.fetch_change(account_changeset, [:user, :config, :address, :street])
  ```
  """
  def fetch_change(changeset, [key | []]) do
    Ecto.Changeset.fetch_change(changeset, key)
  end

  def fetch_change(changeset, [key | tail_keys]) do
    case Map.get(changeset.changes, key) do
      nil ->
        nil

      changeset ->
        fetch_change(changeset, tail_keys)
    end
  end

  @doc ~S"""
  Same as `fetch_change/2` but returns the value or raises if the given nested key was not found.

  ```elixir
  street = ChangesetHelpers.fetch_change!(account_changeset, [:user, :config, :address, :street])
  ```
  """
  def fetch_change!(changeset, keys) do
    case fetch_change(changeset, keys) do
      {:ok, value} ->
        value

      :error ->
        raise KeyError, key: keys, term: changeset.changes
    end
  end

  @doc ~S"""
  This function allows checking if a given field is different between two changesets.

  ```elixir
  {street_changed, street1, street2} =
    diff_field(account_changeset, new_account_changeset, [:user, :config, :address, :street])
  ```
  """
  def diff_field(changeset1, changeset2, keys) do
    do_diff_field(changeset1, changeset2, List.wrap(keys))
  end

  defp do_diff_field(changeset1, changeset2, [key | []]) do
    field1 = Ecto.Changeset.fetch_field!(changeset1, key)
    field2 = Ecto.Changeset.fetch_field!(changeset2, key)

    {field1 != field2, field1, field2}
  end

  defp do_diff_field(changeset1, changeset2, [key | tail_keys]) do
    changeset1 =
      Map.get(changeset1.changes, key, Map.fetch!(changeset1.data, key) |> load!(changeset1.data))
      |> Ecto.Changeset.change()

    changeset2 =
      Map.get(changeset2.changes, key, Map.fetch!(changeset2.data, key) |> load!(changeset2.data))
      |> Ecto.Changeset.change()

    do_diff_field(changeset1, changeset2, tail_keys)
  end

  defp load!(%Ecto.Association.NotLoaded{} = not_loaded, %{__meta__: %{state: :built}}) do
    case cardinality_to_empty(not_loaded.__cardinality__) do
      nil ->
        Ecto.build_assoc(struct(not_loaded.__owner__), not_loaded.__field__)

      [] ->
        []
    end
  end

  defp load!(%Ecto.Association.NotLoaded{__field__: field}, struct) do
    raise "attempting to change association `#{field}` " <>
          "from `#{inspect struct.__struct__}` that was not loaded. Please preload your " <>
          "associations before manipulating them through changesets"
  end

  defp load!(loaded, _struct) do
    loaded
  end

  defp cardinality_to_empty(:one), do: nil
  defp cardinality_to_empty(:many), do: []
end
