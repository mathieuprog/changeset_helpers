defmodule ChangesetHelpersTest do
  use ExUnit.Case
  doctest ChangesetHelpers

  alias ChangesetHelpers.{Account, Address, Article, User, UserConfig}
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

    {_, address_changeset} =
      change_assoc(account, [:user, :user_config, :address], %{street: "Foo street"})

    assert %Ecto.Changeset{data: %Address{}, changes: %{street: "Foo street"}} = address_changeset
  end

  test "change_assoc with NotLoaded assoc" do
    account = %Account{user: %User{}}

    assert {_, []} = change_assoc(account, [:user, :articles])

    account = %Account{}

    assert {_, []} = change_assoc(account, [:user, :articles])
  end

  test "put_assoc", context do
    account_changeset = context[:account_changeset]

    assert article_changeset = %Ecto.Changeset{data: %Article{}}

    address_changeset = change(%Address{}, %{street: "Another street"})

    account_changeset =
      ChangesetHelpers.put_assoc(
        account_changeset,
        [:user, :user_config, :address],
        address_changeset
      )

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

  test "fetch_field", context do
    account_changeset = context[:account_changeset]

    assert {:changes, "A street"} = ChangesetHelpers.fetch_field(account_changeset, [:user, :user_config, :address, :street])
    assert "A street" = ChangesetHelpers.fetch_field!(account_changeset, [:user, :user_config, :address, :street])

    user_changeset = change(%User{name: "John", user_config: %UserConfig{address: %Address{street: "John's street"}}})
    account_changeset = change(%Account{}, %{user: user_changeset})

    assert {:data, "John"} = ChangesetHelpers.fetch_field(account_changeset, [:user, :name])
    assert {:data, "John's street"} = ChangesetHelpers.fetch_field(account_changeset, [:user, :user_config, :address, :street])
  end

  test "fetch_change", context do
    account_changeset = context[:account_changeset]

    assert {:ok, "A street"} = ChangesetHelpers.fetch_change(account_changeset, [:user, :user_config, :address, :street])
    assert "A street" = ChangesetHelpers.fetch_change!(account_changeset, [:user, :user_config, :address, :street])
  end

  test "diff_field", context do
    account_changeset = context[:account_changeset]

    {_, address_changeset} =
      change_assoc(account_changeset, [:user, :user_config, :address], %{street: "Another street"})

    new_account_changeset =
      ChangesetHelpers.put_assoc(
        account_changeset,
        [:user, :user_config, :address],
        address_changeset
      )

    {street_changed, street1, street2} =
      diff_field(account_changeset, new_account_changeset, [
        :user,
        :user_config,
        :address,
        :street
      ])

    assert {true, "A street", "Another street"} = {street_changed, street1, street2}
  end
end
