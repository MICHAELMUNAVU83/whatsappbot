defmodule Whatsappbot.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  alias Whatsappbot.Accounts.User

  schema "workspaces" do
    belongs_to :account, User, foreign_key: :account_id

    field :name, :string
    field :language, :string
    field :slug, :string
    field :ai_instructions, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:account_id, :name, :slug, :ai_instructions, :language])
    |> validate_required([:account_id, :name, :slug, :language])
    |> validate_length(:name, min: 2, max: 120)
    |> validate_length(:ai_instructions, max: 5000)
    |> validate_inclusion(:language, ~w(en sw both))
    |> foreign_key_constraint(:account_id)
    |> unique_constraint(:slug, name: :workspaces_account_id_slug_index)
  end
end
