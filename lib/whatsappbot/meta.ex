defmodule Whatsappbot.Meta do
  @moduledoc """
  The Meta context. Manages the single WhatsApp Cloud API connection per workspace.
  """

  import Ecto.Query, warn: false

  alias Whatsappbot.Meta.Connection
  alias Whatsappbot.Repo

  @doc "Returns the workspace's Meta connection, or nil."
  def get_connection(workspace_id) do
    Repo.get_by(Connection, workspace_id: workspace_id)
  end

  @doc "Returns the Meta connection for a workspace slug, preloading the workspace."
  def get_connection_by_workspace_slug(slug) do
    query =
      from connection in Connection,
        join: workspace in assoc(connection, :workspace),
        where: workspace.slug == ^slug,
        preload: [workspace: workspace]

    Repo.one(query)
  end

  @doc "Returns the workspace's connection or an unsaved struct to back a form."
  def get_connection_or_new(workspace_id) do
    get_connection(workspace_id) || %Connection{workspace_id: workspace_id}
  end

  def change_connection(%Connection{} = connection, attrs \\ %{}) do
    Connection.credentials_changeset(connection, attrs)
  end

  @doc """
  Inserts or updates the workspace's connection credentials. The verify_token is
  preserved across updates so an already-configured webhook keeps working.
  """
  def upsert_connection(workspace_id, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put("workspace_id", workspace_id)

    workspace_id
    |> get_connection_or_new()
    |> Connection.credentials_changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc "Marks the webhook verified and moves the connection toward active."
  def mark_verified(%Connection{} = connection) do
    update_status(connection, %{
      status: "active",
      webhook_verified_at: DateTime.utc_now() |> DateTime.truncate(:second),
      last_error: nil
    })
  end

  @doc "Records an error against the connection."
  def mark_error(%Connection{} = connection, reason) do
    update_status(connection, %{status: "error", last_error: to_string(reason)})
  end

  defp update_status(%Connection{} = connection, attrs) do
    connection
    |> Connection.status_changeset(attrs)
    |> Repo.update()
  end

  defp normalize_attrs(attrs) do
    for {key, value} <- Map.new(attrs), into: %{} do
      {to_string(key), value}
    end
  end
end
