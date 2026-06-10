defmodule WhatsappbotWeb.WorkspacesLive.Index do
  use WhatsappbotWeb, :live_view

  alias Whatsappbot.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Workspaces")
     |> assign(:workspaces, Workspaces.list_workspaces(socket.assigns.current_user.id))}
  end

  defp language_label("en"), do: "English only"
  defp language_label("sw"), do: "Swahili only"
  defp language_label(_), do: "English + Swahili"

  @impl true
  def render(assigns) do
    ~H"""
    <section class="space-y-8">
      <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
        <div class="space-y-2">
          <p class="text-sm font-medium text-zinc-500">Workspace setup</p>
          <h1 class="text-3xl font-semibold tracking-tight text-zinc-950">Your workspaces</h1>
          <p class="max-w-2xl text-sm leading-6 text-zinc-600">
            Each workspace maps one business to one WhatsApp bot, one data source, and one set of AI instructions.
          </p>
        </div>
        <.link
          navigate={~p"/workspaces/new"}
          class="inline-flex items-center justify-center rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
        >
          New workspace
        </.link>
      </div>

      <%= if @workspaces == [] do %>
        <div class="rounded-xl border border-dashed border-zinc-300 bg-white px-8 py-12 text-center">
          <h2 class="text-lg font-semibold text-zinc-900">No workspaces yet</h2>
          <p class="mt-2 text-sm text-zinc-600">
            Create your first workspace to start configuring the chatbot for a business.
          </p>
        </div>
      <% else %>
        <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          <article
            :for={workspace <- @workspaces}
            class="flex h-full flex-col justify-between rounded-xl border border-zinc-200 bg-white p-6 shadow-sm"
          >
            <div class="space-y-4">
              <div class="flex items-start justify-between gap-4">
                <div>
                  <h2 class="text-lg font-semibold text-zinc-950">{workspace.name}</h2>
                  <p class="mt-1 text-sm text-zinc-500">/{workspace.slug}</p>
                </div>
                <span class="rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700">
                  {language_label(workspace.language)}
                </span>
              </div>
              <p class="line-clamp-3 text-sm leading-6 text-zinc-600">
                {workspace.ai_instructions || "No AI instructions added yet."}
              </p>
            </div>

            <div class="mt-6 flex items-center justify-between">
              <p class="text-xs text-zinc-500">
                Updated {Calendar.strftime(workspace.updated_at, "%b %d, %Y")}
              </p>
              <.link
                navigate={~p"/workspaces/#{workspace.id}"}
                class="inline-flex items-center rounded-lg bg-zinc-900 px-3 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
              >
                Open
              </.link>
            </div>
          </article>
        </div>
      <% end %>
    </section>
    """
  end
end
