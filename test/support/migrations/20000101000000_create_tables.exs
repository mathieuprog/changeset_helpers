defmodule ChangesetHelpers.CreateTables do
  use Ecto.Migration

  def change do
    create table(:addresses) do
      add(:street, :string)
      add(:city, :string)
    end

    create table(:users_configs) do
      add(:name, :string)
      add(:address_id, references(:addresses))
    end

    create table(:users) do
      add(:name, :string)
      add(:users_config_id, references(:users_configs))
    end

    create table(:accounts) do
      add(:name, :string)
      add(:user_id, references(:users))
    end

    create table(:articles) do
      add(:title, :string)
      add(:user_id, references(:users))
    end

    create table(:notes) do
      add(:text, :string)
      add(:user_id, references(:users))
    end

    create table(:comments) do
      add(:body, :string)
      add(:article_id, references(:articles))
    end
  end
end
