defmodule WhatsappbotWeb.WorkspacesLive.Meta do
  use WhatsappbotWeb, :live_view

  alias Ecto.Changeset
  alias Whatsappbot.Meta
  alias Whatsappbot.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Meta Connection")
     |> assign(:workspace, nil)
     |> assign(:connection, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        connection = Meta.get_connection_or_new(workspace.id)

        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign(:connection, connection)
         |> assign_form(Meta.change_connection(connection))}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  @impl true
  def handle_event("validate", %{"connection" => params}, socket) do
    changeset =
      socket.assigns.connection
      |> Meta.change_connection(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"connection" => params}, socket) do
    case Meta.upsert_connection(socket.assigns.workspace.id, params) do
      {:ok, connection} ->
        {:noreply,
         socket
         |> assign(:connection, connection)
         |> assign_form(Meta.change_connection(connection))
         |> put_flash(:info, "Meta credentials saved. Now configure the webhook below.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  defp assign_form(socket, %Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset, as: :connection))
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp persisted?(%{id: id}) when not is_nil(id), do: true
  defp persisted?(_), do: false

  defp webhook_url(socket, slug), do: url(socket, ~p"/webhooks/whatsapp/#{slug}")

  defp status_badge_class("active"), do: "border-[#B7EBCF] bg-[#E8FFF3] text-brand-mid"
  defp status_badge_class("error"), do: "border-[#FFCDD2] bg-danger-bg text-danger"
  defp status_badge_class(_), do: "border-line bg-surface-alt text-ink-muted"

  defp status_label("active"), do: "Active"
  defp status_label("error"), do: "Error"
  defp status_label(_), do: "Pending"

  defp verified_label(nil), do: "Not verified yet"
  defp verified_label(%DateTime{} = at), do: Calendar.strftime(at, "%d %b %Y, %H:%M UTC")

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={@workspace} class="mx-auto max-w-3xl space-y-6">
      <nav class="flex items-center gap-1.5 text-[13px] text-ink-faint">
        <.link navigate={~p"/workspaces"} class="transition hover:text-ink-muted">Workspaces</.link>
        <span>/</span>
        <.link navigate={~p"/workspaces/#{@workspace.id}"} class="transition hover:text-ink-muted">
          {@workspace.name}
        </.link>
        <span>/</span>
        <span class="text-ink-muted">Meta Connection</span>
      </nav>

      <div class="overflow-hidden rounded-2xl border border-line bg-surface shadow-card">
        <div class="space-y-1.5 border-b border-line px-8 py-6">
          <h1 class="text-[22px] font-bold tracking-tight text-ink">Meta Connection</h1>
          <p class="max-w-2xl text-sm leading-6 text-ink-muted">
            Connect this workspace to the WhatsApp Business Platform. Save your Cloud API
            credentials, then point Meta's webhook at the URL below to go live.
          </p>
        </div>

        <div class="space-y-6 px-8 py-6">
          <div class="flex items-center gap-2">
            <span class="text-sm font-medium text-ink-muted">Status</span>
            <span class={[
              "inline-flex items-center rounded-full border px-3 py-0.5 text-xs font-semibold",
              status_badge_class(@connection.status)
            ]}>
              {status_label(@connection.status)}
            </span>
          </div>

          <div
            :if={@connection.last_error}
            role="alert"
            class="flex items-start gap-2 rounded-lg border border-[#FFCDD2] border-l-4 border-l-danger bg-danger-bg px-4 py-3 text-[13px] text-ink-muted"
          >
            <.icon name="hero-exclamation-circle-mini" class="mt-0.5 h-4 w-4 flex-none text-danger" />
            <span>{@connection.last_error}</span>
          </div>

          <.simple_form for={@form} phx-change="validate" phx-submit="save">
            <.input field={@form[:phone_number_id]} label="Phone Number ID" required />
            <.input field={@form[:waba_id]} label="WhatsApp Business Account ID" required />
            <.input
              field={@form[:access_token]}
              type="password"
              label="Access Token"
              required
              autocomplete="off"
            />
            <p class="-mt-3 text-[13px] text-ink-muted">
              The access token is encrypted at rest. Saving new credentials resets the
              connection to <span class="font-medium">pending</span>
              until the webhook is re-verified.
            </p>

            <:actions>
              <.link
                navigate={~p"/workspaces/#{@workspace.id}"}
                class="mr-auto text-sm font-medium text-ink-muted transition hover:text-ink"
              >
                Back to dashboard
              </.link>
              <.button>Save credentials</.button>
            </:actions>
          </.simple_form>
        </div>
      </div>

      <div
        :if={persisted?(@connection)}
        class="overflow-hidden rounded-2xl border border-line bg-surface shadow-card"
      >
        <div class="space-y-1.5 border-b border-line px-8 py-6">
          <h2 class="text-[17px] font-bold tracking-tight text-ink">Webhook setup</h2>
          <p class="text-sm leading-6 text-ink-muted">
            In your Meta app, open WhatsApp → Configuration → Webhooks and paste these values,
            then subscribe to the <span class="font-medium">messages</span> field.
          </p>
        </div>

        <div class="space-y-5 px-8 py-6">
          <.copy_field
            id="webhook-url"
            label="Callback URL"
            value={webhook_url(@socket, @workspace.slug)}
          />
          <.copy_field id="verify-token" label="Verify token" value={@connection.verify_token} />
        </div>
      </div>

      <div
        :if={persisted?(@connection)}
        class="overflow-hidden rounded-2xl border border-line bg-surface shadow-card"
      >
        <div class="space-y-1.5 border-b border-line px-8 py-6">
          <h2 class="text-[17px] font-bold tracking-tight text-ink">Setup checklist</h2>
        </div>
        <div class="space-y-3 px-8 py-6 text-sm">
          <.checklist_item done={true} label="Credentials saved" />
          <.checklist_item
            done={not is_nil(@connection.webhook_verified_at)}
            label={"Webhook verified — #{verified_label(@connection.webhook_verified_at)}"}
          />
          <.checklist_item
            done={@connection.status == "active"}
            label="Connection active and ready to receive messages"
          />
        </div>
      </div>
    </section>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true

  defp copy_field(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-ink">{@label}</label>
      <div class="mt-1.5 flex items-center gap-2">
        <input
          id={@id}
          type="text"
          readonly
          value={@value}
          class="w-full rounded-lg border border-line bg-surface-alt px-3 py-2 font-mono text-[13px] text-ink"
        />
        <button
          id={"copy-#{@id}"}
          type="button"
          phx-hook="ClipboardCopy"
          data-copy={@value}
          class="inline-flex h-9 flex-none items-center gap-1.5 rounded-lg border border-line bg-surface px-3 text-sm font-medium text-ink transition hover:bg-surface-alt"
          title="Copy to clipboard"
        >
          <.icon name="hero-document-duplicate-mini" class="h-4 w-4" /> Copy
        </button>
      </div>
    </div>
    """
  end

  attr :done, :boolean, required: true
  attr :label, :string, required: true

  defp checklist_item(assigns) do
    ~H"""
    <div class="flex items-center gap-2.5">
      <.icon
        :if={@done}
        name="hero-check-circle-mini"
        class="h-5 w-5 flex-none text-brand-mid"
      />
      <.icon
        :if={not @done}
        name="hero-minus-circle-mini"
        class="h-5 w-5 flex-none text-ink-faint"
      />
      <span class={if @done, do: "text-ink", else: "text-ink-muted"}>{@label}</span>
    </div>
    """
  end
end
