defmodule Whatsappbot.AI.CtaInjectorTest do
  use ExUnit.Case, async: true

  alias Whatsappbot.AI.CtaInjector

  test "inject_cta_rules/2 appends numbered CTA rules" do
    prompt = "Base prompt"

    rules = [
      %{
        trigger_description: "Buyer wants to purchase",
        cta_type: "website",
        cta_payload: %{"url" => "https://shop.example.com"}
      },
      %{
        "trigger_description" => "Buyer asks for a phone number",
        "cta_type" => "phone",
        "cta_payload" => %{"number" => "+254700000000"}
      }
    ]

    result = CtaInjector.inject_cta_rules(prompt, rules)

    assert result =~ "CTA RULES (apply the first matching rule):"
    assert result =~ "1. Buyer wants to purchase → use CTA type \"website\""
    assert result =~ ~s({"url":"https://shop.example.com"})
    assert result =~ "2. Buyer asks for a phone number → use CTA type \"phone\""
  end

  test "inject_cta_rules/2 leaves the prompt untouched when no rules are provided" do
    assert CtaInjector.inject_cta_rules("Base prompt", []) == "Base prompt"
    assert CtaInjector.inject_cta_rules("Base prompt", nil) == "Base prompt"
  end
end
