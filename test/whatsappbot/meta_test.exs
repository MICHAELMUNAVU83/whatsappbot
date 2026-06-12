defmodule Whatsappbot.MetaTest do
  use Whatsappbot.DataCase, async: true

  import Whatsappbot.AccountsFixtures
  import Whatsappbot.WorkspacesFixtures

  alias Whatsappbot.Meta
  alias Whatsappbot.Repo

  setup do
    %{workspace: workspace_fixture(user_fixture())}
  end

  test "upsert_connection/2 creates a connection with a generated verify token", %{
    workspace: workspace
  } do
    assert {:ok, connection} =
             Meta.upsert_connection(workspace.id, %{
               "phone_number_id" => "111",
               "waba_id" => "222",
               "access_token" => "secret-token"
             })

    assert connection.status == "pending"
    assert is_binary(connection.verify_token)
    assert connection.access_token == "secret-token"
  end

  test "the access token is stored encrypted, not as plaintext", %{workspace: workspace} do
    {:ok, connection} =
      Meta.upsert_connection(workspace.id, %{
        "phone_number_id" => "111",
        "waba_id" => "222",
        "access_token" => "super-secret"
      })

    %{rows: [[raw]]} =
      Repo.query!(
        "SELECT access_token_encrypted FROM meta_connections WHERE id = $1",
        [connection.id]
      )

    refute raw == "super-secret"
    refute to_string(raw) =~ "super-secret"
  end

  test "upsert_connection/2 preserves the verify token across updates", %{workspace: workspace} do
    {:ok, first} = Meta.upsert_connection(workspace.id, base_attrs())
    {:ok, second} = Meta.upsert_connection(workspace.id, base_attrs(%{"waba_id" => "changed"}))

    assert second.verify_token == first.verify_token
    assert second.waba_id == "changed"
  end

  test "mark_verified/1 activates the connection", %{workspace: workspace} do
    {:ok, connection} = Meta.upsert_connection(workspace.id, base_attrs())

    assert {:ok, verified} = Meta.mark_verified(connection)
    assert verified.status == "active"
    assert verified.webhook_verified_at
  end

  test "get_connection_by_workspace_slug/1 finds the connection and preloads the workspace", %{
    workspace: workspace
  } do
    {:ok, _connection} = Meta.upsert_connection(workspace.id, base_attrs())

    found = Meta.get_connection_by_workspace_slug(workspace.slug)
    assert found.workspace.id == workspace.id
  end

  defp base_attrs(overrides \\ %{}) do
    Map.merge(
      %{"phone_number_id" => "111", "waba_id" => "222", "access_token" => "tok"},
      overrides
    )
  end
end
