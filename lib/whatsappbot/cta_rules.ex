defmodule Whatsappbot.CTARules do
  @moduledoc """
  The CTA rules context.
  """

  import Ecto.Query, warn: false

  alias Whatsappbot.CTARules.CTARule
  alias Whatsappbot.Repo

  def list_cta_rules(workspace_id) do
    CTARule
    |> where([rule], rule.workspace_id == ^workspace_id)
    |> order_by([rule], asc: rule.priority, asc: rule.inserted_at, asc: rule.id)
    |> Repo.all()
  end

  def get_cta_rule!(id, workspace_id) do
    CTARule
    |> where([rule], rule.id == ^id and rule.workspace_id == ^workspace_id)
    |> Repo.one!()
  end

  def create_cta_rule(workspace_id, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put("workspace_id", workspace_id)

    %CTARule{}
    |> CTARule.changeset(attrs)
    |> Repo.insert()
  end

  def update_cta_rule(%CTARule{} = rule, attrs) do
    rule
    |> CTARule.changeset(normalize_attrs(attrs))
    |> Repo.update()
  end

  def delete_cta_rule(%CTARule{} = rule) do
    Repo.delete(rule)
  end

  def change_cta_rule(%CTARule{} = rule, attrs \\ %{}) do
    CTARule.changeset(rule, normalize_attrs(attrs))
  end

  def next_priority(workspace_id) do
    workspace_id
    |> list_cta_rules()
    |> Enum.map(& &1.priority)
    |> Enum.max(fn -> 0 end)
    |> Kernel.+(1)
  end

  defp normalize_attrs(attrs) do
    for {key, value} <- Map.new(attrs), into: %{} do
      {to_string(key), value}
    end
  end
end
