defmodule Whatsappbot.ConversationsTest do
  use Whatsappbot.DataCase, async: true

  import Whatsappbot.AccountsFixtures
  import Whatsappbot.ConversationsFixtures
  import Whatsappbot.WorkspacesFixtures

  alias Whatsappbot.Conversations

  describe "get_or_create_conversation/3" do
    test "returns the existing conversation for the same workspace, number, and source" do
      workspace = workspace_fixture(user_fixture())

      assert {:ok, conversation} =
               Conversations.get_or_create_conversation(
                 workspace.id,
                 "+254700111222",
                 :playground
               )

      assert {:ok, same_conversation} =
               Conversations.get_or_create_conversation(
                 workspace.id,
                 "+254700111222",
                 "playground"
               )

      assert conversation.id == same_conversation.id
    end
  end

  describe "list_conversations/1" do
    test "orders conversations by latest message first" do
      workspace = workspace_fixture(user_fixture())
      older = conversation_fixture(workspace, %{phone_number: "+254700000001"})
      newer = conversation_fixture(workspace, %{phone_number: "+254700000002"})

      message_fixture(older, %{content: "First message"})
      Process.sleep(5)
      message_fixture(newer, %{content: "Newest message"})

      assert Enum.map(Conversations.list_conversations(workspace.id), & &1.id) == [
               newer.id,
               older.id
             ]
    end
  end

  describe "get_conversation!/2" do
    test "raises for a conversation outside the workspace" do
      first_workspace = workspace_fixture(user_fixture())
      second_workspace = workspace_fixture(user_fixture())
      conversation = conversation_fixture(first_workspace)

      assert_raise Ecto.NoResultsError, fn ->
        Conversations.get_conversation!(conversation.id, second_workspace.id)
      end
    end
  end

  describe "add_message/4" do
    test "stores CTA, endpoint snapshot, and token metadata" do
      workspace = workspace_fixture(user_fixture())
      conversation = conversation_fixture(workspace)

      assert {:ok, message} =
               Conversations.add_message(conversation, :assistant, "Here is your answer",
                 cta: %{"type" => "website", "payload" => %{"url" => "https://shop.example.com"}},
                 endpoint_snapshot: [%{"sku" => "A1"}],
                 tokens_used: 88
               )

      assert message.cta["type"] == "website"
      assert message.endpoint_snapshot == %{"items" => [%{"sku" => "A1"}]}
      assert message.tokens_used == 88
    end
  end

  describe "list_messages/1" do
    test "returns the last 50 messages ordered ascending" do
      workspace = workspace_fixture(user_fixture())
      conversation = conversation_fixture(workspace)

      for index <- 1..55 do
        message_fixture(conversation, %{content: "Message #{index}"})
      end

      messages = Conversations.list_messages(conversation.id)

      assert length(messages) == 50
      assert hd(messages).content == "Message 6"
      assert List.last(messages).content == "Message 55"
    end
  end

  describe "build_messages/2" do
    test "returns the last 10 messages in Anthropic format and appends the new user message once" do
      workspace = workspace_fixture(user_fixture())
      conversation = conversation_fixture(workspace)

      for index <- 1..12 do
        role = if rem(index, 2) == 0, do: :assistant, else: :user
        message_fixture(conversation, %{role: role, content: "Message #{index}"})
      end

      messages = Conversations.build_messages(conversation.id, "Do you have onions?")

      assert length(messages) == 11
      assert hd(messages) == %{role: "user", content: "Message 3"}
      assert List.last(messages) == %{role: "user", content: "Do you have onions?"}
    end

    test "does not duplicate the just-saved user message" do
      workspace = workspace_fixture(user_fixture())
      conversation = conversation_fixture(workspace)

      message_fixture(conversation, %{role: :assistant, content: "Hello"})
      message_fixture(conversation, %{role: :user, content: "Current question"})

      assert Conversations.build_messages(conversation.id, "Current question") == [
               %{role: "assistant", content: "Hello"},
               %{role: "user", content: "Current question"}
             ]
    end
  end
end
