defmodule Whatsappbot.ConversationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  conversation entities via the `Whatsappbot.Conversations` context.
  """

  alias Whatsappbot.Conversations

  def conversation_fixture(workspace, attrs \\ %{}) do
    phone_number = Map.get(attrs, :phone_number, "+254700#{System.unique_integer([:positive])}")
    source = Map.get(attrs, :source, "playground")

    {:ok, conversation} =
      Conversations.get_or_create_conversation(workspace.id, phone_number, source)

    conversation
  end

  def message_fixture(conversation, attrs \\ %{}) do
    role = Map.get(attrs, :role, "user")
    content = Map.get(attrs, :content, "Hello there")

    options =
      attrs
      |> Map.take([:cta, :endpoint_snapshot, :tokens_used])
      |> Enum.into([])

    {:ok, message} = Conversations.add_message(conversation, role, content, options)
    message
  end
end
