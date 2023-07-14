defmodule ChangesetHelpersTest do
  use ExUnit.Case
  doctest ChangesetHelpers

  alias ChangesetHelpers.{Account, Address, Appointment, Article, User, UserConfig}
  import Ecto.Changeset
  import ChangesetHelpers

  setup do
    account_changeset =
      change(
        %Account{},
        %{
          email: "john@example.net",
          mobile: "0434123456",
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

  test "validate_list/5" do
    appointment_changeset = change(%Appointment{}, %{days_of_week: [1, 3, 8]})

    changeset = validate_list(appointment_changeset, :days_of_week, &Ecto.Changeset.validate_inclusion/3, [1..7])

    assert [days_of_week: {"is invalid", [validation: :list, index: 2, validator: :validate_inclusion]}] = changeset.errors
    assert [days_of_week: {:list, [validator: :validate_inclusion]}] = changeset.validations

    changeset = validate_list(appointment_changeset, :days_of_week, :validate_inclusion, [1..7])

    assert [days_of_week: {"is invalid", [validation: :list, index: 2, validator: :validate_inclusion]}] = changeset.errors
    assert [days_of_week: {:list, [validator: :validate_inclusion]}] = changeset.validations

    appointment_changeset = change(%Appointment{}, %{days_of_week: [1, 3, 5]})

    changeset = validate_list(appointment_changeset, :days_of_week, &Ecto.Changeset.validate_inclusion/3, [1..7])

    assert [] = changeset.errors
    assert [days_of_week: {:list, [validator: :validate_inclusion]}] = changeset.validations

    appointment_changeset = change(%Appointment{}, %{})

    changeset = validate_list(appointment_changeset, :days_of_week, &Ecto.Changeset.validate_inclusion/3, [1..7])

    assert [] = changeset.errors
    assert [days_of_week: {:list, [validator: :validate_inclusion]}] = changeset.validations

    appointment_changeset = change(%Appointment{}, %{days_of_week: []})

    changeset = validate_list(appointment_changeset, :days_of_week, &Ecto.Changeset.validate_inclusion/3, [1..7])

    assert [] = changeset.errors
    assert [days_of_week: {:list, [validator: :validate_inclusion]}] = changeset.validations
  end

  test "validate_comparison/5" do
    appointment_changeset =
      change(
        %Appointment{start_time: ~T[11:00:00]},
        %{
          end_time: ~T[10:00:00],
          start_date: ~D[2021-06-11],
          end_date: ~D[2021-06-11],
          attendees: 5,
          max_attendees: 3,
          int2: 1
        }
      )

    changeset = validate_comparison(appointment_changeset, :start_time, :lt, :end_time)

    assert [start_time: {"must be less than 10:00:00", [validation: :comparison]}] = changeset.errors
    assert [start_time: :comparison, end_time: :comparison] = changeset.validations

    changeset = validate_comparison(appointment_changeset, :start_time, :lt, :end_time, message: "foo")

    assert [start_time: {"foo", [validation: :comparison]}] = changeset.errors
    assert [start_time: :comparison, end_time: :comparison] = changeset.validations

    changeset = validate_comparison(appointment_changeset, :start_time, :lt, :end_time, error_on_field: :end_time)

    assert [end_time: {"must be greater than 11:00:00", [validation: :comparison]}] = changeset.errors
    assert [start_time: :comparison, end_time: :comparison] = changeset.validations

    changeset = validate_comparison(appointment_changeset, :end_time, :gt, ~T[14:00:00])

    assert [end_time: {"must be greater than 14:00:00", [validation: :comparison]}] = changeset.errors
    assert [end_time: :comparison] = changeset.validations

    changeset = validate_comparison(appointment_changeset, :end_time, :gt, ~T[08:00:00])

    assert [] = changeset.errors
    assert [end_time: :comparison] = changeset.validations

    changeset = validate_comparison(appointment_changeset, :attendees, :le, :max_attendees)

    assert [attendees: {"must be less than or equal to 3", [validation: :comparison]}] = changeset.errors
    assert [attendees: :comparison, max_attendees: :comparison] = changeset.validations

    changeset = validate_comparison(appointment_changeset, :foo, :le, :bar)

    assert [] = changeset.errors
    assert [foo: :comparison, bar: :comparison] = changeset.validations

    changeset = validate_comparison(appointment_changeset, :int1, :le, :int2)

    assert [] = changeset.errors
    assert [int1: :comparison, int2: :comparison] = changeset.validations
  end

  test "validate_changes/4", context do
    account_changeset = context[:account_changeset]

    account_changeset1 =
      account_changeset
      |> validate_change(:email, :custom, fn _, _ ->
        [{:email, {"changeset error", [validation: :custom, foo: :bar]}}]
      end)

    assert [email: {"changeset error", [validation: :custom, foo: :bar]}] == account_changeset1.errors
    assert [email: :custom] == account_changeset1.validations

    account_changeset2 =
      account_changeset
      |> validate_changes([:email], :custom, fn arg ->
        assert [email: _] = arg
        [{:email, {"changeset error", [validation: :custom, foo: :bar]}}]
      end)

    assert [email: {"changeset error", [validation: :custom, foo: :bar]}] == account_changeset2.errors
    assert [email: :custom] == account_changeset2.validations

    account_changeset = change(%Account{email: "john@example.net"}, %{mobile: "0434123456"})

    account_changeset3 =
      account_changeset
      |> validate_changes([:email, :mobile], :custom, fn arg ->
        assert [email: _, mobile: _] = arg
        [{:email, {"changeset error", [validation: :custom, foo: :bar]}}]
      end)

    assert [email: {"changeset error", [validation: :custom, foo: :bar]}] == account_changeset3.errors
    assert [email: :custom, mobile: :custom] == account_changeset3.validations
  end

  test "field_violates_constraint?/3", context do
    account_changeset = context[:account_changeset]

    changeset =
      account_changeset
      |> unique_constraint(:email)

    refute field_violates_constraint?(changeset, :email, :unique)
  end

  test "field_fails_validation?/3", context do
    account_changeset = context[:account_changeset]

    changeset =
      account_changeset
      |> validate_length(:email, min: 200)

    assert field_fails_validation?(changeset, :email, :length)

    changeset =
      account_changeset
      |> put_change(:email, "")
      |> validate_required([:email])
      |> validate_length(:email, min: 200)

    assert field_fails_validation?(changeset, :email, :required)

    # `:email` is blank, validation error is `:required`
    changeset =
      account_changeset
      |> put_change(:email, "")
      |> validate_required([:email])
      |> validate_length(:email, min: 200)

    refute field_fails_validation?(changeset, :email, :length)

    # `:foo` field doesn't exist
    assert_raise ArgumentError, "unknown field `:foo`", fn ->
      account_changeset
      |> field_fails_validation?(:foo, :length)
    end

    # no validation `:length` for `:email`
    assert_raise ArgumentError, "unknown validation `:length` for field `:email`", fn ->
      account_changeset
      |> field_fails_validation?(:email, :length)
    end

    changeset =
      account_changeset
      |> validate_required([:email])
      |> validate_length(:mobile, min: 2)
      |> validate_length(:email, min: 3)

    refute field_fails_validation?(changeset, :email, [:length, :required])
    refute field_fails_validation?(changeset, :mobile, :length)

    # `:email` length is invalid but `:mobile` length is valid
    changeset =
      account_changeset
      |> validate_required([:email])
      |> validate_length(:mobile, min: 2)
      |> validate_length(:email, min: 200)

    assert field_fails_validation?(changeset, :email, [:required, :length])
    refute field_fails_validation?(changeset, :mobile, :length)

    changeset =
      account_changeset
      |> validate_required([:email])
      |> validate_length(:mobile, min: 100)
      |> validate_length(:email, min: 3)

    refute field_fails_validation?(changeset, :email, [:length, :required])
    assert field_fails_validation?(changeset, :mobile, :length)

    changeset =
      account_changeset
      |> put_change(:email, "123")
      |> validate_required([:email])
      |> validate_length(:email, min: 200)

    assert field_fails_validation?(changeset, :email, [:length, :required])

    # raise format and not length (raise in order of validations)
    changeset =
      account_changeset
      |> put_change(:email, "123")
      |> validate_required([:email])
      |> validate_format(:email, ~r/@/)
      |> validate_length(:email, min: 200)

    assert field_fails_validation?(changeset, :email, [:length, :format])
    assert field_fails_validation?(changeset, :email, :length)
    assert field_fails_validation?(changeset, :email, :format)
    refute field_fails_validation?(changeset, :email, :required)

    changeset =
      account_changeset
      |> put_change(:email, "123")
      |> validate_required([:email])
      |> validate_length(:email, min: 200)

    assert field_fails_validation?(changeset, :email, [:length, :required])

    changeset =
      account_changeset
      |> put_change(:email, "")
      |> validate_required([:email])
      |> validate_length(:email, min: 3)

    assert field_fails_validation?(changeset, :email, [:length, :required])

    # custom validation
    changeset =
      account_changeset
      |> validate_change(:email, {:custom, []}, fn _, _ ->
        [{:email, {"changeset error", [validation: :custom]}}]
      end)

    assert field_fails_validation?(changeset, :email, :custom)
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
    assert :error = ChangesetHelpers.fetch_change(account_changeset, [:user, :user_config, :address, :city])
    assert :error = ChangesetHelpers.fetch_change(account_changeset, [:user, :dummy])
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
