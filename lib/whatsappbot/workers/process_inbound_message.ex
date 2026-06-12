defmodule Whatsappbot.Workers.ProcessInboundMessage do
  @moduledoc """
  Processes a single inbound WhatsApp message: runs it through the shared
  conversation `Dispatcher` and sends the assistant reply back through Meta.

  Duplicate protection is handled by Oban uniqueness keyed on the WhatsApp
  message id, so Meta's at-least-once webhook delivery never double-processes.
  """

  use Oban.Worker,
    queue: :meta_send,
    max_attempts: 3,
    unique: [keys: [:whatsapp_message_id], period: 60 * 60 * 24]

  alias Whatsappbot.Conversations.Dispatcher
  alias Whatsappbot.Meta
  alias Whatsappbot.Meta.Sender

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{
      "workspace_id" => workspace_id,
      "phone_number" => phone_number,
      "message_text" => message_text
    } = args

    case Meta.get_connection(workspace_id) do
      nil ->
        Logger.warning("No Meta connection for workspace #{workspace_id}; dropping inbound message")
        :ok

      connection ->
        with {:ok, assistant_message} <-
               Dispatcher.dispatch(workspace_id, phone_number, message_text, :whatsapp),
             {:ok, _id} <-
               Sender.send_reply(
                 connection,
                 phone_number,
                 assistant_message.content,
                 assistant_message.cta
               ) do
          :ok
        else
          {:error, reason} ->
            _ = Meta.mark_error(connection, reason)
            Logger.error("Failed to handle inbound WhatsApp message: #{inspect(reason)}")
            {:error, reason}
        end
    end
  end
end
