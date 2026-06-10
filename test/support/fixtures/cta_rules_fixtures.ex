defmodule Whatsappbot.CTARulesFixtures do
  @moduledoc """
  Test helpers for CTA rules.
  """

  def valid_cta_rule_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      trigger_description: "When the buyer wants to place an order",
      cta_type: "website",
      cta_payload: %{"url" => "https://shop.example.com/checkout"},
      priority: 1
    })
  end

  def cta_rule_fixture(workspace, attrs \\ %{}) do
    cta_rule_attrs = valid_cta_rule_attributes(attrs)

    {:ok, rule} =
      Whatsappbot.CTARules.create_cta_rule(workspace.id, cta_rule_attrs)

    rule
  end
end
