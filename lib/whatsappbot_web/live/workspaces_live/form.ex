defmodule WhatsappbotWeb.WorkspacesLive.Form do
  use WhatsappbotWeb, :live_view

  alias Ecto.Changeset
  alias Whatsappbot.Workspaces
  alias Whatsappbot.Workspaces.Workspace

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:workspace, nil) |> assign_new_workspace()}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, %{assigns: %{live_action: :edit}} = socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> assign(:page_title, "Edit workspace")
         |> assign(:workspace, workspace)
         |> assign_form(Workspaces.change_workspace(workspace))}

      :error ->
        {:noreply, redirect_to_index(socket)}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, socket |> assign(:page_title, "New workspace") |> assign_new_workspace()}
  end

  @impl true
  def handle_event("validate", %{"workspace" => workspace_params}, socket) do
    changeset =
      socket.assigns.workspace
      |> current_workspace()
      |> Workspaces.change_workspace(workspace_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event(
        "save",
        %{"workspace" => workspace_params},
        %{assigns: %{live_action: :new}} = socket
      ) do
    case Workspaces.create_workspace(workspace_params, socket.assigns.current_user.id) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workspace created successfully.")
         |> push_navigate(to: ~p"/workspaces/#{workspace.id}")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("save", %{"workspace" => workspace_params}, socket) do
    case Workspaces.update_workspace(socket.assigns.workspace, workspace_params) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> put_flash(:info, "Workspace updated successfully.")
         |> push_navigate(to: ~p"/workspaces/#{workspace.id}")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_new_workspace(socket) do
    workspace = %Workspace{language: "both"}
    assign(socket, :workspace, workspace) |> assign_form(Workspaces.change_workspace(workspace))
  end

  defp assign_form(socket, %Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp current_workspace(nil), do: %Workspace{language: "both"}
  defp current_workspace(workspace), do: workspace

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp redirect_to_index(socket) do
    socket
    |> put_flash(:error, "Workspace not found.")
    |> push_navigate(to: ~p"/workspaces")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="mx-auto max-w-3xl rounded-xl border border-zinc-200 bg-white p-8 shadow-sm">
      <div class="space-y-2">
        <p class="text-sm font-medium text-zinc-500">Workspace details</p>
        <h1 class="text-3xl font-semibold tracking-tight text-zinc-950">{@page_title}</h1>
        <p class="text-sm leading-6 text-zinc-600">
          Set the business name, the AI's baseline instructions, and the languages the bot should support.
        </p>
      </div>

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} label="Name" required />
        <.input
          field={@form[:ai_instructions]}
          type="textarea"
          label="AI Instructions"
          placeholder="You are a helpful sales assistant for..."
        />
        <.input
          field={@form[:language]}
          type="select"
          label="Language"
          options={[
            {"English only", "en"},
            {"Swahili only", "sw"},
            {"Both", "both"}
          ]}
        />

        <:actions>
          <.link
            navigate={~p"/workspaces"}
            class="text-sm font-semibold text-zinc-600 hover:text-zinc-900"
          >
            Cancel
          </.link>
          <.button>{if @live_action == :new, do: "Create workspace", else: "Save changes"}</.button>
        </:actions>
      </.simple_form>
    </section>
    """
  end
end
