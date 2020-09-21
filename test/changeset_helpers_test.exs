defmodule ChangesetHelpersTest do
  use ExUnit.Case
  doctest ChangesetHelpers

  alias ChangesetHelpers.{Account, Address, Article}
  import Ecto.Changeset
  import ChangesetHelpers

  test "change_assoc" do
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
              address: %{street: "An address"}
            }
          }
        }
      )

    {_, [article_changeset | _]} = change_assoc(account_changeset, [:user, :articles])

    assert %Ecto.Changeset{data: %Article{}} = article_changeset

    account = apply_changes(account_changeset)

    {_, [article_changeset | _]} = change_assoc(account, [:user, :articles])

    assert %Ecto.Changeset{data: %Article{}} = article_changeset

    {_, address_changeset} = change_assoc(account, [:user, :user_config, :address], %{street: "Foo street"})

    assert %Ecto.Changeset{data: %Address{}, changes: %{street: "Foo street"}} = address_changeset
  end

  test "put_assoc" do
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
              address: %{street: "An address"}
            }
          }
        }
      )

    assert article_changeset = %Ecto.Changeset{data: %Article{}}

    address_changeset = change(%Address{}, %{street: "Another address"})

    account_changeset =
      ChangesetHelpers.put_assoc(account_changeset, [:user, :user_config, :address], address_changeset)

    assert "Another address" =
             Ecto.Changeset.fetch_field!(account_changeset, :user)
             |> Map.fetch!(:user_config)
             |> Map.fetch!(:address)
             |> Map.fetch!(:street)

    account_changeset =
      ChangesetHelpers.put_assoc(
        account_changeset,
        [:user, :user_config, :address],
        &change(&1, %{street: "The address"})
      )

    assert "The address" =
             Ecto.Changeset.fetch_field!(account_changeset, :user)
             |> Map.fetch!(:user_config)
             |> Map.fetch!(:address)
             |> Map.fetch!(:street)
  end

  test "diff_field" do
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
              address: %{street: "An address"}
            }
          }
        }
      )

    {_, address_changeset} =
      change_assoc(account_changeset, [:user, :user_config, :address], %{street: "Another address"})

    new_account_changeset =
      ChangesetHelpers.put_assoc(account_changeset, [:user, :user_config, :address], address_changeset)

    {address_changed, address1, address2} =
      diff_field(account_changeset, new_account_changeset, [:user, :user_config, :address, :street])

    assert {true, "An address", "Another address"} = {address_changed, address1, address2}
  end
end
