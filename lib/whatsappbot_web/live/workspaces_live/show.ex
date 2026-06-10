defmodule WhatsappbotWeb.WorkspacesLive.Show do
  use WhatsappbotWeb, :live_view

  alias Whatsappbot.CTARules
  alias Whatsappbot.Endpoints
  alias Whatsappbot.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Workspace dashboard")}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        endpoint = Endpoints.get_endpoint(workspace.id)
        cta_rules = CTARules.list_cta_rules(workspace.id)

        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign(:endpoint_configured, configured?(endpoint, :endpoint))
         |> assign(:cta_rules_configured, configured?(cta_rules, :cta_rules))}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp configured?(%{url: url}, :endpoint), do: not is_nil_or_blank?(url)
  defp configured?(cta_rules, :cta_rules) when is_list(cta_rules), do: cta_rules != []
  defp configured?(workspace, :playground), do: not is_nil_or_blank?(workspace.ai_instructions)
  defp configured?(_resource, _section), do: false

  defp status_classes(true), do: "bg-emerald-50 text-emerald-700"
  defp status_classes(false), do: "bg-zinc-100 text-zinc-500"

  defp status_label(true), do: "Configured"
  defp status_label(false), do: "Not configured"

  defp is_nil_or_blank?(value), do: is_nil(value) or String.trim(value) == ""

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={assigns[:workspace]} class="space-y-8">
      <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div class="space-y-3">
          <div class="flex flex-wrap items-center gap-3">
            <h1 class="text-3xl font-semibold tracking-tight text-zinc-950">{@workspace.name}</h1>
            <span class="rounded-full bg-zinc-100 px-3 py-1 text-xs font-semibold text-zinc-600">
              /{@workspace.slug}
            </span>
          </div>
          <p class="max-w-3xl text-sm leading-6 text-zinc-600">
            Configure the data source, CTA rules, playground behavior, and Meta connection for this bot.
          </p>
        </div>
        <.link
          navigate={~p"/workspaces/#{@workspace.id}/edit"}
          class="inline-flex items-center justify-center rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm font-semibold text-zinc-900 hover:bg-zinc-50"
        >
          Edit workspace
        </.link>
      </div>

      <div class="grid gap-4 md:grid-cols-2">
        <article class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-semibold text-zinc-950">Data Endpoint</h2>
            <span class={[
              "rounded-full px-2.5 py-1 text-xs font-semibold",
              status_classes(@endpoint_configured)
            ]}>
              {status_label(@endpoint_configured)}
            </span>
          </div>
          <p class="mt-3 text-sm leading-6 text-zinc-600">
            Connect the JSON feed or API the bot should read from in real time.
          </p>
          <.link
            navigate={~p"/workspaces/#{@workspace.id}/endpoint"}
            class="mt-6 inline-flex items-center text-sm font-semibold text-zinc-900 hover:text-zinc-700"
          >
            Open Data Endpoint
          </.link>
        </article>

        <article class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-semibold text-zinc-950">CTA Rules</h2>
            <span class={[
              "rounded-full px-2.5 py-1 text-xs font-semibold",
              status_classes(@cta_rules_configured)
            ]}>
              {status_label(@cta_rules_configured)}
            </span>
          </div>
          <p class="mt-3 text-sm leading-6 text-zinc-600">
            Define which button, link, or list message should appear when a buyer is ready to act.
          </p>
          <.link
            navigate={~p"/workspaces/#{@workspace.id}/cta_rules"}
            class="mt-6 inline-flex items-center text-sm font-semibold text-zinc-900 hover:text-zinc-700"
          >
            Open CTA Rules
          </.link>
        </article>

        <article class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-semibold text-zinc-950">Playground</h2>
            <span class={[
              "rounded-full px-2.5 py-1 text-xs font-semibold",
              status_classes(configured?(@workspace, :playground))
            ]}>
              {status_label(configured?(@workspace, :playground))}
            </span>
          </div>
          <p class="mt-3 text-sm leading-6 text-zinc-600">
            Test responses in a browser chat before connecting the workspace to a real WhatsApp number.
          </p>
          <.link
            navigate={~p"/workspaces/#{@workspace.id}/playground"}
            class="mt-6 inline-flex items-center text-sm font-semibold text-zinc-900 hover:text-zinc-700"
          >
            Open Playground
          </.link>
        </article>

        <article class="rounded-xl border border-zinc-200 bg-white p-6 shadow-sm">
          <div class="flex items-center justify-between gap-4">
            <h2 class="text-lg font-semibold text-zinc-950">Meta Connection</h2>
            <span class={["rounded-full px-2.5 py-1 text-xs font-semibold", status_classes(false)]}>
              {status_label(false)}
            </span>
          </div>
          <p class="mt-3 text-sm leading-6 text-zinc-600">
            Connect Meta credentials and webhook settings when you are ready to go live.
          </p>
          <.link
            navigate={~p"/workspaces/#{@workspace.id}/meta"}
            class="mt-6 inline-flex items-center text-sm font-semibold text-zinc-900 hover:text-zinc-700"
          >
            Open Meta Connection
          </.link>
        </article>
      </div>
    </section>
    """
  end
end
