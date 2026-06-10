defmodule WhatsappbotWeb.WorkspacesLive.CTARules do
  use WhatsappbotWeb, :live_view

  alias Ecto.Changeset
  alias Whatsappbot.CTARules
  alias Whatsappbot.CTARules.CTARule
  alias Whatsappbot.CTARules.RuleForm
  alias Whatsappbot.Workspaces

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "CTA Rules")
     |> assign(:workspace, nil)
     |> assign(:cta_rules, [])
     |> assign(:sort_by, "priority")
     |> assign(:sort_dir, "asc")
     |> assign(:show_rule_form, false)
     |> assign(:editing_rule, nil)
     |> assign_rule_form(RuleForm.changeset(RuleForm.blank(1)), RuleForm.blank(1))}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    case fetch_workspace(id, socket) do
      {:ok, workspace} ->
        {:noreply,
         socket
         |> assign(:workspace, workspace)
         |> refresh_rules()}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Workspace not found.")
         |> push_navigate(to: ~p"/workspaces")}
    end
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    sort_dir =
      if socket.assigns.sort_by == field and socket.assigns.sort_dir == "asc",
        do: "desc",
        else: "asc"

    {:noreply,
     socket
     |> assign(:sort_by, field)
     |> assign(:sort_dir, sort_dir)
     |> refresh_rules(false)}
  end

  def handle_event("open_add_rule", _params, socket) do
    next_priority = CTARules.next_priority(socket.assigns.workspace.id)
    rule_form = RuleForm.blank(next_priority)

    {:noreply,
     socket
     |> assign(:show_rule_form, true)
     |> assign(:editing_rule, nil)
     |> assign_rule_form(RuleForm.changeset(rule_form), rule_form)}
  end

  def handle_event("edit_rule", %{"id" => id}, socket) do
    rule = CTARules.get_cta_rule!(id, socket.assigns.workspace.id)
    rule_form = RuleForm.from_rule(rule)

    {:noreply,
     socket
     |> assign(:show_rule_form, true)
     |> assign(:editing_rule, rule)
     |> assign_rule_form(RuleForm.changeset(rule_form), rule_form)}
  end

  def handle_event("close_rule_form", _params, socket) do
    {:noreply, close_rule_form(socket)}
  end

  def handle_event("validate_rule", %{"cta_rule_form" => rule_params}, socket) do
    changeset =
      socket.assigns.rule_form_data
      |> RuleForm.changeset(rule_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_rule_form(socket, changeset, Ecto.Changeset.apply_changes(changeset))}
  end

  def handle_event("save_rule", %{"cta_rule_form" => rule_params}, socket) do
    changeset =
      socket.assigns.rule_form_data
      |> RuleForm.changeset(rule_params)
      |> Map.put(:action, :validate)

    if changeset.valid? do
      persist_rule(socket, Ecto.Changeset.apply_changes(changeset))
    else
      {:noreply, assign_rule_form(socket, changeset, Ecto.Changeset.apply_changes(changeset))}
    end
  end

  def handle_event("delete_rule", %{"id" => id}, socket) do
    rule = CTARules.get_cta_rule!(id, socket.assigns.workspace.id)

    {:ok, _rule} = CTARules.delete_cta_rule(rule)

    {:noreply,
     socket
     |> put_flash(:info, "CTA rule deleted.")
     |> refresh_rules()}
  end

  defp persist_rule(socket, %RuleForm{} = rule_form) do
    attrs = RuleForm.to_cta_rule_attrs(rule_form)

    case socket.assigns.editing_rule do
      %CTARule{} = rule ->
        case CTARules.update_cta_rule(rule, attrs) do
          {:ok, _updated_rule} ->
            {:noreply,
             socket
             |> put_flash(:info, "CTA rule updated.")
             |> close_rule_form()
             |> refresh_rules()}

          {:error, %Changeset{} = changeset} ->
            {:noreply, assign_rule_errors(socket, changeset, rule_form)}
        end

      nil ->
        case CTARules.create_cta_rule(socket.assigns.workspace.id, attrs) do
          {:ok, _rule} ->
            {:noreply,
             socket
             |> put_flash(:info, "CTA rule created.")
             |> close_rule_form()
             |> refresh_rules()}

          {:error, %Changeset{} = changeset} ->
            {:noreply, assign_rule_errors(socket, changeset, rule_form)}
        end
    end
  end

  defp assign_rule_errors(socket, %Changeset{}, %RuleForm{} = rule_form) do
    form_changeset =
      rule_form
      |> RuleForm.changeset()
      |> Map.put(:action, :validate)

    socket
    |> put_flash(:error, "Could not save CTA rule. Please review the form and try again.")
    |> assign_rule_form(form_changeset, rule_form)
  end

  defp refresh_rules(socket, reset_form \\ true) do
    sorted_rules =
      socket.assigns.workspace.id
      |> CTARules.list_cta_rules()
      |> sort_rules(socket.assigns.sort_by, socket.assigns.sort_dir)

    socket =
      assign(socket, :cta_rules, sorted_rules)

    if reset_form do
      next_priority = CTARules.next_priority(socket.assigns.workspace.id)
      rule_form = RuleForm.blank(next_priority)

      socket
      |> assign(:show_rule_form, false)
      |> assign(:editing_rule, nil)
      |> assign_rule_form(RuleForm.changeset(rule_form), rule_form)
    else
      socket
    end
  end

  defp close_rule_form(socket) do
    next_priority =
      if socket.assigns.workspace do
        CTARules.next_priority(socket.assigns.workspace.id)
      else
        1
      end

    rule_form = RuleForm.blank(next_priority)

    socket
    |> assign(:show_rule_form, false)
    |> assign(:editing_rule, nil)
    |> assign_rule_form(RuleForm.changeset(rule_form), rule_form)
  end

  defp sort_rules(rules, sort_by, sort_dir) do
    sorter =
      case sort_by do
        "trigger_description" -> &{String.downcase(&1.trigger_description || ""), &1.id}
        "cta_type" -> &{String.downcase(&1.cta_type || ""), &1.id}
        _ -> &{&1.priority || 0, &1.id}
      end

    sorted = Enum.sort_by(rules, sorter)

    if sort_dir == "desc", do: Enum.reverse(sorted), else: sorted
  end

  defp fetch_workspace(id, socket) do
    {:ok, Workspaces.get_workspace!(id, socket.assigns.current_user.id)}
  rescue
    Ecto.NoResultsError -> :error
  end

  defp assign_rule_form(socket, %Changeset{} = changeset, %RuleForm{} = rule_form) do
    socket
    |> assign(:rule_form_data, rule_form)
    |> assign(:form, to_form(changeset, as: :cta_rule_form))
  end

  defp sort_indicator(assigns) do
    cond do
      assigns.sort_by != assigns.field -> ""
      assigns.sort_dir == "asc" -> "↑"
      true -> "↓"
    end
  end

  defp payload_summary(%CTARule{cta_type: "website", cta_payload: %{"url" => url}}), do: url

  defp payload_summary(%CTARule{cta_type: "phone", cta_payload: %{"number" => number}}),
    do: number

  defp payload_summary(%CTARule{cta_type: "whatsapp", cta_payload: %{"number" => number}}),
    do: number

  defp payload_summary(%CTARule{cta_type: "reply_buttons", cta_payload: %{"buttons" => buttons}})
       when is_list(buttons) do
    Enum.join(buttons, ", ")
  end

  defp payload_summary(%CTARule{cta_type: "list_message", cta_payload: %{"items" => items}})
       when is_list(items) do
    "#{length(items)} items"
  end

  defp payload_summary(%CTARule{
         cta_type: "location",
         cta_payload: %{"latitude" => latitude, "longitude" => longitude}
       }) do
    "#{latitude}, #{longitude}"
  end

  defp payload_summary(%CTARule{cta_type: "catalog", cta_payload: %{"product_id" => product_id}}),
    do: product_id

  defp payload_summary(%CTARule{cta_type: "custom", cta_payload: %{"template" => template}}),
    do: template

  defp payload_summary(%CTARule{}), do: "Payload configured"

  defp humanize_cta_type("reply_buttons"), do: "Reply buttons"
  defp humanize_cta_type("list_message"), do: "List message"
  defp humanize_cta_type("website"), do: "Website"
  defp humanize_cta_type("whatsapp"), do: "WhatsApp"
  defp humanize_cta_type("phone"), do: "Phone"
  defp humanize_cta_type("location"), do: "Location"
  defp humanize_cta_type("catalog"), do: "Catalog"
  defp humanize_cta_type("custom"), do: "Custom"
  defp humanize_cta_type(type), do: Phoenix.Naming.humanize(type)

  @impl true
  def render(assigns) do
    ~H"""
    <section :if={@workspace} class="space-y-8">
      <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div class="space-y-3">
          <p class="text-sm font-medium text-zinc-500">{@workspace.name}</p>
          <h1 class="text-3xl font-semibold tracking-tight text-zinc-950">CTA Rules</h1>
          <p class="max-w-3xl text-sm leading-6 text-zinc-600">
            Tell the assistant which call-to-action to attach when a buyer asks for the next step.
          </p>
        </div>

        <div class="flex items-center gap-3">
          <.link
            navigate={~p"/workspaces/#{@workspace.id}"}
            class="inline-flex items-center justify-center rounded-lg border border-zinc-300 bg-white px-4 py-2 text-sm font-semibold text-zinc-900 hover:bg-zinc-50"
          >
            Back to dashboard
          </.link>
          <button
            type="button"
            phx-click="open_add_rule"
            class="inline-flex items-center justify-center rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
          >
            Add rule
          </button>
        </div>
      </div>

      <div class="rounded-2xl border border-zinc-200 bg-white shadow-sm">
        <%= if @cta_rules == [] do %>
          <div class="space-y-3 px-6 py-10 text-center">
            <h2 class="text-lg font-semibold text-zinc-950">No CTA rules yet</h2>
            <p class="mx-auto max-w-2xl text-sm leading-6 text-zinc-600">
              Start with the buyer moments you care about most, like asking for price, location, or how to place an order.
            </p>
            <button
              type="button"
              phx-click="open_add_rule"
              class="inline-flex items-center justify-center rounded-lg bg-zinc-900 px-4 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
            >
              Add your first rule
            </button>
          </div>
        <% else %>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-zinc-200">
              <thead class="bg-zinc-50">
                <tr class="text-left text-xs font-semibold uppercase tracking-wide text-zinc-500">
                  <th class="px-6 py-4">
                    <button
                      type="button"
                      phx-click="sort"
                      phx-value-field="priority"
                      class="inline-flex items-center gap-2"
                    >
                      Priority
                      <span>
                        {sort_indicator(%{sort_by: @sort_by, sort_dir: @sort_dir, field: "priority"})}
                      </span>
                    </button>
                  </th>
                  <th class="px-6 py-4">
                    <button
                      type="button"
                      phx-click="sort"
                      phx-value-field="trigger_description"
                      class="inline-flex items-center gap-2"
                    >
                      Trigger
                      <span>
                        {sort_indicator(%{
                          sort_by: @sort_by,
                          sort_dir: @sort_dir,
                          field: "trigger_description"
                        })}
                      </span>
                    </button>
                  </th>
                  <th class="px-6 py-4">
                    <button
                      type="button"
                      phx-click="sort"
                      phx-value-field="cta_type"
                      class="inline-flex items-center gap-2"
                    >
                      CTA Type
                      <span>
                        {sort_indicator(%{sort_by: @sort_by, sort_dir: @sort_dir, field: "cta_type"})}
                      </span>
                    </button>
                  </th>
                  <th class="px-6 py-4">Payload</th>
                  <th class="px-6 py-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-zinc-100">
                <tr :for={rule <- @cta_rules} id={"cta-rule-#{rule.id}"} class="align-top">
                  <td class="px-6 py-4 text-sm font-semibold text-zinc-900">{rule.priority}</td>
                  <td class="px-6 py-4 text-sm leading-6 text-zinc-700">
                    {rule.trigger_description}
                  </td>
                  <td class="px-6 py-4">
                    <span class="rounded-full bg-zinc-100 px-3 py-1 text-xs font-semibold text-zinc-700">
                      {humanize_cta_type(rule.cta_type)}
                    </span>
                  </td>
                  <td class="px-6 py-4 text-sm text-zinc-600">{payload_summary(rule)}</td>
                  <td class="px-6 py-4">
                    <div class="flex justify-end gap-3">
                      <button
                        type="button"
                        phx-click="edit_rule"
                        phx-value-id={rule.id}
                        class="text-sm font-semibold text-zinc-700 hover:text-zinc-950"
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        phx-click="delete_rule"
                        phx-value-id={rule.id}
                        data-confirm="Delete this CTA rule?"
                        class="text-sm font-semibold text-rose-600 hover:text-rose-700"
                      >
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>

      <%= if @show_rule_form do %>
        <div class="fixed inset-0 z-40">
          <button
            type="button"
            phx-click="close_rule_form"
            class="absolute inset-0 bg-zinc-950/40"
            aria-label="Close CTA rule form"
          />
          <aside class="absolute right-0 top-0 h-full w-full max-w-2xl overflow-y-auto border-l border-zinc-200 bg-white p-8 shadow-2xl">
            <div class="flex items-start justify-between gap-4">
              <div class="space-y-2">
                <p class="text-sm font-medium text-zinc-500">{@workspace.name}</p>
                <h2 class="text-2xl font-semibold tracking-tight text-zinc-950">
                  {if @editing_rule, do: "Edit CTA rule", else: "Add CTA rule"}
                </h2>
                <p class="text-sm leading-6 text-zinc-600">
                  Focus each rule on one buyer intent so the assistant can choose the first matching action confidently.
                </p>
              </div>
              <button
                type="button"
                phx-click="close_rule_form"
                class="rounded-lg p-2 text-zinc-500 hover:bg-zinc-100 hover:text-zinc-900"
                aria-label="Close"
              >
                <.icon name="hero-x-mark-solid" class="h-5 w-5" />
              </button>
            </div>

            <.simple_form for={@form} phx-change="validate_rule" phx-submit="save_rule">
              <.input
                field={@form[:trigger_description]}
                type="textarea"
                label="Trigger description"
                placeholder="When the buyer asks about price or wants to buy"
                required
              />

              <.input
                field={@form[:cta_type]}
                type="select"
                label="CTA type"
                options={RuleForm.cta_type_options()}
              />

              <.input field={@form[:priority]} type="number" label="Priority" min="1" required />

              <%= case @form[:cta_type].value do %>
                <% "website" -> %>
                  <.input
                    field={@form[:url]}
                    label="Website URL"
                    placeholder="https://example.com/checkout"
                  />
                <% "phone" -> %>
                  <.input
                    field={@form[:phone_number]}
                    label="Phone number"
                    placeholder="+254700000000"
                  />
                <% "whatsapp" -> %>
                  <.input
                    field={@form[:whatsapp_number]}
                    label="WhatsApp number"
                    placeholder="+254700000000"
                  />
                <% "reply_buttons" -> %>
                  <div class="space-y-4 rounded-xl border border-zinc-200 bg-zinc-50 p-4">
                    <div class="space-y-1">
                      <h3 class="text-sm font-semibold text-zinc-900">Reply button labels</h3>
                      <p class="text-sm text-zinc-600">Add up to three button labels.</p>
                    </div>
                    <.input
                      :for={field_name <- RuleForm.button_fields()}
                      field={@form[field_name]}
                      label={Phoenix.Naming.humanize(Atom.to_string(field_name))}
                    />
                  </div>
                <% "list_message" -> %>
                  <div class="space-y-4 rounded-xl border border-zinc-200 bg-zinc-50 p-4">
                    <div class="space-y-1">
                      <h3 class="text-sm font-semibold text-zinc-900">List items</h3>
                      <p class="text-sm text-zinc-600">
                        Only rows with both a title and description will be saved.
                      </p>
                    </div>
                    <div
                      :for={index <- RuleForm.list_item_indexes()}
                      class="grid gap-3 rounded-xl border border-zinc-200 bg-white p-4 sm:grid-cols-2"
                    >
                      <.input
                        field={@form[String.to_atom("list_item_#{index}_title")]}
                        label={"Item #{index} title"}
                      />
                      <.input
                        field={@form[String.to_atom("list_item_#{index}_description")]}
                        label={"Item #{index} description"}
                      />
                    </div>
                  </div>
                <% "location" -> %>
                  <div class="grid gap-4 sm:grid-cols-2">
                    <.input
                      field={@form[:location_latitude]}
                      type="number"
                      step="any"
                      label="Latitude"
                    />
                    <.input
                      field={@form[:location_longitude]}
                      type="number"
                      step="any"
                      label="Longitude"
                    />
                  </div>
                <% "catalog" -> %>
                  <.input
                    field={@form[:catalog_product_id]}
                    label="Product ID"
                    placeholder="sku_12345"
                  />
                <% "custom" -> %>
                  <.input
                    field={@form[:custom_template]}
                    type="textarea"
                    label="Custom template"
                    placeholder="Share the showroom map and invite the buyer to pick a visit time."
                  />
                <% _ -> %>
              <% end %>

              <:actions>
                <button
                  type="button"
                  phx-click="close_rule_form"
                  class="text-sm font-semibold text-zinc-600 hover:text-zinc-900"
                >
                  Cancel
                </button>
                <.button>{if @editing_rule, do: "Save changes", else: "Create rule"}</.button>
              </:actions>
            </.simple_form>
          </aside>
        </div>
      <% end %>
    </section>
    """
  end
end
