defmodule Whatsappbot.AI.CtaInjector do
  @moduledoc """
  Appends CTA rule guidance to the Claude system prompt.
  """

  def inject_cta_rules(system_prompt, cta_rules) when cta_rules in [nil, []] do
    system_prompt
  end

  def inject_cta_rules(system_prompt, cta_rules) when is_list(cta_rules) do
    rules_text =
      cta_rules
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {rule, index} ->
        "#{index}. #{rule_field(rule, :trigger_description)} → use CTA type " <>
          ~s("#{rule_field(rule, :cta_type)}") <>
          " with payload #{format_payload(rule_field(rule, :cta_payload))}"
      end)

    String.trim_trailing(system_prompt) <>
      "\n\nCTA RULES (apply the first matching rule):\n" <> rules_text
  end

  defp format_payload(payload) when is_binary(payload), do: payload
  defp format_payload(payload), do: Jason.encode!(payload || %{})

  defp rule_field(rule, key) when is_map(rule) do
    Map.get(rule, key) || Map.get(rule, Atom.to_string(key))
  end
end
