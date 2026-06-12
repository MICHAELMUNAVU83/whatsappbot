# Sends a test WhatsApp message to yourself through the app's Meta connection.
#
#   mix run priv/repo/whatsapp_send_test.exs
#
# Reads WA_WORKSPACE_SLUG and WA_TEST_RECIPIENT from .env.
#
# By default it sends the `hello_world` template — the only thing allowed to
# start a conversation outside the 24h window. If WA_TEST_TEXT is set, it sends
# that as a free-form text reply instead (only works if the recipient has
# messaged you in the last 24h).

alias Whatsappbot.Meta
alias Whatsappbot.Meta.Sender

dotenv =
  case File.read(Path.expand("../../.env", __DIR__)) do
    {:ok, contents} ->
      contents
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        trimmed = String.trim(line)

        with false <- trimmed == "" or String.starts_with?(trimmed, "#"),
             [key, value] <- String.split(String.trim_leading(trimmed, "export "), "=", parts: 2) do
          Map.put(acc, String.trim(key), String.trim(value))
        else
          _ -> acc
        end
      end)

    {:error, _} ->
      %{}
  end

env = fn key, default -> System.get_env(key) || Map.get(dotenv, key) || default end

slug = env.("WA_WORKSPACE_SLUG", "sokopawa")
to = env.("WA_TEST_RECIPIENT", nil) || raise "Set WA_TEST_RECIPIENT in .env"
text = env.("WA_TEST_TEXT", nil)

connection =
  Meta.get_connection_by_workspace_slug(slug) ||
    raise "No Meta connection for workspace slug #{inspect(slug)}. Run whatsapp_test_setup.exs first."

result =
  if text do
    IO.puts("Sending free-form text to #{to} via #{slug}...")
    Sender.send_reply(connection, to, text)
  else
    IO.puts("Sending hello_world template to #{to} via #{slug}...")
    Sender.send_template(connection, to, "hello_world", "en_US")
  end

case result do
  {:ok, id} -> IO.puts("✅ Sent. message_id=#{id}")
  {:error, reason} -> IO.puts("❌ Failed: #{inspect(reason)}")
end
