defmodule Whatsappbot.WorkspacesTest do
  use Whatsappbot.DataCase

  alias Whatsappbot.Workspaces

  import Whatsappbot.AccountsFixtures
  import Whatsappbot.WorkspacesFixtures

  describe "create_workspace/2" do
    test "auto-generates a slug from the workspace name" do
      user = user_fixture()

      assert {:ok, workspace} =
               Workspaces.create_workspace(
                 valid_workspace_attributes(name: "Fresh Farm Produce"),
                 user.id
               )

      assert workspace.slug == "fresh-farm-produce"
    end
  end

  describe "get_workspace!/2" do
    test "raises when another user tries to access the workspace" do
      owner = user_fixture()
      intruder = user_fixture()
      workspace = workspace_fixture(owner)

      assert_raise Ecto.NoResultsError, fn ->
        Workspaces.get_workspace!(workspace.id, intruder.id)
      end
    end
  end

  describe "update_workspace/2" do
    test "updates AI instructions" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, updated_workspace} =
               Workspaces.update_workspace(workspace, %{
                 "ai_instructions" => "Only answer using the latest product data."
               })

      assert updated_workspace.ai_instructions == "Only answer using the latest product data."
    end
  end
end
