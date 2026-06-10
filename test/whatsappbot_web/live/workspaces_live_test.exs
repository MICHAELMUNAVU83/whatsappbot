defmodule WhatsappbotWeb.WorkspacesLiveTest do
  use WhatsappbotWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Whatsappbot.AccountsFixtures
  import Whatsappbot.WorkspacesFixtures

  test "another user's workspace cannot be accessed", %{conn: conn} do
    owner = user_fixture()
    intruder = user_fixture()
    workspace = workspace_fixture(owner)

    assert {:error, {:live_redirect, %{to: to, flash: flash}}} =
             conn
             |> log_in_user(intruder)
             |> live(~p"/workspaces/#{workspace.id}")

    assert to == ~p"/workspaces"
    assert flash["error"] == "Workspace not found."
  end
end
