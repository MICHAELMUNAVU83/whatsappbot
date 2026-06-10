defmodule Whatsappbot.Conversations.Message do
  use Ecto.Schema
  import Ecto.Changeset

  alias Whatsappbot.Conversations.Conversation

  @roles ~w(user assistant system)

  schema "messages" do
    belongs_to :conversation, Conversation

    field :role, :string
    field :content, :string
    field :cta, :map
    field :endpoint_snapshot, :map
    field :tokens_used, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:conversation_id, :role, :content, :cta, :endpoint_snapshot, :tokens_used])
    |> validate_required([:conversation_id, :role, :content])
    |> validate_inclusion(:role, @roles)
    |> validate_length(:content, min: 1, max: 20_000)
    |> validate_number(:tokens_used, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:conversation_id)
  end
end
