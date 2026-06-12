defmodule WhatsappbotWeb.MetaLiveTest do
  use WhatsappbotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whatsappbot.AccountsFixtures
  import Whatsappbot.WorkspacesFixtures

  alias Whatsappbot.Meta

  test "saving credentials creates a connection and reveals the webhook panel", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, view, html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/meta")

    assert html =~ "Meta Connection"
    refute html =~ "Callback URL"

    params = %{
      "phone_number_id" => "123456789012345",
      "waba_id" => "987654321098765",
      "access_token" => "EAAG-secret"
    }

    html =
      view
      |> form("form", connection: params)
      |> render_submit()

    assert html =~ "Meta credentials saved"
    assert html =~ "Callback URL"
    assert html =~ "/webhooks/whatsapp/#{workspace.slug}"

    connection = Meta.get_connection(workspace.id)
    assert connection.phone_number_id == "123456789012345"
    assert connection.access_token == "EAAG-secret"
    assert html =~ connection.verify_token
  end

  test "redirects when the workspace belongs to someone else", %{conn: conn} do
    other_workspace = workspace_fixture(user_fixture())

    assert {:error, {:live_redirect, %{to: "/workspaces"}}} =
             conn
             |> log_in_user(user_fixture())
             |> live(~p"/workspaces/#{other_workspace.id}/meta")
  end
end
