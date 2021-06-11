defmodule ChangesetHelpers do
  @moduledoc ~S"""
  Provides a set of helpers to work with Changesets.
  """

  @doc ~S"""
  Validates the result of the comparison of
    * two fields (where at least one is a change) or
    * a change and a value, where the value is an integer, a `Date`, a `Time`,
      a `DateTime` or a `NaiveDateTime`.

  ## Options

    * `:error_on_field` - specifies on which field to add the error, defaults to the first field
    * `:message` - a customized message on failure
  """
  def validate_comparison(changeset, field1, operator, field_or_value, opts \\ [])

  def validate_comparison(%Ecto.Changeset{} = changeset, field1, operator, field2, opts) when is_atom(field2) do
    error_on_field = Keyword.get(opts, :error_on_field, field1)

    operator = operator_abbr(operator)

    validate_changes changeset, [field1, field2], :comparison, fn [{_, value1}, {_, value2}] ->
      if value1 == nil && value2 == nil do
        []
      else
        valid? =
          case compare(value1, value2) do
            :eq ->
              operator in [:eq, :ge, :le]

            :lt ->
              operator in [:ne, :lt, :le]

            :gt ->
              operator in [:ne, :gt, :ge]
          end

        message =
          if error_on_field == field1 do
            Keyword.get(opts, :message, comparison_error_message(operator, value2))
          else
            reverse_operator =
              case operator do
                :lt -> :gt
                :gt -> :lt
                :le -> :ge
                :ge -> :le
                _ -> operator
              end
            Keyword.get(opts, :message, comparison_error_message(reverse_operator, value1))
          end

        if valid?,
          do: [],
          else: [{error_on_field, {message, [validation: :comparison]}}]
      end
    end
  end

  def validate_comparison(%Ecto.Changeset{} = changeset, field, operator, value, opts) do
    operator = operator_abbr(operator)

    Ecto.Changeset.validate_change changeset, field, :comparison, fn _, field_value ->
      valid? =
        case compare(field_value, value) do
          :eq ->
            operator in [:eq, :ge, :le]

          :lt ->
            operator in [:ne, :lt, :le]

          :gt ->
            operator in [:ne, :gt, :ge]
        end

      message = Keyword.get(opts, :message, comparison_error_message(operator, value))

      if valid?,
        do: [],
        else: [{field, {message, [validation: :comparison]}}]
    end
  end

  defp operator_abbr(:eq), do: :eq
  defp operator_abbr(:ne), do: :ne
  defp operator_abbr(:gt), do: :gt
  defp operator_abbr(:ge), do: :ge
  defp operator_abbr(:lt), do: :lt
  defp operator_abbr(:le), do: :le

  defp operator_abbr(:equal_to), do: :eq
  defp operator_abbr(:not_equal_to), do: :ne
  defp operator_abbr(:greater_than), do: :gt
  defp operator_abbr(:greater_than_or_equal_to), do: :ge
  defp operator_abbr(:less_than), do: :lt
  defp operator_abbr(:less_than_or_equal_to), do: :le

  defp comparison_error_message(:eq, value), do: "must be equal to #{to_string value}"
  defp comparison_error_message(:ne, value), do: "must be not equal to #{to_string value}"
  defp comparison_error_message(:gt, value), do: "must be greater than #{to_string value}"
  defp comparison_error_message(:ge, value), do: "must be greater than or equal to #{to_string value}"
  defp comparison_error_message(:lt, value), do: "must be less than #{to_string value}"
  defp comparison_error_message(:le, value), do: "must be less than or equal to #{to_string value}"

  defp compare(%Time{} = time1, %Time{} = time2), do: Time.compare(time1, time2)
  defp compare(%Date{} = date1, %Date{} = date2), do: Date.compare(date1, date2)
  defp compare(%DateTime{} = dt1, %DateTime{} = dt2), do: DateTime.compare(dt1, dt2)
  defp compare(%NaiveDateTime{} = dt1, %NaiveDateTime{} = dt2), do: NaiveDateTime.compare(dt1, dt2)

  defp compare(number1, number2) when is_number(number1) and is_number(number2) do
    cond do
      number1 == number2 -> :eq
      number1 < number2 -> :lt
      true -> :gt
    end
  end

  @doc ~S"""
  Works like `Ecto.Changeset.validate_change/3` but may receive multiple fields.

  The `validator` function receives as argument a keyword list, where the keys are the field
  names and the values are the change for this field, or the data.any()

  If none of the given fields has a change, the `validator` function is not invoked.
  """
  def validate_changes(changeset, fields, meta, validator) when is_list(fields) do
      fields_values = Enum.map(fields, &{&1, Ecto.Changeset.fetch_field!(changeset, &1)})

      changeset =
        cond do
          # all of the values are nil
          Enum.all?(fields_values, fn {_, value} -> value == nil end) ->
            changeset

          # none of the values are nil
          Enum.all?(fields_values, fn {_, value} -> value != nil end) ->
            errors = validator.(fields_values)

            if errors do
              Enum.reduce(errors, changeset, fn
                {field, {msg, meta}}, changeset ->
                  Ecto.Changeset.add_error(changeset, field, msg, meta)

                {field, msg}, changeset ->
                  Ecto.Changeset.add_error(changeset, field, msg)
              end)
            else
              changeset
            end

          true ->
            nil_field = Enum.find_value(fields_values, fn {field, value} -> value == nil && field end)

            Ecto.Changeset.add_error(changeset, nil_field, "is invalid", meta)
        end

    validations = Enum.map(fields, &{&1, meta})

    %{changeset | validations: validations ++ changeset.validations}
  end

  @doc ~S"""
  Raises if one of the given field has an invalid value.
  """
  def raise_if_invalid_fields(changeset, keys_validations) do
    unless Keyword.keyword?(keys_validations) do
      raise ArgumentError, message: "`raise_if_invalid_fields/2` expects a keyword list as its second argument"
    end

    ensure_fields_exist!(changeset, keys_validations)
    ensure_validations_exist!(changeset, keys_validations)

    # `keys_validations` may be passed in different formats:
    #   * email: [:required, :length]
    #   * email: :required, email: :length
    keys_validations =
      keys_validations
      # flatten to: email: :required, email: :length
      |> Enum.map(fn {key, validations} ->
        Enum.map(List.wrap(validations), &({key, &1}))
      end)
      |> List.flatten()
      # filter out duplicates
      |> Enum.uniq()
      # regroup to: email: [:required, :length]
      |> Enum.group_by(fn {field, _} -> field end)
      |> Enum.map(fn {field, validations} -> {field, Keyword.values(validations)} end)

    do_raise_if_invalid_fields(changeset, keys_validations)
  end

  def do_raise_if_invalid_fields(%Ecto.Changeset{valid?: false, errors: errors} = changeset, keys_validations) do
    errors
    |> Enum.reverse()
    |> Enum.find_value(fn {key, {_message, meta}} ->
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
      changeset.required
      |> Enum.map(fn field -> {field, :required} end)

    validations =
      Ecto.Changeset.validations(changeset)
      |> Enum.map(fn
        {field, validation_tuple} when is_tuple(validation_tuple) ->
          {field, elem(validation_tuple, 0)}

        {field, validation} when is_atom(validation) ->
          {field, validation}
        end)

    validations = required ++ validations

    keys_validations =
      keys_validations
      |> Enum.map(fn {key, validations} ->
        Enum.map(List.wrap(validations), &({key, &1}))
      end)
      |> List.flatten()
      |> Enum.uniq()

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
