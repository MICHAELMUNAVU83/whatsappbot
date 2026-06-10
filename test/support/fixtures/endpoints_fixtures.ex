defmodule Whatsappbot.EndpointsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  endpoint entities via the `Whatsappbot.Endpoints` context.
  """

  def valid_endpoint_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      url: "https://catalog.example.com/products",
      method: "GET",
      headers: %{},
      body_template: nil,
      refresh_strategy: "on_demand"
    })
  end

  def endpoint_fixture(workspace, attrs \\ %{}) do
    attrs = valid_endpoint_attributes(attrs)

    {:ok, endpoint} =
      Whatsappbot.Endpoints.upsert_endpoint(workspace.id, attrs)

    endpoint
  end
end
