defmodule WhatsappbotWeb.WebhookController do
  @moduledoc """
  WhatsApp Cloud API webhook endpoints. Meta calls these as plain HTTP requests,
  so they live on the `:api` pipeline (no session / CSRF).
  """

  use WhatsappbotWeb, :controller

  alias Whatsappbot.Meta
  alias Whatsappbot.Workers.ProcessInboundMessage

  require Logger

  @doc """
  GET handler for Meta's webhook verification handshake. Echoes `hub.challenge`
  back as plain text when the verify token matches the stored one.
  """
  def handle_verification(conn, %{"slug" => slug} = params) do
    mode = params["hub.mode"]
    token = params["hub.verify_token"]
    challenge = params["hub.challenge"]

    with "subscribe" <- mode,
         %Meta.Connection{} = connection <- Meta.get_connection_by_workspace_slug(slug),
         true <- secure_compare(connection.verify_token, token) do
      _ = Meta.mark_verified(connection)

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, challenge || "")
    else
      _ ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(403, "Forbidden")
    end
  end

  @doc """
  POST handler for inbound events. Returns 200 immediately and enqueues actual
  user messages for background processing; status callbacks are ignored.
  """
  def handle_message(conn, %{"slug" => slug} = params) do
    case Meta.get_connection_by_workspace_slug(slug) do
      %Meta.Connection{workspace: workspace} ->
        params
        |> extract_inbound_messages()
        |> Enum.each(&enqueue(&1, workspace.id))

      nil ->
        Logger.warning("Inbound webhook for unknown workspace slug: #{slug}")
    end

    send_resp(conn, 200, "ok")
  end

  defp enqueue(%{from: from, text: text, id: id}, workspace_id) do
    %{
      "workspace_id" => workspace_id,
      "phone_number" => from,
      "message_text" => text,
      "whatsapp_message_id" => id
    }
    |> ProcessInboundMessage.new()
    |> Oban.insert()
  end

  # Defensively walk Meta's payload, which can carry multiple entries/changes and
  # several event shapes (messages, statuses, errors). We only keep real inbound
  # text messages.
  defp extract_inbound_messages(%{"entry" => entries}) when is_list(entries) do
    for entry <- entries,
        change <- List.wrap(entry["changes"]),
        message <- List.wrap(get_in(change, ["value", "messages"])),
        inbound = normalize_message(message),
        not is_nil(inbound) do
      inbound
    end
  end

  defp extract_inbound_messages(_params), do: []

  defp normalize_message(%{"from" => from, "id" => id} = message) do
    case message_text(message) do
      nil -> nil
      "" -> nil
      text -> %{from: from, id: id, text: text}
    end
  end

  defp normalize_message(_message), do: nil

  defp message_text(%{"type" => "text", "text" => %{"body" => body}}), do: body

  defp message_text(%{"type" => "interactive", "interactive" => interactive}) do
    get_in(interactive, ["button_reply", "title"]) ||
      get_in(interactive, ["list_reply", "title"])
  end

  defp message_text(%{"type" => "button", "button" => %{"text" => text}}), do: text
  defp message_text(_message), do: nil

  defp secure_compare(nil, _), do: false
  defp secure_compare(_, nil), do: false
  defp secure_compare(left, right), do: Plug.Crypto.secure_compare(left, right)
end
