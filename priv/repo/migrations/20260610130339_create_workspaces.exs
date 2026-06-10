defmodule Whatsappbot.Repo.Migrations.CreateWorkspaces do
  use Ecto.Migration

  def change do
    create table(:workspaces) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :ai_instructions, :text
      add :language, :string, null: false, default: "both"
      add :account_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:workspaces, [:account_id])
    create unique_index(:workspaces, [:account_id, :slug])
  end
end
