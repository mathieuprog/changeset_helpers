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
  def validate_comparison(changeset, field1, operator, field2_or_value, opts \\ [])

  def validate_comparison(%Ecto.Changeset{} = changeset, field1, operator, field2, opts) when is_atom(field2) do
    error_on_field = Keyword.get(opts, :error_on_field, field1)

    operator = operator_abbr(operator)

    validate_changes changeset, [field1, field2], :comparison, fn [{_, value1}, {_, value2}] ->
      if value1 == nil || value2 == nil do
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
  Validates a list of values using the given validator.

  ```elixir
  changeset =
    %Appointment{}
    |> Appointment.changeset(%{days_of_week: [1, 3, 8]})
    |> validate_list(:days_of_week, &Ecto.Changeset.validate_inclusion/3, [1..7])

  assert [days_of_week: {"is invalid", [validation: :list, index: 2, validator: :validate_inclusion]}] = changeset.errors
  assert [days_of_week: {:list, [validator: :validate_inclusion]}] = changeset.validations
  ```
  """
  def validate_list(changeset, field, validation_fun, validation_fun_args) do
    {validation_fun, validation_fun_name} =
      if is_atom(validation_fun) do
        {capture_function(validation_fun, length(validation_fun_args) + 2), validation_fun}
        # + 2 because we must pass the changeset and the field name
      else
        {:name, validation_fun_name} = Function.info(validation_fun, :name)
        {validation_fun, validation_fun_name}
      end

    values = Ecto.Changeset.get_change(changeset, field)

    changeset =
      if values == nil || values == [] do
        changeset
      else
        ecto_type = type(hd(values))

        {errors, index} =
          Enum.reduce_while(values, {[], -1}, fn value, {_errors, index} ->
            data = %{}
            types = %{field => ecto_type}
            params = %{field => value}

            changeset = Ecto.Changeset.cast({data, types}, params, Map.keys(types))
            changeset = apply(validation_fun, [changeset, field | validation_fun_args])

            if match?(%Ecto.Changeset{valid?: false}, changeset) do
              {:halt, {changeset.errors, index + 1}}
            else
              {:cont, {[], index + 1}}
            end
          end)

        case errors do
          [] ->
            changeset

          [{_field, {message, _meta}}] ->
            Ecto.Changeset.add_error(changeset, field, message, validation: :list, index: index, validator: validation_fun_name)
        end
      end

    %{changeset | validations: [{field, {:list, validator: validation_fun_name}} | changeset.validations]}
  end

  defp capture_function(fun_name, args_count), do: Function.capture(Ecto.Changeset, fun_name, args_count)

  defp type(%Time{}), do: :time
  defp type(%Date{}), do: :date
  defp type(%DateTime{}), do: :utc_datetime
  defp type(%NaiveDateTime{}), do: :naive_datetime
  defp type(integer) when is_integer(integer), do: :integer
  defp type(float) when is_float(float), do: :float
  defp type(string) when is_binary(string), do: :string

  @doc ~S"""
  Works like `Ecto.Changeset.validate_change/3` but may receive multiple fields.

  The `validator` function receives as argument a keyword list, where the keys are the field
  names and the values are the change for this field, or the data.any()

  If one of the fields is `nil`, the `validator` function is not invoked.
  """
  def validate_changes(changeset, fields, meta, validator) when is_list(fields) do
    fields_values = Enum.map(fields, &{&1, Ecto.Changeset.fetch_field!(changeset, &1)})

    changeset =
      cond do
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
          changeset
      end

    validations = Enum.map(fields, &{&1, meta})

    %{changeset | validations: validations ++ changeset.validations}
  end

  def field_fails_validation?(changeset, field, validations) do
    validations = List.wrap(validations)
    ensure_field_exists!(changeset, field)
    ensure_validations_exist!(changeset, field, validations)

    do_field_fails_validation?(changeset, field, validations)
  end

  defp do_field_fails_validation?(%Ecto.Changeset{valid?: true}, _, _), do: false

  defp do_field_fails_validation?(changeset, field, validations) do
    errors = get_errors_for_field(changeset, field)

    validations = List.wrap(validations)

    Enum.any?(errors, fn {_key, {_message, meta}} ->
      Enum.member?(validations, meta[:validation])
    end)
  end

  def field_violates_constraint?(changeset, field, constraints) do
    constraints = List.wrap(constraints)
    ensure_field_exists!(changeset, field)
    ensure_constraints_exist!(changeset, field, constraints)

    do_field_violates_constraint?(changeset, field, constraints)
  end

  defp do_field_violates_constraint?(%Ecto.Changeset{valid?: true}, _, _), do: false

  defp do_field_violates_constraint?(changeset, field, constraints) do
    errors = get_errors_for_field(changeset, field)

    constraints = List.wrap(constraints)

    Enum.any?(errors, fn {_key, {_message, meta}} ->
      Enum.member?(constraints, meta[:constraint])
    end)
  end

  defp get_errors_for_field(%Ecto.Changeset{errors: errors}, field) do
    Enum.filter(errors, fn {key, _} -> key == field end)
  end

  defp ensure_field_exists!(%Ecto.Changeset{types: types}, field) do
    unless Map.has_key?(types, field) do
      raise ArgumentError, "unknown field `#{inspect field}`"
    end
  end

  defp ensure_validations_exist!(%Ecto.Changeset{} = changeset, field, validations) do
    required? = Enum.member?(changeset.required, field)

    all_validations =
      Ecto.Changeset.validations(changeset)
      |> Enum.filter(fn {f, _} -> field == f end)
      |> Enum.map(fn
        {_, validation_tuple} when is_tuple(validation_tuple) ->
          elem(validation_tuple, 0)

        {_, validation} when is_atom(validation) ->
          validation
        end)

    all_validations =
      if required? do
        [:required] ++ all_validations
      else
        all_validations
      end

    unknown_validations = validations -- all_validations

    if unknown_validations != [] do
      [validation | _] = unknown_validations
      raise ArgumentError, "unknown validation `#{inspect validation}` for field `#{inspect field}`"
    end
  end

  defp ensure_constraints_exist!(%Ecto.Changeset{} = changeset, field, constraints) do
    all_constraints =
      Ecto.Changeset.constraints(changeset)
      |> Enum.filter(fn %{field: f} -> field == f end)
      |> Enum.map(fn %{type: type} -> type end)

    unknown_constraints = constraints -- all_constraints

    if unknown_constraints != [] do
      [constraint | _] = unknown_constraints
      raise ArgumentError, "unknown constraint `#{inspect constraint}` for field `#{inspect field}`"
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
