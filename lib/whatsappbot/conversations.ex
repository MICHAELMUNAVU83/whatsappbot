defmodule Whatsappbot.Conversations do
  @moduledoc """
  The Conversations context.
  """

  import Ecto.Query, warn: false

  alias Whatsappbot.Conversations.Conversation
  alias Whatsappbot.Conversations.Message
  alias Whatsappbot.Repo

  @pubsub Whatsappbot.PubSub

  def get_conversation(workspace_id, phone_number, source) do
    Repo.get_by(Conversation,
      workspace_id: workspace_id,
      phone_number: phone_number,
      source: normalize_source(source)
    )
  end

  def get_or_create_conversation(workspace_id, phone_number, source) do
    attrs = %{
      "workspace_id" => workspace_id,
      "phone_number" => phone_number,
      "source" => normalize_source(source)
    }

    case Repo.get_by(Conversation,
           workspace_id: workspace_id,
           phone_number: phone_number,
           source: attrs["source"]
         ) do
      %Conversation{} = conversation ->
        {:ok, conversation}

      nil ->
        %Conversation{}
        |> Conversation.changeset(attrs)
        |> Repo.insert()
        |> case do
          {:ok, conversation} ->
            {:ok, conversation}

          {:error, changeset} ->
            case Repo.get_by(Conversation,
                   workspace_id: workspace_id,
                   phone_number: phone_number,
                   source: attrs["source"]
                 ) do
              %Conversation{} = conversation -> {:ok, conversation}
              nil -> {:error, changeset}
            end
        end
    end
  end

  def list_conversations(workspace_id) do
    latest_messages =
      from message in Message,
        group_by: message.conversation_id,
        select: %{
          conversation_id: message.conversation_id,
          latest_message_at: max(message.inserted_at),
          latest_message_id: max(message.id)
        }

    Conversation
    |> where([conversation], conversation.workspace_id == ^workspace_id)
    |> join(:left, [conversation], latest in subquery(latest_messages),
      on: latest.conversation_id == conversation.id
    )
    |> order_by([conversation, latest],
      desc_nulls_last: latest.latest_message_at,
      desc_nulls_last: latest.latest_message_id,
      desc: conversation.inserted_at
    )
    |> select([conversation, _latest], conversation)
    |> Repo.all()
  end

  def get_conversation!(id, workspace_id) do
    Conversation
    |> where(
      [conversation],
      conversation.id == ^id and conversation.workspace_id == ^workspace_id
    )
    |> Repo.one!()
  end

  def add_message(%Conversation{} = conversation, role, content, opts \\ []) do
    attrs = %{
      "conversation_id" => conversation.id,
      "role" => normalize_role(role),
      "content" => content,
      "cta" => opts[:cta],
      "endpoint_snapshot" => normalize_endpoint_snapshot(opts[:endpoint_snapshot]),
      "tokens_used" => opts[:tokens_used]
    }

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  def list_messages(conversation_id) do
    ordered_recent_messages(conversation_id, 50)
  end

  def delete_conversation(%Conversation{} = conversation) do
    Repo.delete(conversation)
  end

  def build_messages(conversation_id, new_user_message) do
    existing_messages =
      conversation_id
      |> ordered_recent_messages(10)
      |> Enum.map(&%{role: &1.role, content: &1.content})

    user_message = %{
      role: "user",
      content: normalize_content(new_user_message)
    }

    cond do
      user_message.content == "" ->
        existing_messages

      List.last(existing_messages) == user_message ->
        existing_messages

      true ->
        existing_messages ++ [user_message]
    end
  end

  def subscribe_conversation(conversation_id) do
    Phoenix.PubSub.subscribe(@pubsub, conversation_topic(conversation_id))
  end

  def subscribe_playground(workspace_id) do
    Phoenix.PubSub.subscribe(@pubsub, playground_topic(workspace_id))
  end

  def broadcast_new_message(%Message{} = message) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      conversation_topic(message.conversation_id),
      {:new_message, message}
    )
  end

  def broadcast_playground_message(workspace_id, %Message{} = message) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      playground_topic(workspace_id),
      {:new_message, message}
    )
  end

  def broadcast_playground_cleared(workspace_id) do
    Phoenix.PubSub.broadcast(
      @pubsub,
      playground_topic(workspace_id),
      {:conversation_cleared, workspace_id}
    )
  end

  def conversation_topic(conversation_id), do: "conversation:#{conversation_id}"
  def playground_phone_number(workspace_id), do: "playground_#{workspace_id}"
  def playground_topic(workspace_id), do: "conversation:playground_#{workspace_id}"

  defp ordered_recent_messages(conversation_id, limit) do
    recent_messages =
      Message
      |> where([message], message.conversation_id == ^conversation_id)
      |> order_by([message], desc: message.inserted_at, desc: message.id)
      |> limit(^limit)

    from(message in subquery(recent_messages),
      order_by: [asc: message.inserted_at, asc: message.id]
    )
    |> Repo.all()
  end

  defp normalize_source(source) when is_atom(source), do: Atom.to_string(source)
  defp normalize_source(source) when is_binary(source), do: source

  defp normalize_role(role) when is_atom(role), do: Atom.to_string(role)
  defp normalize_role(role) when is_binary(role), do: role

  defp normalize_content(content) when is_binary(content), do: String.trim(content)
  defp normalize_content(content), do: content |> to_string() |> String.trim()

  defp normalize_endpoint_snapshot(nil), do: nil
  defp normalize_endpoint_snapshot(snapshot) when is_map(snapshot), do: snapshot
  defp normalize_endpoint_snapshot(snapshot) when is_list(snapshot), do: %{"items" => snapshot}
  defp normalize_endpoint_snapshot(snapshot), do: %{"value" => snapshot}
end
