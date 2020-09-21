defmodule ChangesetHelpersTest do
  use ExUnit.Case
  doctest ChangesetHelpers

  alias ChangesetHelpers.{Account, Address, Article}
  import Ecto.Changeset
  import ChangesetHelpers

  setup do
    account_changeset =
      change(
        %Account{},
        %{
          email: "john@example.net",
          user: %{
            name: "John",
            articles: [
              %{title: "Article 1", comments: [%{body: "Comment 1"}, %{body: "Comment 2"}]},
              %{title: "Article 2", comments: [%{body: "Comment 1"}, %{body: "Comment 2"}]}
            ],
            user_config: %{
              address: %{street: "A street"}
            }
          }
        }
      )

    [account_changeset: account_changeset]
  end

  test "change_assoc", context do
    account_changeset = context[:account_changeset]

    {_, [article_changeset | _]} = change_assoc(account_changeset, [:user, :articles])

    assert %Ecto.Changeset{data: %Article{}} = article_changeset

    account = apply_changes(account_changeset)

    {_, [article_changeset | _]} = change_assoc(account, [:user, :articles])

    assert %Ecto.Changeset{data: %Article{}} = article_changeset

    {_, address_changeset} = change_assoc(account, [:user, :user_config, :address], %{street: "Foo street"})

    assert %Ecto.Changeset{data: %Address{}, changes: %{street: "Foo street"}} = address_changeset
  end

  test "put_assoc", context do
    account_changeset = context[:account_changeset]

    assert article_changeset = %Ecto.Changeset{data: %Article{}}

    address_changeset = change(%Address{}, %{street: "Another street"})

    account_changeset =
      ChangesetHelpers.put_assoc(account_changeset, [:user, :user_config, :address], address_changeset)

    assert "Another street" =
             Ecto.Changeset.fetch_field!(account_changeset, :user)
             |> Map.fetch!(:user_config)
             |> Map.fetch!(:address)
             |> Map.fetch!(:street)

    account_changeset =
      ChangesetHelpers.put_assoc(
        account_changeset,
        [:user, :user_config, :address],
        &change(&1, %{street: "Foo street"})
      )

    assert "Foo street" =
             Ecto.Changeset.fetch_field!(account_changeset, :user)
             |> Map.fetch!(:user_config)
             |> Map.fetch!(:address)
             |> Map.fetch!(:street)
  end

  test "diff_field", context do
    account_changeset = context[:account_changeset]

    {_, address_changeset} =
      change_assoc(account_changeset, [:user, :user_config, :address], %{street: "Another street"})

    new_account_changeset =
      ChangesetHelpers.put_assoc(account_changeset, [:user, :user_config, :address], address_changeset)

    {street_changed, street1, street2} =
      diff_field(account_changeset, new_account_changeset, [:user, :user_config, :address, :street])

    assert {true, "A street", "Another street"} = {street_changed, street1, street2}
  end
end
