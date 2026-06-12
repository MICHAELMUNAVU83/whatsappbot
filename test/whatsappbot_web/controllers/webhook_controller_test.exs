defmodule WhatsappbotWeb.WebhookControllerTest do
  use WhatsappbotWeb.ConnCase, async: true
  use Oban.Testing, repo: Whatsappbot.Repo

  import Whatsappbot.AccountsFixtures
  import Whatsappbot.MetaFixtures
  import Whatsappbot.WorkspacesFixtures

  alias Whatsappbot.Meta
  alias Whatsappbot.Workers.ProcessInboundMessage

  setup do
    workspace = workspace_fixture(user_fixture())
    connection = connection_fixture(workspace)
    %{workspace: workspace, connection: connection}
  end

  describe "GET verification" do
    test "echoes the challenge and marks the connection verified", %{
      conn: conn,
      workspace: workspace,
      connection: connection
    } do
      conn =
        get(conn, ~p"/webhooks/whatsapp/#{workspace.slug}", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => connection.verify_token,
          "hub.challenge" => "challenge-123"
        })

      assert text_response(conn, 200) == "challenge-123"

      reloaded = Meta.get_connection(workspace.id)
      assert reloaded.status == "active"
      assert reloaded.webhook_verified_at
    end

    test "returns 403 for a wrong verify token", %{conn: conn, workspace: workspace} do
      conn =
        get(conn, ~p"/webhooks/whatsapp/#{workspace.slug}", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => "wrong",
          "hub.challenge" => "challenge-123"
        })

      assert response(conn, 403)
    end

    test "returns 403 for an unknown workspace slug", %{conn: conn} do
      conn =
        get(conn, ~p"/webhooks/whatsapp/does-not-exist", %{
          "hub.mode" => "subscribe",
          "hub.verify_token" => "whatever",
          "hub.challenge" => "x"
        })

      assert response(conn, 403)
    end
  end

  describe "POST inbound message" do
    test "enqueues a job for an inbound text message", %{
      conn: conn,
      workspace: workspace
    } do
      conn = post(conn, ~p"/webhooks/whatsapp/#{workspace.slug}", inbound_payload("wamid.IN1", "Hi"))

      assert response(conn, 200)

      assert_enqueued(
        worker: ProcessInboundMessage,
        args: %{
          "workspace_id" => workspace.id,
          "phone_number" => "254700999888",
          "message_text" => "Hi",
          "whatsapp_message_id" => "wamid.IN1"
        }
      )
    end

    test "deduplicates repeated deliveries of the same message id", %{
      conn: conn,
      workspace: workspace
    } do
      post(conn, ~p"/webhooks/whatsapp/#{workspace.slug}", inbound_payload("wamid.DUP", "Hi"))
      post(conn, ~p"/webhooks/whatsapp/#{workspace.slug}", inbound_payload("wamid.DUP", "Hi"))

      assert length(all_enqueued(worker: ProcessInboundMessage)) == 1
    end

    test "ignores status callbacks", %{conn: conn, workspace: workspace} do
      payload = %{
        "object" => "whatsapp_business_account",
        "entry" => [
          %{
            "changes" => [
              %{"field" => "messages", "value" => %{"statuses" => [%{"status" => "delivered"}]}}
            ]
          }
        ]
      }

      conn = post(conn, ~p"/webhooks/whatsapp/#{workspace.slug}", payload)

      assert response(conn, 200)
      assert all_enqueued(worker: ProcessInboundMessage) == []
    end
  end

  defp inbound_payload(message_id, text) do
    %{
      "object" => "whatsapp_business_account",
      "entry" => [
        %{
          "changes" => [
            %{
              "field" => "messages",
              "value" => %{
                "messages" => [
                  %{
                    "from" => "254700999888",
                    "id" => message_id,
                    "type" => "text",
                    "text" => %{"body" => text}
                  }
                ]
              }
            }
          ]
        }
      ]
    }
  end
end
