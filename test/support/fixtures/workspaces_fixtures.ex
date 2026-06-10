defmodule Whatsappbot.WorkspacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Whatsappbot.Workspaces` context.
  """

  def valid_workspace_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Sokopawa Market",
      ai_instructions: "You are a helpful sales assistant for Sokopawa.",
      language: "both"
    })
  end

  def workspace_fixture(user, attrs \\ %{}) do
    {:ok, workspace} =
      attrs
      |> valid_workspace_attributes()
      |> Whatsappbot.Workspaces.create_workspace(user.id)

    workspace
  end
end
