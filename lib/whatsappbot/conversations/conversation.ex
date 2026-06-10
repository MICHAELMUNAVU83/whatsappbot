defmodule Whatsappbot.Conversations.Conversation do
  use Ecto.Schema
  import Ecto.Changeset

  alias Whatsappbot.Conversations.Message
  alias Whatsappbot.Workspaces.Workspace

  schema "conversations" do
    belongs_to :workspace, Workspace

    field :phone_number, :string
    field :source, :string

    has_many :messages, Message

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:workspace_id, :phone_number, :source])
    |> validate_required([:workspace_id, :phone_number, :source])
    |> validate_length(:phone_number, min: 2, max: 100)
    |> validate_length(:source, min: 2, max: 50)
    |> foreign_key_constraint(:workspace_id)
    |> unique_constraint([:workspace_id, :phone_number, :source])
  end
end
