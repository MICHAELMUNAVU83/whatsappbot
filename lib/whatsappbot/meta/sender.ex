defmodule Whatsappbot.Meta.Sender do
  @moduledoc """
  Turns an internal assistant reply (text + optional CTA) into one or more
  WhatsApp Cloud API requests and sends them through Meta's Graph API.

  Supported CTA types: `website`, `phone`, `whatsapp`, `reply_buttons`,
  `list_message`, `location`. Anything else falls back to a plain text reply.
  """

  alias Whatsappbot.Meta.Connection

  require Logger

  @doc """
  Sends `reply_text` (plus optional `cta`) to `to` through the workspace's Meta
  connection. Returns `{:ok, message_id}` for the last message sent, or
  `{:error, reason}` on the first failure.
  """
  def send_reply(%Connection{} = connection, to, reply_text, cta \\ nil) do
    reply_text = reply_text || ""

    cta
    |> build_messages(reply_text)
    |> send_messages(connection, to)
  end

  @doc """
  Sends a pre-approved template message (e.g. `hello_world`). Templates are the
  only message type allowed to open a conversation outside the 24h customer
  service window, so this is the right call for a first proactive test message.
  """
  def send_template(%Connection{} = connection, to, template_name, language_code \\ "en_US") do
    message = %{
      type: "template",
      template: %{name: template_name, language: %{code: language_code}}
    }

    send_message(connection, to, message)
  end

  @doc false
  def build_messages(cta, reply_text) do
    case normalize_cta(cta) do
      {"reply_buttons", payload} ->
        [with_image_header(reply_buttons_message(payload, reply_text), payload)]

      {"list_message", payload} ->
        [with_image_header(list_message(payload, reply_text), payload)]

      {"website", payload} ->
        [with_image_header(website_message(payload, reply_text), payload)]

      {"location", payload} ->
        [text_or_image(reply_text, payload), location_message(payload)]

      {"phone", payload} ->
        [text_or_image(append_line(reply_text, "📞 #{value(payload, "number")}"), payload)]

      {"whatsapp", payload} ->
        number = digits_only(value(payload, "number"))
        [text_or_image(append_line(reply_text, "💬 https://wa.me/#{number}"), payload)]

      {_other, payload} ->
        # custom / catalog and any other typed CTA: keep the text but show the
        # product image as a card when one is available.
        [text_or_image(reply_text, payload)]

      nil ->
        [text_message(reply_text)]
    end
    |> Enum.reject(&is_nil/1)
  end

  defp send_messages([], _connection, _to), do: {:error, :empty_reply}

  defp send_messages(messages, connection, to) do
    Enum.reduce_while(messages, {:error, :empty_reply}, fn message, _acc ->
      case send_message(connection, to, message) do
        {:ok, _id} = ok -> {:cont, ok}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
  end

  defp send_message(connection, to, message), do: do_send(connection, to, message, true)

  defp do_send(
         %Connection{phone_number_id: phone_number_id, access_token: token} = connection,
         to,
         message,
         retry_media?
       ) do
    body = Map.merge(%{messaging_product: "whatsapp", to: to(to)}, message)

    options =
      req_options()
      |> Keyword.merge(
        url: "#{base_url()}/#{phone_number_id}/messages",
        headers: [
          {"authorization", "Bearer #{token}"},
          {"content-type", "application/json"}
        ],
        json: body
      )

    case Req.post(options) do
      {:ok, %Req.Response{status: status, body: response_body}} when status in 200..299 ->
        {:ok, extract_message_id(response_body)}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        reason = "Meta API error (HTTP #{status}): #{error_message(response_body)}"
        maybe_retry_without_media(connection, to, message, reason, retry_media?)

      {:error, reason} ->
        Logger.warning("WhatsApp send transport error: #{inspect(reason)}")
        {:error, "transport error: #{inspect(reason)}"}
    end
  end

  # WhatsApp rejected the image (e.g. unsupported format / unreachable URL). Rather
  # than drop the whole reply, resend it once without the image.
  defp maybe_retry_without_media(connection, to, message, reason, true) do
    case {media_error?(reason), strip_image(message)} do
      {true, stripped} when stripped != message and not is_nil(stripped) ->
        Logger.warning("WhatsApp media rejected, resending without image: #{reason}")
        do_send(connection, to, stripped, false)

      _ ->
        Logger.warning("WhatsApp send failed: #{reason}")
        {:error, reason}
    end
  end

  defp maybe_retry_without_media(_connection, _to, _message, reason, false) do
    Logger.warning("WhatsApp send failed: #{reason}")
    {:error, reason}
  end

  defp media_error?(reason), do: String.contains?(reason, "131053") or reason =~ ~r/media/i

  defp strip_image(%{type: "image", image: image}), do: text_message(Map.get(image, :caption))

  defp strip_image(%{type: "interactive", interactive: interactive} = message),
    do: %{message | interactive: Map.delete(interactive, :header)}

  defp strip_image(message), do: message

  # --- message builders ---

  defp text_message(text) do
    case String.trim(text || "") do
      "" -> nil
      body -> %{type: "text", text: %{preview_url: true, body: truncate(body, 4096)}}
    end
  end

  # Sends an image card with the reply as caption when the CTA carries an image,
  # otherwise falls back to a plain text message.
  defp text_or_image(text, payload) do
    case image_link(payload) do
      nil -> text_message(text)
      link -> image_message(link, text)
    end
  end

  defp image_message(link, caption) do
    image =
      case String.trim(caption || "") do
        "" -> %{link: link}
        body -> %{link: link, caption: truncate(body, 1024)}
      end

    %{type: "image", image: image}
  end

  # Adds an image header to an interactive message (button / list / cta_url) when
  # the payload carries a usable image URL.
  defp with_image_header(%{type: "interactive", interactive: interactive} = message, payload) do
    case image_link(payload) do
      nil ->
        message

      link ->
        header = %{type: "image", image: %{link: link}}
        %{message | interactive: Map.put(interactive, :header, header)}
    end
  end

  defp with_image_header(message, _payload), do: message

  defp image_link(payload) do
    case value(payload, "image_url") do
      url when is_binary(url) ->
        trimmed = String.trim(url)
        if String.match?(trimmed, ~r/^https?:\/\//), do: trimmed, else: nil

      _ ->
        nil
    end
  end

  defp website_message(payload, reply_text) do
    %{
      type: "interactive",
      interactive: %{
        type: "cta_url",
        body: %{text: body_text(payload, reply_text)},
        action: %{
          name: "cta_url",
          parameters: %{
            display_text: value(payload, "title") || "Open link",
            url: value(payload, "url")
          }
        }
      }
    }
  end

  defp reply_buttons_message(payload, reply_text) do
    buttons =
      payload
      |> list_value("buttons")
      |> Enum.take(3)
      |> Enum.with_index()
      |> Enum.map(fn {label, index} ->
        %{
          type: "reply",
          reply: %{id: "btn_#{index}", title: truncate(to_string(label), 20)}
        }
      end)

    %{
      type: "interactive",
      interactive: %{
        type: "button",
        body: %{text: body_text(payload, reply_text)},
        action: %{buttons: buttons}
      }
    }
  end

  defp list_message(payload, reply_text) do
    rows =
      payload
      |> list_value("items")
      |> Enum.take(10)
      |> Enum.with_index()
      |> Enum.map(fn {item, index} ->
        %{
          id: "row_#{index}",
          title: truncate(value(item, "title") || "Option #{index + 1}", 24),
          description: truncate(value(item, "description") || "", 72)
        }
      end)

    %{
      type: "interactive",
      interactive: %{
        type: "list",
        body: %{text: body_text(payload, reply_text)},
        action: %{
          button: truncate(value(payload, "title") || "View options", 20),
          sections: [%{title: "Options", rows: rows}]
        }
      }
    }
  end

  defp location_message(payload) do
    %{
      type: "location",
      location:
        %{
          latitude: to_number(value(payload, "latitude")),
          longitude: to_number(value(payload, "longitude"))
        }
        |> maybe_put(:name, value(payload, "title") || value(payload, "name"))
        |> maybe_put(:address, value(payload, "address") || value(payload, "body"))
    }
  end

  # --- helpers ---

  defp normalize_cta(%{"type" => type, "payload" => payload}) when is_binary(type),
    do: {type, payload || %{}}

  defp normalize_cta(%{type: type, payload: payload}) when is_binary(type),
    do: {type, payload || %{}}

  defp normalize_cta(_), do: nil

  defp body_text(payload, reply_text) do
    text =
      case String.trim(reply_text || "") do
        "" -> value(payload, "body") || value(payload, "title") || "Please choose an option:"
        reply -> reply
      end

    truncate(text, 1024)
  end

  defp value(map, key) when is_map(map), do: Map.get(map, key) || Map.get(map, safe_atom(key))
  defp value(_map, _key), do: nil

  defp list_value(map, key) do
    case value(map, key) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  defp safe_atom(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> :"#{key}__missing"
  end

  defp append_line(text, line) do
    case String.trim(text || "") do
      "" -> line
      body -> body <> "\n\n" <> line
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp to_number(value) when is_number(value), do: value

  defp to_number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, _} -> number
      :error -> 0.0
    end
  end

  defp to_number(_), do: 0.0

  defp digits_only(nil), do: ""
  defp digits_only(value), do: Regex.replace(~r/[^\d]/, to_string(value), "")

  defp truncate(string, max) when is_binary(string) do
    if String.length(string) > max, do: String.slice(string, 0, max), else: string
  end

  defp to(value), do: digits_only(value)

  defp extract_message_id(%{"messages" => [%{"id" => id} | _]}), do: id
  defp extract_message_id(_), do: nil

  defp error_message(body) when is_map(body) do
    get_in(body, ["error", "message"]) || Jason.encode!(body)
  end

  defp error_message(body) when is_binary(body), do: body
  defp error_message(_), do: "request failed"

  defp base_url do
    config = Application.get_env(:whatsappbot, :meta, [])
    version = Keyword.get(config, :graph_api_version, "v21.0")
    "https://graph.facebook.com/#{version}"
  end

  defp req_options do
    Process.get(:meta_req_options) ||
      Application.get_env(:whatsappbot, :meta_req_options, [])
  end
end
