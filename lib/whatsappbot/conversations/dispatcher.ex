defmodule Whatsappbot.Conversations.Dispatcher do
  @moduledoc """
  Orchestrates inbound conversation handling for playground and channel integrations.
  """

  alias Whatsappbot.AI.ClaudeClient
  alias Whatsappbot.AI.ContextBuilder
  alias Whatsappbot.AI.CtaInjector
  alias Whatsappbot.Conversations
  alias Whatsappbot.Endpoints
  alias Whatsappbot.Repo
  alias Whatsappbot.Workspaces.Workspace

  def dispatch(workspace_id, phone_number, user_message, source \\ :playground) do
    with {:ok, prepared} <- prepare_dispatch(workspace_id) do
      dispatch_prepared(prepared, phone_number, user_message, source)
    end
  end

  def prepare_dispatch(workspace_id) do
    workspace = Repo.get!(Workspace, workspace_id)
    endpoint = Endpoints.get_endpoint(workspace.id)
    cta_rules = cta_rules_for(workspace.id)

    with {:ok, endpoint_data} <- endpoint_data_for_dispatch(endpoint) do
      {:ok,
       %{
         workspace: workspace,
         endpoint: Endpoints.get_endpoint(workspace.id) || endpoint,
         cta_rules: cta_rules,
         endpoint_data: endpoint_data,
         system_prompt:
           workspace
           |> ContextBuilder.build_system_prompt(endpoint_data)
           |> CtaInjector.inject_cta_rules(cta_rules)
       }}
    end
  end

  def dispatch_prepared(
        %{workspace: workspace, endpoint_data: endpoint_data, system_prompt: system_prompt},
        phone_number,
        user_message,
        source \\ :playground
      ) do
    with {:ok, conversation} <-
           Conversations.get_or_create_conversation(workspace.id, phone_number, source),
         {:ok, _user_message} <-
           Conversations.add_message(conversation, :user, user_message,
             endpoint_snapshot: endpoint_data
           ),
         messages <- Conversations.build_messages(conversation.id, user_message),
         {:ok, reply} <- ClaudeClient.chat(messages, system_prompt),
         {:ok, assistant_message} <-
           Conversations.add_message(conversation, :assistant, reply.reply,
             cta: reply.cta,
             tokens_used: reply.tokens
           ) do
      Conversations.broadcast_new_message(assistant_message)
      maybe_broadcast_to_playground(workspace.id, source, assistant_message)
      {:ok, assistant_message}
    end
  end

  defp endpoint_data_for_dispatch(nil), do: {:ok, nil}

  defp endpoint_data_for_dispatch(%{refresh_strategy: "on_demand"} = endpoint) do
    Endpoints.fetch_live_data(endpoint)
  end

  defp endpoint_data_for_dispatch(%{cached_data: cached_data}) when not is_nil(cached_data) do
    {:ok, cached_data}
  end

  defp endpoint_data_for_dispatch(endpoint) do
    case Endpoints.refresh_cached_data(endpoint) do
      {:ok, refreshed_endpoint} -> {:ok, refreshed_endpoint.cached_data}
      {:error, reason} -> {:error, reason}
    end
  end

  defp cta_rules_for(workspace_id) do
    module = Whatsappbot.CTARules

    if Code.ensure_loaded?(module) and function_exported?(module, :list_cta_rules, 1) do
      apply(module, :list_cta_rules, [workspace_id])
    else
      []
    end
  end

  defp maybe_broadcast_to_playground(workspace_id, source, assistant_message) do
    if normalize_source(source) == "playground" do
      Conversations.broadcast_playground_message(workspace_id, assistant_message)
    end
  end

  defp normalize_source(source) when is_atom(source), do: Atom.to_string(source)
  defp normalize_source(source) when is_binary(source), do: source
end
