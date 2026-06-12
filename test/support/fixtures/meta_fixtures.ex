defmodule Whatsappbot.MetaFixtures do
  @moduledoc """
  Test helpers for creating `Whatsappbot.Meta.Connection` records.
  """

  alias Whatsappbot.Meta

  def valid_connection_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      "phone_number_id" => "123456789012345",
      "waba_id" => "987654321098765",
      "access_token" => "EAAG-test-access-token"
    })
  end

  def connection_fixture(workspace, attrs \\ %{}) do
    {:ok, connection} =
      Meta.upsert_connection(workspace.id, valid_connection_attributes(attrs))

    connection
  end
end
