# Seeds one CTA rule per CTA type onto the WA_WORKSPACE_SLUG workspace (default
# "sokopawa") so you can test each interactive message type end to end.
#
#   mix run priv/repo/seeds_cta_rules.exs
#
# Idempotent: a rule is only created if no rule with the same trigger already
# exists on the workspace.

import Ecto.Query

alias Whatsappbot.CTARules
alias Whatsappbot.Repo
alias Whatsappbot.Workspaces.Workspace

slug = System.get_env("WA_WORKSPACE_SLUG") || "sokopawa"

workspace =
  Repo.one(from w in Workspace, where: w.slug == ^slug) ||
    raise "No workspace with slug #{inspect(slug)}."

rules = [
  %{
    cta_type: "website",
    trigger_description: "When the buyer asks to browse the online store or shop the full catalog",
    cta_payload: %{"url" => "https://shop.example.com"}
  },
  %{
    cta_type: "phone",
    trigger_description: "When the buyer wants to call the shop or asks for a phone number",
    cta_payload: %{"number" => "+254700000001"}
  },
  %{
    cta_type: "whatsapp",
    trigger_description: "When the buyer wants to chat with a human sales agent",
    cta_payload: %{"number" => "+254700000002"}
  },
  %{
    cta_type: "reply_buttons",
    trigger_description: "When the buyer asks which payment methods or payment options are accepted",
    cta_payload: %{
      "title" => "Payment options",
      "body" => "How would you like to pay?",
      "buttons" => ["M-Pesa", "Card", "Cash on delivery"]
    }
  },
  %{
    cta_type: "list_message",
    trigger_description: "When the buyer asks what product categories or departments are available",
    cta_payload: %{
      "title" => "Browse categories",
      "body" => "Pick a category to explore",
      "items" => [
        %{"title" => "Apparel", "description" => "Hoodies and clothing"},
        %{"title" => "Electronics", "description" => "Earbuds, speakers and gadgets"},
        %{"title" => "Home", "description" => "Mugs, candles and lamps"}
      ]
    }
  },
  %{
    cta_type: "location",
    trigger_description: "When the buyer asks where the shop is located or wants directions",
    cta_payload: %{
      "title" => "Our shop",
      "address" => "Nairobi CBD, Kenya",
      "latitude" => -1.2921,
      "longitude" => 36.8219
    }
  },
  %{
    cta_type: "catalog",
    trigger_description: "When the buyer specifically asks to see the catalog card for the Classic Hoodie",
    cta_payload: %{"product_id" => "1"}
  },
  %{
    cta_type: "custom",
    trigger_description: "When the buyer asks about delivery time, shipping or how long orders take",
    cta_payload: %{
      "template" =>
        "🚚 Standard delivery is 2–4 business days countrywide. Express options at checkout."
    }
  }
]

existing_triggers =
  workspace.id
  |> CTARules.list_cta_rules()
  |> MapSet.new(& &1.trigger_description)

Enum.reduce(rules, CTARules.next_priority(workspace.id), fn rule, priority ->
  if MapSet.member?(existing_triggers, rule.trigger_description) do
    IO.puts("• skip (exists): #{rule.cta_type}")
    priority
  else
    {:ok, _} =
      CTARules.create_cta_rule(workspace.id, Map.put(rule, :priority, priority))

    IO.puts("✓ created #{rule.cta_type} (priority #{priority})")
    priority + 1
  end
end)

IO.puts("\nDone. Seeded CTA rules for workspace #{slug} (id #{workspace.id}).")
