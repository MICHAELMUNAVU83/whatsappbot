defmodule Whatsappbot.CTARules.CTARule do
  use Ecto.Schema
  import Ecto.Changeset

  alias Whatsappbot.Workspaces.Workspace

  @cta_types ~w(website phone whatsapp reply_buttons list_message location catalog custom)

  schema "cta_rules" do
    belongs_to :workspace, Workspace

    field :trigger_description, :string
    field :cta_type, :string
    field :cta_payload, :map
    field :priority, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(cta_rule, attrs) do
    cta_rule
    |> cast(attrs, [:workspace_id, :trigger_description, :cta_type, :cta_payload, :priority])
    |> validate_required([:workspace_id, :trigger_description, :cta_type, :cta_payload, :priority])
    |> validate_length(:trigger_description, min: 5, max: 500)
    |> validate_inclusion(:cta_type, @cta_types)
    |> validate_number(:priority, greater_than_or_equal_to: 1)
    |> validate_change(:cta_payload, fn :cta_payload, payload ->
      if is_map(payload) and map_size(payload) > 0 do
        []
      else
        [cta_payload: "must include CTA details"]
      end
    end)
    |> foreign_key_constraint(:workspace_id)
  end

  def cta_types, do: @cta_types
end
