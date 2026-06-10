defmodule Whatsappbot.Workspaces do
  @moduledoc """
  The Workspaces context.
  """

  import Ecto.Query, warn: false

  alias Whatsappbot.Repo
  alias Whatsappbot.Workspaces.Workspace

  def list_workspaces(user_id) do
    Workspace
    |> where([workspace], workspace.account_id == ^user_id)
    |> order_by([workspace], desc: workspace.inserted_at)
    |> Repo.all()
  end

  def get_workspace!(id, user_id) do
    Workspace
    |> where([workspace], workspace.id == ^id and workspace.account_id == ^user_id)
    |> Repo.one!()
  end

  def create_workspace(attrs, user_id) do
    attrs = normalize_attrs(attrs)

    attrs =
      attrs
      |> Map.put("account_id", user_id)
      |> Map.put("slug", unique_slug(user_id, attrs))

    %Workspace{}
    |> Workspace.changeset(attrs)
    |> Repo.insert()
  end

  def update_workspace(%Workspace{} = workspace, attrs) do
    workspace
    |> Workspace.changeset(normalize_attrs(attrs))
    |> Repo.update()
  end

  def delete_workspace(%Workspace{} = workspace) do
    Repo.delete(workspace)
  end

  def change_workspace(%Workspace{} = workspace, attrs \\ %{}) do
    Workspace.changeset(workspace, normalize_attrs(attrs))
  end

  defp unique_slug(user_id, attrs) do
    base_slug =
      attrs
      |> workspace_name()
      |> slugify()

    Stream.iterate(0, &(&1 + 1))
    |> Enum.find_value(fn suffix ->
      candidate = if suffix == 0, do: base_slug, else: "#{base_slug}-#{suffix + 1}"

      exists? =
        Workspace
        |> where([workspace], workspace.account_id == ^user_id and workspace.slug == ^candidate)
        |> Repo.exists?()

      if exists?, do: nil, else: candidate
    end)
  end

  defp workspace_name(attrs) do
    attrs["name"] || attrs[:name] || "workspace"
  end

  defp normalize_attrs(attrs) do
    for {key, value} <- Map.new(attrs), into: %{} do
      {to_string(key), value}
    end
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.trim()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "workspace"
      slug -> slug
    end
  end
end
