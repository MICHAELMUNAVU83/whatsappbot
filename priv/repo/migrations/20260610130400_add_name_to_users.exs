defmodule Whatsappbot.Repo.Migrations.AddNameToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :name, :string
    end

    execute("""
    UPDATE users
    SET name = split_part(email, '@', 1)
    WHERE name IS NULL
    """)

    alter table(:users) do
      modify :name, :string, null: false
    end
  end

  def down do
    alter table(:users) do
      remove :name
    end
  end
end
