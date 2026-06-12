defmodule Whatsappbot.Meta.Connection do
  use Ecto.Schema
  import Ecto.Changeset

  alias Whatsappbot.Workspaces.Workspace

  @statuses ~w(pending active error)

  schema "meta_connections" do
    belongs_to :workspace, Workspace

    field :phone_number_id, :string
    field :waba_id, :string
    field :access_token, Whatsappbot.Encrypted.String, source: :access_token_encrypted
    field :verify_token, :string
    field :webhook_verified_at, :utc_datetime
    field :status, :string, default: "pending"
    field :last_error, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for the credentials form. Generates a verify_token on first save and
  resets the connection to a pending state whenever credentials change.
  """
  def credentials_changeset(connection, attrs) do
    connection
    |> cast(attrs, [:workspace_id, :phone_number_id, :waba_id, :access_token])
    |> put_default_verify_token()
    |> put_change(:status, "pending")
    |> put_change(:last_error, nil)
    |> validate_required([:workspace_id, :phone_number_id, :waba_id, :access_token])
    |> validate_length(:phone_number_id, max: 100)
    |> validate_length(:waba_id, max: 100)
    |> validate_length(:access_token, max: 1000)
    |> foreign_key_constraint(:workspace_id)
    |> unique_constraint(:workspace_id)
  end

  @doc """
  Changeset used internally to update connection status / verification fields.
  """
  def status_changeset(connection, attrs) do
    connection
    |> cast(attrs, [:status, :webhook_verified_at, :last_error, :verify_token])
    |> validate_inclusion(:status, @statuses)
  end

  def statuses, do: @statuses

  defp put_default_verify_token(changeset) do
    case get_field(changeset, :verify_token) do
      value when is_binary(value) and value != "" -> changeset
      _ -> put_change(changeset, :verify_token, Ecto.UUID.generate())
    end
  end
end
