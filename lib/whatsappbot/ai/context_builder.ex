defmodule Whatsappbot.AI.ContextBuilder do
  @moduledoc """
  Builds the Claude system prompt from workspace configuration and live business data.
  """

  @max_endpoint_chars 3000

  def build_system_prompt(workspace, endpoint_data) do
    """
    You are an AI sales assistant for #{workspace_field(workspace, :name)}.

    INSTRUCTIONS:
    #{workspace_field(workspace, :ai_instructions) |> present_or_fallback("No additional instructions provided.")}

    LANGUAGE: #{language_instruction(workspace_field(workspace, :language))}

    CURRENT DATA FROM THE BUSINESS:
    #{format_endpoint_data(endpoint_data)}

    RULES:
    - Answer only from the data provided. If you don't know, say so.
    - Be concise. WhatsApp messages should be short.
    - Never make up prices, stock levels, or contact details.
    - At the end of your JSON response, include a "cta" key if a CTA rule applies.
      Otherwise set "cta" to null.

    RESPONSE FORMAT (always valid JSON):
    {
      "reply": "your message text here",
      "cta": null | { "type": "website|phone|whatsapp|reply_buttons|list_message", "payload": {...} }
    }
    """
    |> String.trim()
  end

  defp language_instruction("en"), do: "Respond in English only."
  defp language_instruction("sw"), do: "Respond in Swahili only."

  defp language_instruction("both") do
    "Detect the buyer's language and respond in the same language (English or Swahili)."
  end

  defp language_instruction(_), do: "Respond in English only."

  defp format_endpoint_data(nil), do: "No business data is available right now."

  defp format_endpoint_data(endpoint_data) do
    endpoint_data
    |> Jason.encode!(pretty: true)
    |> truncate_endpoint_text()
  end

  defp truncate_endpoint_text(text) when byte_size(text) <= @max_endpoint_chars, do: text

  defp truncate_endpoint_text(text) do
    String.slice(text, 0, @max_endpoint_chars) <> "\n...[truncated]"
  end

  defp workspace_field(workspace, key) when is_map(workspace) do
    Map.get(workspace, key) || Map.get(workspace, Atom.to_string(key))
  end

  defp present_or_fallback(nil, fallback), do: fallback
  defp present_or_fallback("", fallback), do: fallback
  defp present_or_fallback(value, _fallback), do: value
end
