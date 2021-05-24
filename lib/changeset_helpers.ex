defmodule ChangesetHelpers do
  @moduledoc ~S"""
  Provides a set of helpers to work with Changesets.
  """

  @doc ~S"""
  Raises if one of the given field has an invalid value.
  """
  def raise_if_invalid_fields(changeset, keys_validations) do
    unless Keyword.keyword?(keys_validations) do
      raise ArgumentError, message: "`raise_if_invalid_fields/2` expects a keyword list as its second argument"
    end

    ensure_fields_exist!(changeset, keys_validations)
    ensure_validations_exist!(changeset, keys_validations)

    do_raise_if_invalid_fields(changeset, keys_validations)
  end

  def do_raise_if_invalid_fields(%Ecto.Changeset{valid?: false, errors: errors} = changeset, keys_validations) do
    Enum.find_value(errors, fn {key, {_message, meta}} ->
      if validations = keys_validations[key] do
        if validation = Enum.find(List.wrap(validations), &(&1 == meta[:validation])) do
          {key, validation, meta[:raise]}
        end
      end
    end)
    |> case do
      {key, validation, nil} ->
        value = Ecto.Changeset.fetch_field!(changeset, key)

        raise "Field `#{inspect key}` was provided an invalid value `#{inspect value}`. " <>
              "The changeset validator is `#{inspect validation}`."

      {_, _, error_message} ->
        raise error_message

      _ ->
        changeset
    end
  end

  def do_raise_if_invalid_fields(changeset, _), do: changeset

  defp ensure_fields_exist!(%Ecto.Changeset{} = changeset, keys_validations) do
    Keyword.keys(keys_validations)
    |> Enum.each(&ensure_field_exists!(changeset, &1))
  end

  defp ensure_field_exists!(%Ecto.Changeset{types: types}, key) do
    unless Map.has_key?(types, key) do
      raise ArgumentError, "unknown field `#{inspect key}`"
    end
  end

  defp ensure_validations_exist!(%Ecto.Changeset{} = changeset, keys_validations) do
    required =
      changeset.required |>
      Enum.map(fn field -> {field, :required} end)

    validations =
      Ecto.Changeset.validations(changeset)
      |> Enum.map(fn {field, validation_tuple} -> {field, elem(validation_tuple, 0)} end)

    validations = required ++ validations

    keys_validations =
      keys_validations
      |> Enum.map(fn {key, validations} ->
        Enum.map(List.wrap(validations), &({key, &1}))
      end)
      |> List.flatten()

    unknown_validations = keys_validations -- validations

    if unknown_validations != [] do
      [{field, validation} | _] = unknown_validations
      raise ArgumentError, "unknown validation `#{inspect validation}` for field `#{inspect field}`"
    end
  end

  def change_assoc(struct_or_changeset, keys) do
    change_assoc(struct_or_changeset, keys, %{})
  end

  @doc ~S"""
  Returns the nested association in a changeset. This function will first look into the changes and then fails back on
  data wrapped in a changeset.

  Changes may be added to the given changeset through the third argument.

  A tuple is returned containing the root changeset, and the changeset of the association.

  ```elixir
  {account_changeset, address_changeset} =
    change_assoc(account_changeset, [:user, :config, :address], %{street: "Foo street"})
  ```
  """
  def change_assoc(struct_or_changeset, keys, changes) when is_map(changes) do
    keys = List.wrap(keys)

    changed_assoc = do_change_assoc(struct_or_changeset, keys, changes)

    {
      put_assoc(struct_or_changeset |> Ecto.Changeset.change(), keys, changed_assoc),
      changed_assoc
    }
  end

  def change_assoc(struct_or_changeset, keys, index) when is_integer(index) do
    change_assoc(struct_or_changeset, keys, index, %{})
  end

  @doc ~S"""
  Returns the nested association in a changeset at the given index.

  A tuple is returned containing the root changeset, the changesets of the association and the changeset at the
  specified index.

  See `change_assoc(struct_or_changeset, keys, changes)`.
  ```
  """
  def change_assoc(struct_or_changeset, keys, index, changes) when is_integer(index) and is_map(changes) do
    keys = List.wrap(keys)

    changed_assoc = do_change_assoc(struct_or_changeset, keys, index, changes)

    {
      put_assoc(struct_or_changeset |> Ecto.Changeset.change(), keys, changed_assoc),
      changed_assoc,
      Enum.at(changed_assoc, index)
    }
  end

  defp do_change_assoc(changeset, keys, index \\ nil, changes)

  defp do_change_assoc(%Ecto.Changeset{} = changeset, [key | []], nil, changes) do
    Map.get(changeset.changes, key, Map.fetch!(changeset.data, key) |> load!(changeset.data))
    |> do_change_assoc(changes)
  end

  defp do_change_assoc(%Ecto.Changeset{} = changeset, [key | []], index, changes) do
    Map.get(changeset.changes, key, Map.fetch!(changeset.data, key) |> load!(changeset.data))
    |> List.update_at(index, &(do_change_assoc(&1, changes)))
  end

  defp do_change_assoc(%{__meta__: _} = schema, [key | []], nil, changes) do
    Map.fetch!(schema, key)
    |> load!(schema)
    |> do_change_assoc(changes)
  end

  defp do_change_assoc(%{__meta__: _} = schema, [key | []], index, changes) do
    Map.fetch!(schema, key)
    |> load!(schema)
    |> List.update_at(index, &(do_change_assoc(&1, changes)))
  end

  defp do_change_assoc(%Ecto.Changeset{} = changeset, [key | tail_keys], index, changes) do
    Map.get(changeset.changes, key, Map.fetch!(changeset.data, key) |> load!(changeset.data))
    |> do_change_assoc(tail_keys, index, changes)
  end

  defp do_change_assoc(%{__meta__: _} = schema, [key | tail_keys], index, changes) do
    Map.fetch!(schema, key)
    |> load!(schema)
    |> do_change_assoc(tail_keys, index, changes)
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

  Instead of giving a Changeset or a schema as the third argument, a function may also be given receiving the nested
  Changeset(s) to be updated as argument.

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

  @doc ~S"""
  Puts the given nested association in the changeset at the given index.

  See `put_assoc(changeset, keys, value)`.
  """
  def put_assoc(changeset, keys, index, value) do
    do_put_assoc(changeset, List.wrap(keys), index, value)
  end

  defp do_put_assoc(changeset, keys, index \\ nil, value_or_fun)

  defp do_put_assoc(changeset, [key | []], nil, fun) when is_function(fun) do
    Ecto.Changeset.put_assoc(changeset, key, fun.(do_change_assoc(changeset, [key], %{})))
  end

  defp do_put_assoc(changeset, [key | []], nil, value) do
    Ecto.Changeset.put_assoc(changeset, key, value)
  end

  defp do_put_assoc(changeset, [key | []], index, fun) when is_function(fun) do
    nested_changesets = do_change_assoc(changeset, [key], %{})
    nested_changesets = List.update_at(nested_changesets, index, &(fun.(&1)))

    Ecto.Changeset.put_assoc(changeset, key, nested_changesets)
  end

  defp do_put_assoc(changeset, [key | []], index, value) do
    nested_changesets =
      do_change_assoc(changeset, [key], %{})
      |> List.replace_at(index, value)

    Ecto.Changeset.put_assoc(changeset, key, nested_changesets)
  end

  defp do_put_assoc(changeset, [key | tail_keys], index, value_or_fun) do
    Ecto.Changeset.put_assoc(
      changeset,
      key,
      do_put_assoc(do_change_assoc(changeset, [key], %{}), tail_keys, index, value_or_fun)
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
  def fetch_field(%Ecto.Changeset{} = changeset, [key | []]) do
    Ecto.Changeset.fetch_field(changeset, key)
  end

  def fetch_field(%Ecto.Changeset{} = changeset, [key | tail_keys]) do
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
  def fetch_field!(%Ecto.Changeset{} = changeset, keys) do
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
  def fetch_change(%Ecto.Changeset{} = changeset, [key | []]) do
    Ecto.Changeset.fetch_change(changeset, key)
  end

  def fetch_change(%Ecto.Changeset{} = changeset, [key | tail_keys]) do
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
  def fetch_change!(%Ecto.Changeset{} = changeset, keys) do
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
  def diff_field(%Ecto.Changeset{} = changeset1, %Ecto.Changeset{} = changeset2, keys) do
    field1 = fetch_field!(changeset1, keys)
    field2 = fetch_field!(changeset2, keys)

    {field1 != field2, field1, field2}
  end

  @doc ~S"""
  Adds an error to the nested changeset.

  ```elixir
  account_changeset =
    ChangesetHelpers.add_error(account_changeset, [:user, :articles, :error_key], "Some error")
  ```
  """
  def add_error(%Ecto.Changeset{} = changeset, keys, message, extra \\ []) do
    reversed_keys = keys |> Enum.reverse()
    last_key = hd(reversed_keys)
    keys_without_last = reversed_keys |> tl() |> Enum.reverse()

    {_, nested_changes} = change_assoc(changeset, keys_without_last)

    nested_changes = do_add_error(nested_changes, last_key, message, extra)

    ChangesetHelpers.put_assoc(changeset, keys_without_last, nested_changes)
  end

  defp do_add_error(nested_changes, key, message, extra) when is_list(nested_changes) do
    Enum.map(nested_changes, &(Ecto.Changeset.add_error(&1, key, message, extra)))
  end

  defp do_add_error(nested_changes, key, message, extra) do
    Ecto.Changeset.add_error(nested_changes, key, message, extra)
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
