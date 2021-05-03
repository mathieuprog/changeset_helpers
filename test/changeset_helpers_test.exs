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

  test "raise_if_invalid", context do
    account_changeset = context[:account_changeset]

    %Ecto.Changeset{} = account_changeset |> raise_if_invalid_fields([:email])

    assert_raise RuntimeError, fn ->
      account_changeset
      |> validate_length(:email, min: 200)
      |> raise_if_invalid_fields([:email])
    end
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

    {_, [article_changeset | _], article_changeset} =
      change_assoc(account, [:user, :articles], 0, %{title: "Article X"})

    assert %Ecto.Changeset{data: %Article{}, changes: %{title: "Article X"}} = article_changeset

    {_, [article1, article2_changeset], article2_changeset} =
      change_assoc(account, [:user, :articles], 1, %{title: "Article Y"})

    assert "Article 1" = Ecto.Changeset.fetch_field!(Ecto.Changeset.change(article1), :title)
    assert %Ecto.Changeset{data: %Article{}, changes: %{title: "Article Y"}} = article2_changeset
  end

  test "change_assoc with NotLoaded assoc" do
    account = %Account{user: %User{}}

    assert {_, []} = change_assoc(account, [:user, :articles])

    account = %Account{}

    assert {_, []} = change_assoc(account, [:user, :articles])
  end

  test "put_assoc", context do
    account_changeset = context[:account_changeset]

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

    article_changeset = change(%Article{}, %{title: "Article X"})

    account_changeset =
      ChangesetHelpers.put_assoc(
        account_changeset,
        [:user, :articles],
        1,
        article_changeset
      )

    assert "Article 1" =
             Ecto.Changeset.fetch_field!(account_changeset, :user)
             |> Map.fetch!(:articles)
             |> Enum.at(0)
             |> Map.fetch!(:title)

    assert "Article X" =
             Ecto.Changeset.fetch_field!(account_changeset, :user)
             |> Map.fetch!(:articles)
             |> Enum.at(1)
             |> Map.fetch!(:title)

    account_changeset =
      ChangesetHelpers.put_assoc(
        account_changeset,
        [:user, :articles],
        1,
        fn _ -> article_changeset end
      )

    assert "Article 1" =
             Ecto.Changeset.fetch_field!(account_changeset, :user)
             |> Map.fetch!(:articles)
             |> Enum.at(0)
             |> Map.fetch!(:title)

    assert "Article X" =
             Ecto.Changeset.fetch_field!(account_changeset, :user)
             |> Map.fetch!(:articles)
             |> Enum.at(1)
             |> Map.fetch!(:title)
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

  test "add_error", context do
    account_changeset = context[:account_changeset]

    account_changeset = ChangesetHelpers.add_error(account_changeset, [:user, :articles, :error_key], "Some error")

    refute account_changeset.valid?

    {_, [article_changeset | _]} = change_assoc(account_changeset, [:user, :articles])

    refute account_changeset.valid?
    assert [error_key: {"Some error", []}] = article_changeset.errors
  end
end
