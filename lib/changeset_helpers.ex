defmodule ChangesetHelpers do
  @moduledoc """
  Documentation for `ChangesetHelpers`.
  """

  def change_assoc(struct_or_changeset, keys, changes \\ %{}) do
    changed_assoc = do_change_assoc(struct_or_changeset, keys, changes)

    {put_assoc(struct_or_changeset |> Ecto.Changeset.change(), keys, changed_assoc), changed_assoc}
  end

  defp do_change_assoc(%Ecto.Changeset{} = changeset, [key | []], changes) do
    Map.get(changeset.changes, key, Map.fetch!(changeset.data, key))
    |> do_change_assoc(changes)
  end

  defp do_change_assoc(%{__meta__: _} = schema, [key | []], changes) do
    Map.fetch!(schema, key)
    |> do_change_assoc(changes)
  end

  defp do_change_assoc(%Ecto.Changeset{} = changeset, [key | tail_keys], changes) do
    Map.get(changeset.changes, key, Map.fetch!(changeset.data, key))
    |> do_change_assoc(tail_keys, changes)
  end

  defp do_change_assoc(%{__meta__: _} = schema, [key | tail_keys], changes) do
    Map.fetch!(schema, key)
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

  def put_assoc(changeset, [key | []], fun) when is_function(fun) do
    Ecto.Changeset.put_assoc(changeset, key, fun.(do_change_assoc(changeset, [key], %{})))
  end

  def put_assoc(changeset, [key | []], value) do
    Ecto.Changeset.put_assoc(changeset, key, value)
  end

  def put_assoc(changeset, [key | tail_keys], value) do
    Ecto.Changeset.put_assoc(changeset, key, put_assoc(do_change_assoc(changeset, [key], %{}), tail_keys, value))
  end

  def diff_field(changeset1, changeset2, [key | []]) do
    field1 = Ecto.Changeset.fetch_field!(changeset1, key)
    field2 = Ecto.Changeset.fetch_field!(changeset2, key)

    {field1 != field2, field1, field2}
  end

  def diff_field(changeset1, changeset2, [key | tail_keys]) do
    changeset1 = Map.get(changeset1.changes, key, Map.fetch!(changeset1.data, key)) |> Ecto.Changeset.change()
    changeset2 = Map.get(changeset2.changes, key, Map.fetch!(changeset2.data, key)) |> Ecto.Changeset.change()

    diff_field(changeset1, changeset2, tail_keys)
  end
end
