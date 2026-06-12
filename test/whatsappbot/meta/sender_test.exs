defmodule Whatsappbot.Meta.SenderTest do
  use Whatsappbot.DataCase, async: true

  import Whatsappbot.AccountsFixtures
  import Whatsappbot.MetaFixtures
  import Whatsappbot.WorkspacesFixtures

  alias Whatsappbot.Meta.Sender

  setup {Req.Test, :verify_on_exit!}

  setup do
    on_exit(fn -> Process.delete(:meta_req_options) end)
    :ok
  end

  describe "build_messages/2" do
    test "plain reply builds a single text message" do
      assert [%{type: "text", text: %{body: "Hello there"}}] =
               Sender.build_messages(nil, "Hello there")
    end

    test "reply_buttons builds an interactive button message with up to 3 buttons" do
      cta = %{
        "type" => "reply_buttons",
        "payload" => %{"body" => "Pick one", "buttons" => ["A", "B", "C", "D"]}
      }

      assert [%{type: "interactive", interactive: interactive}] =
               Sender.build_messages(cta, "Reply text wins as body")

      assert interactive.type == "button"
      assert interactive.body.text == "Reply text wins as body"
      assert length(interactive.action.buttons) == 3
      assert Enum.map(interactive.action.buttons, & &1.reply.title) == ["A", "B", "C"]
    end

    test "list_message builds an interactive list with rows" do
      cta = %{
        "type" => "list_message",
        "payload" => %{
          "title" => "Menu",
          "items" => [
            %{"title" => "Tomatoes", "description" => "Fresh"},
            %{"title" => "Onions", "description" => "Red"}
          ]
        }
      }

      assert [%{interactive: %{type: "list", action: action}}] =
               Sender.build_messages(cta, "Browse")

      assert action.button == "Menu"
      assert [%{rows: rows}] = action.sections
      assert Enum.map(rows, & &1.title) == ["Tomatoes", "Onions"]
    end

    test "website builds a cta_url interactive message" do
      cta = %{"type" => "website", "payload" => %{"url" => "https://shop.example.com", "title" => "Shop"}}

      assert [%{interactive: %{type: "cta_url", action: action}}] =
               Sender.build_messages(cta, "Here you go")

      assert action.parameters.url == "https://shop.example.com"
      assert action.parameters.display_text == "Shop"
    end

    test "location builds a text message followed by a location message" do
      cta = %{
        "type" => "location",
        "payload" => %{"latitude" => "-1.29", "longitude" => 36.82, "title" => "Shop"}
      }

      assert [%{type: "text"}, %{type: "location", location: location}] =
               Sender.build_messages(cta, "We are here")

      assert location.latitude == -1.29
      assert location.longitude == 36.82
      assert location.name == "Shop"
    end

    test "phone folds the number into the text reply" do
      cta = %{"type" => "phone", "payload" => %{"number" => "+254700000000"}}

      assert [%{type: "text", text: %{body: body}}] = Sender.build_messages(cta, "Call us")
      assert body =~ "Call us"
      assert body =~ "+254700000000"
    end

    test "an image_url is attached as an interactive header" do
      cta = %{
        "type" => "website",
        "payload" => %{
          "url" => "https://shop.example.com",
          "image_url" => "https://cdn.example.com/p.jpg"
        }
      }

      assert [%{interactive: %{header: header}}] = Sender.build_messages(cta, "Here it is")
      assert header == %{type: "image", image: %{link: "https://cdn.example.com/p.jpg"}}
    end

    test "a product CTA with an image sends an image card with the reply as caption" do
      cta = %{
        "type" => "phone",
        "payload" => %{"number" => "254700000000", "image_url" => "https://cdn.example.com/p.jpg"}
      }

      assert [%{type: "image", image: image}] = Sender.build_messages(cta, "Fresh tomatoes")
      assert image.link == "https://cdn.example.com/p.jpg"
      assert image.caption =~ "Fresh tomatoes"
      assert image.caption =~ "254700000000"
    end

    test "a non-http image_url is ignored" do
      cta = %{
        "type" => "website",
        "payload" => %{"url" => "https://shop.example.com", "image_url" => "not-a-url"}
      }

      assert [%{interactive: interactive}] = Sender.build_messages(cta, "Here it is")
      refute Map.has_key?(interactive, :header)
    end
  end

  describe "send_reply/4" do
    test "posts to the phone number's messages endpoint and returns the message id" do
      workspace = workspace_fixture(user_fixture())
      connection = connection_fixture(workspace)

      Req.Test.expect(__MODULE__.SendStub, fn conn ->
        version = Application.get_env(:whatsappbot, :meta)[:graph_api_version]
        assert conn.method == "POST"
        assert conn.request_path == "/#{version}/#{connection.phone_number_id}/messages"

        body =
          conn
          |> Req.Test.raw_body()
          |> IO.iodata_to_binary()
          |> Jason.decode!()

        assert body["messaging_product"] == "whatsapp"
        assert body["to"] == "254700111222"
        assert body["type"] == "text"

        Req.Test.json(conn, %{"messages" => [%{"id" => "wamid.OUT123"}]})
      end)

      Process.put(:meta_req_options, plug: {Req.Test, __MODULE__.SendStub})

      assert {:ok, "wamid.OUT123"} =
               Sender.send_reply(connection, "+254 700 111 222", "Hello!", nil)
    end

    test "retries without the image when Meta rejects the media" do
      workspace = workspace_fixture(user_fixture())
      connection = connection_fixture(workspace)

      cta = %{
        "type" => "website",
        "payload" => %{
          "url" => "https://shop.example.com",
          "image_url" => "https://cdn.example.com/broken.webp"
        }
      }

      # First call (with image header) is rejected; second call (stripped) succeeds.
      Req.Test.expect(__MODULE__.MediaStub, fn conn ->
        body = conn |> Req.Test.raw_body() |> IO.iodata_to_binary() |> Jason.decode!()
        assert get_in(body, ["interactive", "header"])

        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{"error" => %{"message" => "(#131053) Media upload error"}})
      end)

      Req.Test.expect(__MODULE__.MediaStub, fn conn ->
        body = conn |> Req.Test.raw_body() |> IO.iodata_to_binary() |> Jason.decode!()
        refute get_in(body, ["interactive", "header"])

        Req.Test.json(conn, %{"messages" => [%{"id" => "wamid.RETRY"}]})
      end)

      Process.put(:meta_req_options, plug: {Req.Test, __MODULE__.MediaStub})

      assert {:ok, "wamid.RETRY"} = Sender.send_reply(connection, "254700111222", "Here it is", cta)
    end

    test "returns an error tuple on a non-2xx response" do
      workspace = workspace_fixture(user_fixture())
      connection = connection_fixture(workspace)

      Req.Test.expect(__MODULE__.ErrorStub, fn conn ->
        conn
        |> Plug.Conn.put_status(401)
        |> Req.Test.json(%{"error" => %{"message" => "Invalid token"}})
      end)

      Process.put(:meta_req_options, plug: {Req.Test, __MODULE__.ErrorStub})

      assert {:error, reason} = Sender.send_reply(connection, "254700111222", "Hi", nil)
      assert reason =~ "Invalid token"
    end
  end
end
