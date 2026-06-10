defmodule Whatsappbot.Repo.Migrations.CreateCtaRules do
  use Ecto.Migration

  def change do
    create table(:cta_rules) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :trigger_description, :string, null: false
      add :cta_type, :string, null: false
      add :cta_payload, :map, null: false
      add :priority, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:cta_rules, [:workspace_id])
    create index(:cta_rules, [:workspace_id, :priority])
  end
end
