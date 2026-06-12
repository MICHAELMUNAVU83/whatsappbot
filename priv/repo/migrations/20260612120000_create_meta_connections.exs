defmodule Whatsappbot.Repo.Migrations.CreateMetaConnections do
  use Ecto.Migration

  def change do
    create table(:meta_connections) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :phone_number_id, :string
      add :waba_id, :string
      add :access_token_encrypted, :binary
      add :verify_token, :string, null: false
      add :webhook_verified_at, :utc_datetime
      add :status, :string, null: false, default: "pending"
      add :last_error, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:meta_connections, [:workspace_id])
  end
end
