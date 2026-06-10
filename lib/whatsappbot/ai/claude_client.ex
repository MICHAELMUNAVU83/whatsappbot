defmodule Whatsappbot.AI.ClaudeClient do
  @moduledoc """
  Thin client for Anthropic's Messages API.
  """

  @api_url "https://api.anthropic.com/v1/messages"
  @anthropic_version "2023-06-01"

  def chat(messages, system_prompt) when is_list(messages) and is_binary(system_prompt) do
    anthropic_config = Application.fetch_env!(:whatsappbot, :anthropic)

    request_options =
      request_options(anthropic_config, %{
        model: Keyword.fetch!(anthropic_config, :model),
        max_tokens: Keyword.fetch!(anthropic_config, :max_tokens),
        system: system_prompt,
        messages: normalize_messages(messages)
      })

    with {:ok, response} <- Req.post(request_options),
         {:ok, body} <- parse_response(response) do
      build_result(body)
    end
  end

  defp request_options(anthropic_config, payload) do
    default_options =
      Process.get(:claude_req_options) ||
        Application.get_env(:whatsappbot, :claude_req_options, [])

    default_options
    |> Keyword.merge(
      url: @api_url,
      headers: [
        {"x-api-key", Keyword.fetch!(anthropic_config, :api_key)},
        {"anthropic-version", @anthropic_version},
        {"content-type", "application/json"}
      ],
      json: payload
    )
  end

  defp parse_response(%Req.Response{status: status, body: body}) when status in 200..299,
    do: {:ok, body}

  defp parse_response(%Req.Response{status: status, body: body}) do
    {:error, "Anthropic API error (HTTP #{status}): #{error_message(body)}"}
  end

  defp build_result(body) when is_map(body) do
    text = extract_text(body)

    case Jason.decode(text) do
      {:ok, %{"reply" => reply} = parsed} ->
        {:ok,
         %{
           reply: reply,
           cta: Map.get(parsed, "cta"),
           tokens: token_count(body)
         }}

      {:ok, parsed} when is_map(parsed) ->
        {:ok,
         %{
           reply: Map.get(parsed, "reply", text),
           cta: Map.get(parsed, "cta"),
           tokens: token_count(body)
         }}

      {:error, _reason} ->
        {:ok,
         %{
           reply: text,
           cta: nil,
           tokens: token_count(body)
         }}
    end
  end

  defp extract_text(%{"content" => [%{"text" => text} | _]}) when is_binary(text), do: text
  defp extract_text(%{content: [%{text: text} | _]}) when is_binary(text), do: text
  defp extract_text(_body), do: ""

  defp token_count(%{"usage" => usage}) when is_map(usage) do
    usage_value(usage, "input_tokens") + usage_value(usage, "output_tokens")
  end

  defp token_count(%{usage: usage}) when is_map(usage) do
    usage_value(usage, :input_tokens) + usage_value(usage, :output_tokens)
  end

  defp token_count(_body), do: 0

  defp usage_value(usage, key), do: usage |> Map.get(key, 0) |> normalize_integer()

  defp normalize_integer(value) when is_integer(value), do: value
  defp normalize_integer(_value), do: 0

  defp error_message(body) when is_binary(body), do: body

  defp error_message(body) when is_map(body) do
    get_in(body, ["error", "message"]) || Jason.encode!(body)
  end

  defp error_message(_body), do: "request failed"

  defp normalize_messages(messages) do
    Enum.map(messages, fn message ->
      %{
        role: message_field(message, :role) || "user",
        content: message_field(message, :content) || ""
      }
    end)
  end

  defp message_field(message, key) when is_map(message) do
    Map.get(message, key) || Map.get(message, Atom.to_string(key))
  end
end
