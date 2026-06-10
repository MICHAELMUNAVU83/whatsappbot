defmodule Whatsappbot.Repo.Migrations.CreateEndpoints do
  use Ecto.Migration

  def change do
    create table(:endpoints) do
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :url, :string, null: false
      add :method, :string, null: false, default: "GET"
      add :headers_encrypted, :binary
      add :body_template, :text
      add :refresh_strategy, :string, null: false, default: "on_demand"
      add :last_fetched_at, :utc_datetime
      add :cached_data, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:endpoints, [:workspace_id])
    create index(:endpoints, [:refresh_strategy])
  end
end
