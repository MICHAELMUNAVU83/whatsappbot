defmodule Whatsappbot.Conversations.DispatcherTest do
  use Whatsappbot.DataCase, async: true

  import Whatsappbot.AccountsFixtures
  import Whatsappbot.EndpointsFixtures
  import Whatsappbot.WorkspacesFixtures

  alias Whatsappbot.Conversations
  alias Whatsappbot.Conversations.Dispatcher

  setup {Req.Test, :verify_on_exit!}

  setup do
    on_exit(fn ->
      Process.delete(:endpoint_req_options)
      Process.delete(:claude_req_options)
    end)

    :ok
  end

  test "dispatch/4 saves both messages and broadcasts the assistant reply" do
    workspace = workspace_fixture(user_fixture())

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      method: "GET",
      refresh_strategy: "on_demand"
    })

    Req.Test.expect(__MODULE__.EndpointStub, fn conn ->
      assert conn.method == "GET"
      Req.Test.json(conn, [%{"name" => "Tomatoes", "price" => 120}])
    end)

    Req.Test.expect(__MODULE__.ClaudeStub, fn conn ->
      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert request["messages"] == [%{"role" => "user", "content" => "Do you have tomatoes?"}]
      assert request["system"] =~ "Tomatoes"

      Req.Test.json(conn, %{
        "content" => [
          %{
            "type" => "text",
            "text" =>
              ~s({"reply":"Yes, tomatoes are available.","cta":{"type":"website","payload":{"url":"https://shop.example.com/tomatoes"}}})
          }
        ],
        "usage" => %{"input_tokens" => 33, "output_tokens" => 12}
      })
    end)

    Process.put(:endpoint_req_options, plug: {Req.Test, __MODULE__.EndpointStub})
    Process.put(:claude_req_options, plug: {Req.Test, __MODULE__.ClaudeStub})

    assert {:ok, conversation} =
             Conversations.get_or_create_conversation(
               workspace.id,
               "playground_#{workspace.id}",
               :playground
             )

    assert :ok = Conversations.subscribe_conversation(conversation.id)

    assert {:ok, assistant_message} =
             Dispatcher.dispatch(
               workspace.id,
               "playground_#{workspace.id}",
               "Do you have tomatoes?",
               :playground
             )

    assert assistant_message.role == "assistant"
    assert assistant_message.tokens_used == 45
    assert assistant_message.cta["type"] == "website"

    assert_receive {:new_message, broadcast_message}
    assert broadcast_message.id == assistant_message.id

    messages = Conversations.list_messages(conversation.id)
    assert Enum.map(messages, & &1.role) == ["user", "assistant"]

    assert hd(messages).endpoint_snapshot == %{
             "items" => [%{"name" => "Tomatoes", "price" => 120}]
           }

    assert List.last(messages).content == "Yes, tomatoes are available."
  end

  test "dispatch/4 uses cached endpoint data when the endpoint is not on-demand" do
    workspace = workspace_fixture(user_fixture())

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      refresh_strategy: "poll_60s",
      cached_data: %{"items" => [%{"name" => "Onions"}]}
    })

    Req.Test.expect(__MODULE__.CachedClaudeStub, fn conn ->
      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert request["system"] =~ "Onions"

      Req.Test.json(conn, %{
        "content" => [
          %{"type" => "text", "text" => ~s({"reply":"Onions are in stock.","cta":null})}
        ]
      })
    end)

    Process.put(:claude_req_options, plug: {Req.Test, __MODULE__.CachedClaudeStub})

    assert {:ok, _assistant_message} =
             Dispatcher.dispatch(
               workspace.id,
               "cached-phone",
               "Do you have onions?",
               "playground"
             )

    assert {:ok, conversation} =
             Conversations.get_or_create_conversation(workspace.id, "cached-phone", "playground")

    [user_message, assistant_message] = Conversations.list_messages(conversation.id)

    assert user_message.endpoint_snapshot == %{"items" => [%{"name" => "Onions"}]}
    assert assistant_message.content == "Onions are in stock."
  end
end
