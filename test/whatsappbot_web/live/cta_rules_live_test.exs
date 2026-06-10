defmodule WhatsappbotWeb.CTARulesLiveTest do
  use WhatsappbotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whatsappbot.AccountsFixtures
  import Whatsappbot.WorkspacesFixtures

  test "creating a rule makes it appear in the list", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/cta_rules")

    assert view |> element("button", "Add rule") |> render_click() =~ "Add CTA rule"

    params = %{
      "trigger_description" => "When the buyer asks for checkout",
      "cta_type" => "website",
      "priority" => "1",
      "url" => "https://shop.example.com/checkout"
    }

    html =
      view
      |> form("form", cta_rule_form: params)
      |> render_submit()

    assert html =~ "CTA rule created."
    assert html =~ "When the buyer asks for checkout"
    assert html =~ "Website"
    assert html =~ "https://shop.example.com/checkout"
  end
end
