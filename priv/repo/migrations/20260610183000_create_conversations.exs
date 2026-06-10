defmodule Whatsappbot.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :phone_number, :string, null: false
      add :source, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:conversations, [:workspace_id])
    create unique_index(:conversations, [:workspace_id, :phone_number, :source])
  end
end
