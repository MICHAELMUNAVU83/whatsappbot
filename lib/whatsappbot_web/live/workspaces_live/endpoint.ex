defmodule WhatsappbotWeb.WorkspacesLive.Endpoint do
  use WhatsappbotWeb, :live_view

  alias Ecto.Changeset
  alias Whatsappbot.Endpoints
  alias Whatsappbot.Endpoints.Endpoint
  alias Whatsappbot.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Data Endpoint")
     |> assign(:workspace, nil)
     |> assign(:endpoint, nil)
     |> assign(:preview_json, nil)
     |> assign(:preview_label, nil)
     |> assign(:test_error, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        endpoint = Endpoints.get_endpoint(workspace.id) || default_endpoint(workspace.id)

        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> assign(:endpoint, endpoint)
         |> assign(:preview_json, preview_json(endpoint.cached_data))
         |> assign(:preview_label, if(endpoint.cached_data, do: "Cached JSON preview", else: nil))
         |> assign(:test_error, nil)
         |> assign_form(Endpoints.change_endpoint(endpoint))}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  @impl true
  def handle_event("validate", %{"endpoint" => endpoint_params}, socket) do
    changeset =
      socket.assigns.endpoint
      |> current_endpoint(socket.assigns.workspace.id)
      |> Endpoints.change_endpoint(endpoint_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("submit", %{"endpoint" => endpoint_params}, socket) do
    case Map.get(endpoint_params, "action", "save") do
      "test" -> test_connection(socket, endpoint_params)
      _ -> save_endpoint(socket, endpoint_params)
    end
  end

  defp save_endpoint(socket, endpoint_params) do
    case Endpoints.upsert_endpoint(
           socket.assigns.workspace.id,
           Map.delete(endpoint_params, "action")
         ) do
      {:ok, endpoint} ->
        {:noreply,
         socket
         |> assign(:endpoint, endpoint)
         |> assign(:preview_json, preview_json(endpoint.cached_data))
         |> assign(:preview_label, if(endpoint.cached_data, do: "Cached JSON preview", else: nil))
         |> assign(:test_error, nil)
         |> assign_form(Endpoints.change_endpoint(endpoint))
         |> put_flash(:info, "Endpoint settings saved successfully.")}

      {:error, %Changeset{} = changeset} ->
        {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  defp test_connection(socket, endpoint_params) do
    changeset =
      socket.assigns.endpoint
      |> current_endpoint(socket.assigns.workspace.id)
      |> Endpoints.change_endpoint(Map.delete(endpoint_params, "action"))
      |> Map.put(:action, :validate)

    case Ecto.Changeset.apply_action(changeset, :validate) do
      {:ok, endpoint} ->
        case Endpoints.fetch_live_data(endpoint) do
          {:ok, data} ->
            {:noreply,
             socket
             |> assign(:test_error, nil)
             |> assign(:preview_json, preview_json(data))
             |> assign(:preview_label, "Connection test preview")
             |> assign_form(changeset)
             |> put_flash(:info, "Connection successful.")}

          {:error, reason} ->
            {:noreply,
             socket
             |> assign(:test_error, reason)
             |> assign_form(changeset)}
        end

      {:error, %Changeset{} = invalid_changeset} ->
        {:noreply, assign_form(socket, Map.put(invalid_changeset, :action, :validate))}
    end
  end

  defp assign_form(socket, %Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp current_endpoint(nil, workspace_id), do: default_endpoint(workspace_id)
  defp current_endpoint(endpoint, _workspace_id), do: endpoint

  defp default_endpoint(workspace_id) do
    %Endpoint{
      workspace_id: workspace_id,
      method: "GET",
      refresh_strategy: "on_demand",
      headers: %{}
    }
  end

  defp preview_json(nil), do: nil
  defp preview_json(data), do: Jason.encode_to_iodata!(data, pretty: true)

  defp last_fetched_label(nil), do: nil

  defp last_fetched_label(%DateTime{} = last_fetched_at) do
    minutes_ago = max(DateTime.diff(DateTime.utc_now(), last_fetched_at, :minute), 0)

    cond do
      minutes_ago < 1 -> "just now"
      minutes_ago == 1 -> "1 minute ago"
      minutes_ago < 60 -> "#{minutes_ago} minutes ago"
      minutes_ago < 1_440 -> "#{div(minutes_ago, 60)} hours ago"
      true -> "#{div(minutes_ago, 1_440)} days ago"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      :if={@workspace}
      class="mx-auto max-w-4xl space-y-6 rounded-xl border border-zinc-200 bg-white p-8 shadow-sm"
    >
      <div class="space-y-2">
        <p class="text-sm font-medium text-zinc-500">{@workspace.name}</p>
        <h1 class="text-3xl font-semibold tracking-tight text-zinc-950">Data Endpoint</h1>
        <p class="max-w-3xl text-sm leading-6 text-zinc-600">
          Connect the JSON endpoint the bot should read from so responses stay current with the business data.
        </p>
      </div>

      <div
        :if={@endpoint.last_fetched_at}
        class="rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-sm text-emerald-800"
      >
        Last fetched: {last_fetched_label(@endpoint.last_fetched_at)}
      </div>

      <div
        :if={@test_error}
        class="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-800"
      >
        {@test_error}
      </div>

      <.simple_form for={@form} phx-change="validate" phx-submit="submit">
        <.input field={@form[:url]} label="URL" required />
        <.input
          field={@form[:method]}
          type="select"
          label="Method"
          options={[{"GET", "GET"}, {"POST", "POST"}]}
        />
        <.input
          field={@form[:headers_text]}
          type="textarea"
          label="Headers"
          placeholder="Authorization: Bearer token\nAccept: application/json"
        />

        <.input
          :if={@form[:method].value == "POST"}
          field={@form[:body_template]}
          type="textarea"
          label="Body template"
          placeholder={"{\"query\": \"{{query}}\"}"}
        />
        <p :if={@form[:method].value == "POST"} class="text-sm text-zinc-500">
          Use <code>{"{{query}}"}</code>
          anywhere in the JSON body where the buyer's query should be inserted.
        </p>

        <.input
          field={@form[:refresh_strategy]}
          type="select"
          label="Refresh strategy"
          options={[
            {"On demand", "on_demand"},
            {"Every 60s", "poll_60s"},
            {"Every 5 min", "poll_300s"}
          ]}
        />

        <:actions>
          <.link
            navigate={~p"/workspaces/#{@workspace.id}"}
            class="text-sm font-semibold text-zinc-600 hover:text-zinc-900"
          >
            Back to dashboard
          </.link>
          <button
            type="submit"
            name="endpoint[action]"
            value="test"
            class="inline-flex items-center justify-center rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm font-semibold text-zinc-900 hover:bg-zinc-50"
          >
            Test connection
          </button>
          <.button name="endpoint[action]" value="save">Save endpoint</.button>
        </:actions>
      </.simple_form>

      <details
        :if={@preview_json}
        open
        class="rounded-xl border border-zinc-200 bg-zinc-950 text-zinc-100"
      >
        <summary class="cursor-pointer px-4 py-3 text-sm font-semibold">
          {@preview_label || "JSON preview"}
        </summary>
        <pre class="overflow-x-auto border-t border-zinc-800 px-4 py-4 text-xs leading-6"><%= @preview_json %></pre>
      </details>
    </section>
    """
  end
end
