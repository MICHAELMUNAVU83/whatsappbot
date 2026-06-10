defmodule WhatsappbotWeb.WorkspacesLive.Section do
  use WhatsappbotWeb, :live_view

  alias Whatsappbot.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign(:page_title, page_title(socket.assigns.live_action))}

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

  defp page_title(:endpoint), do: "Data Endpoint"
  defp page_title(:cta_rules), do: "CTA Rules"
  defp page_title(:playground), do: "Playground"
  defp page_title(:meta), do: "Meta Connection"

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={assigns[:workspace]}
      class="mx-auto max-w-3xl rounded-xl border border-zinc-200 bg-white p-8 shadow-sm"
    >
      <div class="space-y-2">
        <p class="text-sm font-medium text-zinc-500">{@workspace.name}</p>
        <h1 class="text-3xl font-semibold tracking-tight text-zinc-950">{@page_title}</h1>
        <p class="text-sm leading-6 text-zinc-600">
          This section is scaffolded so the dashboard flow is complete. The detailed configuration arrives in the next task group.
        </p>
      </div>

      <div class="mt-8 rounded-xl bg-zinc-50 p-6 text-sm leading-6 text-zinc-600">
        <p>The workspace route and ownership checks are in place.</p>
        <p class="mt-2">Continue from the dashboard once the next setup step is implemented.</p>
      </div>

      <.link
        navigate={~p"/workspaces/#{@workspace.id}"}
        class="mt-6 inline-flex items-center text-sm font-semibold text-zinc-900 hover:text-zinc-700"
      >
        Back to dashboard
      </.link>
    </section>
    """
  end
end
