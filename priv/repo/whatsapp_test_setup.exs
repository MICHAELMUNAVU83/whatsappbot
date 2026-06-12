# One-off helper to provision an ACTIVE WhatsApp test workspace from the
# credentials in your .env (WA_PHONE_NUMBER_ID, WA_WABA_ID, WA_ACCESS_TOKEN).
#
# Run it with:
#
#     mix run priv/repo/whatsapp_test_setup.exs
#
# It is idempotent — re-running updates the same workspace/connection in place.

import Ecto.Query

alias Whatsappbot.Accounts.User
alias Whatsappbot.Meta
alias Whatsappbot.Repo
alias Whatsappbot.Workspaces.Workspace

# Load .env (the dotenv values aren't exported into System env, only into config),
# so this script can read the WA_* credentials the same way you'd set them.
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

fetch_env = fn key ->
  case System.get_env(key) || Map.get(dotenv, key) do
    value when is_binary(value) and value != "" -> value
    _ -> raise "Missing #{key}. Add it to your .env (see .env.example)."
  end
end

phone_number_id = fetch_env.("WA_PHONE_NUMBER_ID")
waba_id = fetch_env.("WA_WABA_ID")
access_token = fetch_env.("WA_ACCESS_TOKEN")
workspace_slug = fetch_env.("WA_WORKSPACE_SLUG")

# Target the workspace named by WA_WORKSPACE_SLUG. It must already exist so the
# credentials land on a real, configured workspace (data endpoint + CTA rules).
workspace =
  case Repo.one(from w in Workspace, where: w.slug == ^workspace_slug, limit: 1) do
    %Workspace{} = workspace ->
      workspace

    nil ->
      raise "No workspace with slug #{inspect(workspace_slug)}. " <>
              "Create it in the dashboard first, then set WA_WORKSPACE_SLUG in .env."
  end

user = Repo.get!(User, workspace.account_id)

{:ok, connection} =
  Meta.upsert_connection(workspace.id, %{
    "phone_number_id" => phone_number_id,
    "waba_id" => waba_id,
    "access_token" => access_token
  })

# Mark it active so the dashboard reflects a live connection without needing the
# manual Meta webhook handshake first.
{:ok, connection} = Meta.mark_verified(connection)

host = Application.get_env(:whatsappbot, WhatsappbotWeb.Endpoint)[:url][:host] || "localhost"
webhook_path = "/webhooks/whatsapp/#{workspace.slug}"

IO.puts("""

✅ WhatsApp test workspace ready

  Owner user:      #{user.email}
  Workspace:       #{workspace.name} (id: #{workspace.id})
  Slug:            #{workspace.slug}
  Status:          #{connection.status}
  Phone number ID: #{connection.phone_number_id}

  Dashboard:       /workspaces/#{workspace.id}/meta
  Webhook path:    #{webhook_path}
  Local callback:  http://#{host}:4000#{webhook_path}  (expose with a tunnel for Meta)
  Verify token:    #{connection.verify_token}

Next:
  1. Configure your data endpoint + CTA rules for this workspace if you want richer replies.
  2. To receive messages, expose your app over HTTPS (e.g. ngrok) and set the
     callback URL + verify token above in Meta → WhatsApp → Configuration.
""")
