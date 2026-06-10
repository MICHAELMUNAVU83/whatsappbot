defmodule WhatsappbotWeb.PlaygroundLive do
  use WhatsappbotWeb, :live_view

  alias Whatsappbot.AI.ContextBuilder
  alias Whatsappbot.AI.CtaInjector
  alias Whatsappbot.CTARules
  alias Whatsappbot.Conversations
  alias Whatsappbot.Conversations.Dispatcher
  alias Whatsappbot.Conversations.Message
  alias Whatsappbot.Endpoints
  alias Whatsappbot.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Playground")
     |> assign(:workspace, nil)
     |> assign(:endpoint, nil)
     |> assign(:conversation, nil)
     |> assign(:phone_number, nil)
     |> assign(:endpoint_preview_json, nil)
     |> assign(:last_system_prompt, nil)
     |> assign(:session_tokens, 0)
     |> assign(:sidebar_open, true)
     |> assign(:subscribed_workspace_id, nil)
     |> assign(:message_ids, MapSet.new())
     |> assign_message_form("")
     |> stream(:messages, [])}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        phone_number = Conversations.playground_phone_number(workspace.id)
        conversation = Conversations.get_conversation(workspace.id, phone_number, :playground)
        messages = if conversation, do: Conversations.list_messages(conversation.id), else: []
        endpoint = Endpoints.get_endpoint(workspace.id)

        socket =
          socket
          |> maybe_subscribe(workspace.id)
          |> assign(:workspace, workspace)
          |> assign(:endpoint, endpoint)
          |> assign(:conversation, conversation)
          |> assign(:phone_number, phone_number)
          |> assign(
            :endpoint_preview_json,
            preview_json(latest_endpoint_snapshot(messages, endpoint))
          )
          |> assign(:last_system_prompt, rebuild_system_prompt(workspace, messages))
          |> assign(:session_tokens, total_tokens(messages))
          |> assign(:message_ids, message_ids(messages))
          |> stream(:messages, messages, reset: true)

        {:noreply, socket}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  @impl true
  def handle_event("send_message", %{"playground" => %{"message" => message}}, socket) do
    trimmed_message = String.trim(message || "")

    if trimmed_message == "" do
      {:noreply, socket}
    else
      with {:ok, conversation, socket} <- ensure_playground_conversation(socket),
           existing_ids = socket.assigns.message_ids,
           {:ok, prepared} <- Dispatcher.prepare_dispatch(socket.assigns.workspace.id),
           {:ok, _assistant_message} <-
             Dispatcher.dispatch_prepared(
               prepared,
               socket.assigns.phone_number,
               trimmed_message,
               :playground
             ) do
        messages = Conversations.list_messages(conversation.id)

        new_user_messages =
          Enum.filter(messages, fn chat_message ->
            chat_message.role == "user" and not MapSet.member?(existing_ids, chat_message.id)
          end)

        {:noreply,
         socket
         |> assign(:endpoint, Endpoints.get_endpoint(socket.assigns.workspace.id))
         |> assign(:endpoint_preview_json, preview_json(prepared.endpoint_data))
         |> assign(:last_system_prompt, prepared.system_prompt)
         |> assign_message_form("")
         |> stream_new_messages(new_user_messages)}
      else
        {:error, reason} ->
          {:noreply, put_flash(socket, :error, format_error(reason))}
      end
    end
  end

  def handle_event("clear_chat", _params, socket) do
    if socket.assigns.conversation do
      {:ok, _conversation} = Conversations.delete_conversation(socket.assigns.conversation)
      Conversations.broadcast_playground_cleared(socket.assigns.workspace.id)
    end

    {:noreply,
     socket
     |> assign(:conversation, nil)
     |> assign(:message_ids, MapSet.new())
     |> assign(:session_tokens, 0)
     |> assign(:last_system_prompt, nil)
     |> assign(
       :endpoint_preview_json,
       preview_json(current_endpoint_snapshot(socket.assigns.endpoint))
     )
     |> assign_message_form("")
     |> stream(:messages, [], reset: true)}
  end

  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, update(socket, :sidebar_open, &(!&1))}
  end

  def handle_event("refresh_endpoint_data", _params, socket) do
    case socket.assigns.endpoint do
      nil ->
        {:noreply,
         put_flash(socket, :error, "Add an endpoint first so the playground has data to fetch.")}

      endpoint ->
        case Endpoints.refresh_cached_data(endpoint) do
          {:ok, refreshed_endpoint} ->
            {:noreply,
             socket
             |> assign(:endpoint, refreshed_endpoint)
             |> assign(:endpoint_preview_json, preview_json(refreshed_endpoint.cached_data))
             |> put_flash(:info, "Endpoint data refreshed.")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, format_error(reason))}
        end
    end
  end

  @impl true
  def handle_info({:new_message, %Message{} = message}, socket) do
    if MapSet.member?(socket.assigns.message_ids, message.id) do
      {:noreply, socket}
    else
      {:noreply,
       socket
       |> update(:session_tokens, &(&1 + (message.tokens_used || 0)))
       |> stream_new_messages([message])}
    end
  end

  def handle_info({:conversation_cleared, workspace_id}, socket) do
    if socket.assigns.workspace && socket.assigns.workspace.id == workspace_id do
      {:noreply,
       socket
       |> assign(:conversation, nil)
       |> assign(:message_ids, MapSet.new())
       |> assign(:session_tokens, 0)
       |> assign(:last_system_prompt, nil)
       |> assign(
         :endpoint_preview_json,
         preview_json(current_endpoint_snapshot(socket.assigns.endpoint))
       )
       |> stream(:messages, [], reset: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:endpoint_refreshed, workspace_id}, socket) do
    if socket.assigns.workspace && socket.assigns.workspace.id == workspace_id do
      refreshed_endpoint = Endpoints.get_endpoint(workspace_id)

      {:noreply,
       socket
       |> assign(:endpoint, refreshed_endpoint)
       |> assign(
         :endpoint_preview_json,
         preview_json(current_endpoint_snapshot(refreshed_endpoint))
       )}
    else
      {:noreply, socket}
    end
  end

  attr :message, :map, required: true

  defp message_bubble(assigns) do
    ~H"""
    <div class={[
      "flex",
      @message.role == "user" && "justify-end",
      @message.role != "user" && "justify-start"
    ]}>
      <div class="max-w-[85%] space-y-2 md:max-w-[75%]">
        <div class={[
          "rounded-2xl px-4 py-3 shadow-[0_1px_2px_rgba(17,27,33,0.12)]",
          @message.role == "user" && "rounded-br-md bg-[#DCF8C6] text-[#111B21]",
          @message.role != "user" && "rounded-bl-md bg-white text-[#111B21]"
        ]}>
          <p class="whitespace-pre-wrap break-words leading-6">{@message.content}</p>
          <.cta_block :if={@message.role == "assistant" && @message.cta} cta={@message.cta} />
          <div class="mt-2 flex items-center justify-end gap-2 text-[11px] text-[#667781]">
            <button
              :if={@message.role == "assistant"}
              id={"copy-reply-#{@message.id}"}
              type="button"
              phx-hook="ClipboardCopy"
              data-copy={@message.content}
              class="inline-flex items-center rounded-full p-1 text-[#54656f] transition hover:bg-[#F0F2F5] hover:text-[#111B21]"
              title="Copy last reply"
            >
              <.icon name="hero-document-duplicate-mini" class="h-4 w-4" />
            </button>
            <span>{message_time(@message.inserted_at)}</span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :cta, :map, required: true

  defp cta_block(assigns) do
    assigns =
      assigns
      |> assign(:type, cta_type(assigns.cta))
      |> assign(:payload, cta_payload(assigns.cta))

    ~H"""
    <div class="mt-3 space-y-2 border-t border-[#E9EDEF] pt-3">
      <a
        :if={@type == "website"}
        href={payload_value(@payload, "url")}
        target="_blank"
        rel="noreferrer"
        class="flex items-center justify-between rounded-xl bg-[#F0F8FF] px-3 py-2 text-sm font-medium text-[#0A66C2] transition hover:bg-[#E6F1FB]"
      >
        <span class="inline-flex items-center gap-2">
          <.icon name="hero-link-mini" class="h-4 w-4" /> Open link
        </span>
        <span class="truncate text-xs">{payload_value(@payload, "url")}</span>
      </a>

      <a
        :if={@type == "phone"}
        href={"tel:#{payload_value(@payload, "number")}"}
        class="inline-flex items-center gap-2 rounded-xl bg-[#25D366] px-3 py-2 text-sm font-semibold text-white transition hover:bg-[#1faa54]"
      >
        <.icon name="hero-phone-mini" class="h-4 w-4" /> Call {payload_value(@payload, "number")}
      </a>

      <a
        :if={@type == "whatsapp"}
        href={"https://wa.me/#{digits_only(payload_value(@payload, "number"))}"}
        target="_blank"
        rel="noreferrer"
        class="inline-flex items-center gap-2 rounded-xl bg-[#25D366] px-3 py-2 text-sm font-semibold text-white transition hover:bg-[#1faa54]"
      >
        <.icon name="hero-chat-bubble-left-right-mini" class="h-4 w-4" /> Message on WhatsApp
      </a>

      <div :if={@type == "reply_buttons"} class="flex flex-wrap gap-2">
        <button
          :for={button <- payload_buttons(@payload)}
          type="button"
          class="rounded-full border border-[#D1D7DB] bg-white px-3 py-1.5 text-xs font-medium text-[#0A66C2] shadow-sm transition hover:border-[#0A66C2]"
        >
          {button}
        </button>
      </div>

      <details
        :if={@type == "list_message"}
        class="overflow-hidden rounded-xl border border-[#D1D7DB] bg-[#F7F8FA]"
      >
        <summary class="cursor-pointer px-3 py-2 text-sm font-semibold text-[#111B21]">
          Browse options
        </summary>
        <div class="space-y-2 border-t border-[#D1D7DB] px-3 py-3">
          <div
            :for={item <- payload_items(@payload)}
            class="rounded-lg bg-white px-3 py-2 shadow-[0_1px_1px_rgba(17,27,33,0.08)]"
          >
            <p class="text-sm font-semibold text-[#111B21]">{payload_value(item, "title")}</p>
            <p class="mt-1 text-xs text-[#667781]">{payload_value(item, "description")}</p>
          </div>
        </div>
      </details>

      <div
        :if={@type == "location"}
        class="rounded-xl border border-[#D1D7DB] bg-[#F7F8FA] px-3 py-2 text-sm text-[#111B21]"
      >
        <div class="flex items-center gap-2 font-semibold">
          <.icon name="hero-map-pin-mini" class="h-4 w-4 text-[#128C7E]" /> Location pin
        </div>
        <p class="mt-1 text-xs text-[#667781]">
          {payload_value(@payload, "latitude")}, {payload_value(@payload, "longitude")}
        </p>
      </div>

      <p
        :if={@type == "custom"}
        class="rounded-xl bg-[#F7F8FA] px-3 py-2 text-sm italic text-[#54656f]"
      >
        {payload_value(@payload, "template")}
      </p>

      <p :if={@type == "catalog"} class="rounded-xl bg-[#F7F8FA] px-3 py-2 text-sm text-[#111B21]">
        Catalog item: <span class="font-semibold">{payload_value(@payload, "product_id")}</span>
      </p>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@workspace}
      class="space-y-4 text-[14px]"
      style="font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;"
    >
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 class="text-2xl font-semibold tracking-tight text-zinc-950">Playground</h1>
          <p class="mt-1 text-sm text-zinc-600">
            Test live responses for <span class="font-semibold text-zinc-900">{@workspace.name}</span>
            before going live on WhatsApp.
          </p>
        </div>
        <div class="flex items-center gap-2">
          <button
            type="button"
            phx-click="toggle_sidebar"
            class="inline-flex items-center gap-2 rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm font-medium text-zinc-800 transition hover:bg-zinc-50"
          >
            <.icon name="hero-bars-3-bottom-left-mini" class="h-4 w-4" /> Sidebar
          </button>
          <.link
            navigate={~p"/workspaces/#{@workspace.id}"}
            class="inline-flex items-center rounded-lg border border-zinc-300 bg-white px-3 py-2 text-sm font-medium text-zinc-800 transition hover:bg-zinc-50"
          >
            Back to dashboard
          </.link>
        </div>
      </div>

      <div class="grid gap-4 xl:grid-cols-[minmax(0,1fr)_20rem]">
        <div class="overflow-hidden rounded-[28px] border border-[#D1D7DB] bg-[#E7F0E4] shadow-[0_18px_50px_rgba(17,27,33,0.15)]">
          <div class="border-b border-[#D1D7DB] bg-[#F0F2F5] px-5 py-4">
            <div class="flex flex-wrap items-center justify-between gap-3">
              <div>
                <div class="flex items-center gap-2">
                  <h2 class="text-lg font-semibold text-[#111B21]">{@workspace.name}</h2>
                  <span class="h-2.5 w-2.5 rounded-full bg-[#25D366]"></span>
                </div>
                <p class="mt-1 text-sm text-[#54656F]">
                  Connected to: {endpoint_label(@endpoint)}
                </p>
              </div>
              <button
                type="button"
                phx-click="clear_chat"
                class="inline-flex items-center gap-2 rounded-full border border-[#D1D7DB] bg-white px-3 py-1.5 text-sm font-medium text-[#54656F] transition hover:border-[#111B21] hover:text-[#111B21]"
              >
                <.icon name="hero-trash-mini" class="h-4 w-4" /> Clear chat
              </button>
            </div>
          </div>

          <div
            class="h-[34rem] overflow-y-auto px-4 py-5"
            style="background-color: #ECE5DD; background-image: radial-gradient(rgba(17, 27, 33, 0.035) 1px, transparent 1px); background-size: 18px 18px;"
          >
            <div id="playground-messages" phx-update="stream" class="space-y-3">
              <div
                :if={MapSet.size(@message_ids) == 0}
                id="playground-empty"
                class="mx-auto max-w-md rounded-2xl bg-white/75 px-5 py-4 text-center text-sm text-[#54656F] shadow-sm backdrop-blur"
              >
                Send a message to simulate a buyer conversation. Responses here follow the same data and CTA setup that the real bot will use.
              </div>

              <div :for={{dom_id, message} <- @streams.messages} id={dom_id}>
                <.message_bubble message={message} />
              </div>
            </div>
          </div>

          <div class="border-t border-[#D1D7DB] bg-[#F0F2F5] px-4 py-4">
            <.form
              for={@message_form}
              as={:playground}
              phx-submit="send_message"
              class="flex items-end gap-3"
            >
              <div class="flex-1">
                <textarea
                  name={@message_form[:message].name}
                  id={@message_form[:message].id}
                  rows="2"
                  placeholder="Type a message..."
                  class="w-full resize-none rounded-2xl border border-[#D1D7DB] bg-white px-4 py-3 text-[14px] text-[#111B21] shadow-inner outline-none transition focus:border-[#25D366] focus:ring-2 focus:ring-[#25D366]/20"
                ><%= @message_form[:message].value %></textarea>
              </div>
              <button
                type="submit"
                class="inline-flex h-12 items-center justify-center rounded-full bg-[#128C7E] px-5 text-sm font-semibold text-white transition hover:bg-[#0f7267]"
              >
                Send
              </button>
            </.form>
          </div>
        </div>

        <aside class={["space-y-4", !@sidebar_open && "hidden xl:block"]}>
          <div class="rounded-2xl border border-zinc-200 bg-white p-5 shadow-sm">
            <div class="flex items-center justify-between gap-3">
              <div>
                <h3 class="text-sm font-semibold text-zinc-950">Session insights</h3>
                <p class="mt-1 text-xs text-zinc-500">
                  Prompt, endpoint data, and token usage for this playground session.
                </p>
              </div>
              <button
                type="button"
                phx-click="refresh_endpoint_data"
                class="inline-flex items-center gap-1 rounded-lg border border-zinc-300 bg-white px-2.5 py-2 text-xs font-medium text-zinc-700 transition hover:bg-zinc-50"
              >
                <.icon name="hero-arrow-path-mini" class="h-4 w-4" /> Refresh
              </button>
            </div>

            <div class="mt-4 rounded-xl bg-zinc-50 px-4 py-3">
              <p class="text-xs uppercase tracking-[0.2em] text-zinc-500">Tokens</p>
              <p class="mt-2 text-2xl font-semibold text-zinc-950">{@session_tokens}</p>
            </div>
          </div>

          <details open class="overflow-hidden rounded-2xl border border-zinc-200 bg-white shadow-sm">
            <summary class="cursor-pointer px-5 py-4 text-sm font-semibold text-zinc-950">
              Endpoint data preview
            </summary>
            <pre class="max-h-80 overflow-auto border-t border-zinc-200 bg-zinc-950 px-4 py-4 text-xs leading-6 text-zinc-100"><%= @endpoint_preview_json || "{}" %></pre>
          </details>

          <details open class="overflow-hidden rounded-2xl border border-zinc-200 bg-white shadow-sm">
            <summary class="cursor-pointer px-5 py-4 text-sm font-semibold text-zinc-950">
              Last system prompt
            </summary>
            <pre class="max-h-80 overflow-auto border-t border-zinc-200 bg-zinc-950 px-4 py-4 text-xs leading-6 text-zinc-100"><%= @last_system_prompt || "No prompt sent yet." %></pre>
          </details>
        </aside>
      </div>
    </section>
    """
  end

  defp maybe_subscribe(socket, workspace_id) do
    if connected?(socket) and socket.assigns.subscribed_workspace_id != workspace_id do
      Conversations.subscribe_playground(workspace_id)
      Endpoints.subscribe_workspace(workspace_id)
      assign(socket, :subscribed_workspace_id, workspace_id)
    else
      socket
    end
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp ensure_playground_conversation(socket) do
    case socket.assigns.conversation do
      nil ->
        case Conversations.get_or_create_conversation(
               socket.assigns.workspace.id,
               socket.assigns.phone_number,
               :playground
             ) do
          {:ok, conversation} -> {:ok, conversation, assign(socket, :conversation, conversation)}
          {:error, reason} -> {:error, reason}
        end

      conversation ->
        {:ok, conversation, socket}
    end
  end

  defp stream_new_messages(socket, messages) do
    Enum.reduce(messages, socket, fn message, acc ->
      acc
      |> update(:message_ids, &MapSet.put(&1, message.id))
      |> stream_insert(:messages, message)
    end)
  end

  defp assign_message_form(socket, value) do
    assign(socket, :message_form, to_form(%{"message" => value}, as: :playground))
  end

  defp preview_json(nil), do: nil
  defp preview_json(data), do: Jason.encode!(data, pretty: true)

  defp message_ids(messages) do
    messages
    |> Enum.map(& &1.id)
    |> MapSet.new()
  end

  defp total_tokens(messages) do
    Enum.reduce(messages, 0, fn message, acc -> acc + (message.tokens_used || 0) end)
  end

  defp latest_endpoint_snapshot(messages, endpoint) do
    messages
    |> Enum.reverse()
    |> Enum.find_value(& &1.endpoint_snapshot)
    |> case do
      nil -> current_endpoint_snapshot(endpoint)
      snapshot -> snapshot
    end
  end

  defp current_endpoint_snapshot(nil), do: nil
  defp current_endpoint_snapshot(endpoint), do: endpoint.cached_data

  defp rebuild_system_prompt(workspace, messages) do
    case Enum.find(
           Enum.reverse(messages),
           &(&1.role == "user" and not is_nil(&1.endpoint_snapshot))
         ) do
      nil ->
        nil

      message ->
        workspace
        |> ContextBuilder.build_system_prompt(message.endpoint_snapshot)
        |> CtaInjector.inject_cta_rules(CTARules.list_cta_rules(workspace.id))
    end
  end

  defp endpoint_label(nil), do: "not configured"
  defp endpoint_label(%{url: nil}), do: "not configured"

  defp endpoint_label(%{url: url}) do
    URI.parse(url).host || url
  end

  defp cta_type(cta), do: payload_value(cta, "type")
  defp cta_payload(cta), do: payload_value(cta, "payload") || %{}

  defp payload_buttons(payload) do
    case payload_value(payload, "buttons") do
      buttons when is_list(buttons) -> buttons
      _ -> []
    end
  end

  defp payload_items(payload) do
    case payload_value(payload, "items") do
      items when is_list(items) -> items
      _ -> []
    end
  end

  defp payload_value(map, key) when is_map(map) do
    Map.get(map, key) ||
      case safe_existing_atom(key) do
        nil -> nil
        atom_key -> Map.get(map, atom_key)
      end
  rescue
    ArgumentError -> Map.get(map, key)
  end

  defp payload_value(_value, _key), do: nil

  defp safe_existing_atom(key) when is_binary(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> nil
  end

  defp digits_only(nil), do: ""
  defp digits_only(value), do: Regex.replace(~r/[^\d]/, to_string(value), "")

  defp message_time(nil), do: ""
  defp message_time(datetime), do: Calendar.strftime(datetime, "%H:%M")

  defp format_error(%Ecto.Changeset{}),
    do: "The chat could not be saved. Please review your setup and try again."

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
