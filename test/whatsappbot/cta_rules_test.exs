defmodule Whatsappbot.CTARulesTest do
  use Whatsappbot.DataCase, async: true

  alias Whatsappbot.CTARules

  import Whatsappbot.AccountsFixtures
  import Whatsappbot.CTARulesFixtures
  import Whatsappbot.WorkspacesFixtures

  describe "list_cta_rules/1" do
    test "returns rules ordered by ascending priority" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      low = cta_rule_fixture(workspace, %{priority: 1, trigger_description: "Lowest priority"})
      mid = cta_rule_fixture(workspace, %{priority: 2, trigger_description: "Middle priority"})
      high = cta_rule_fixture(workspace, %{priority: 3, trigger_description: "Highest priority"})

      assert Enum.map(CTARules.list_cta_rules(workspace.id), & &1.id) == [low.id, mid.id, high.id]
    end
  end

  describe "update_cta_rule/2" do
    test "updates the CTA type and payload" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      rule = cta_rule_fixture(workspace)

      assert {:ok, updated_rule} =
               CTARules.update_cta_rule(rule, %{
                 "cta_type" => "phone",
                 "cta_payload" => %{"number" => "+254700000001"}
               })

      assert updated_rule.cta_type == "phone"
      assert updated_rule.cta_payload == %{"number" => "+254700000001"}
    end
  end
end
