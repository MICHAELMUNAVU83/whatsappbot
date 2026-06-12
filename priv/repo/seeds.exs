# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# This seed creates a ready-to-demo workspace with:
#   * a confirmed owner user
#   * a workspace with practical AI instructions
#   * a sample product endpoint + cached catalog data
#   * CTA rules for the common WhatsApp interaction types
#   * optional Meta credentials from `.env` / shell env
#
# It is intentionally idempotent, so you can re-run it safely while iterating.

import Ecto.Query

alias Sokochat.Accounts
alias Sokochat.Accounts.User
alias Sokochat.CTARules
alias Sokochat.Endpoints
alias Sokochat.Meta
alias Sokochat.Repo
alias Sokochat.Workspaces
alias Sokochat.Workspaces.Workspace

strip_wrapping_quotes = fn
  "\"" <> rest -> String.trim_trailing(rest, "\"")
  "'" <> rest -> String.trim_trailing(rest, "'")
  value -> value
end

dotenv =
  case File.read(Path.expand("../../.env", __DIR__)) do
    {:ok, contents} ->
      contents
      |> String.split("\n")
      |> Enum.reduce(%{}, fn line, acc ->
        trimmed = String.trim(line)

        with false <- trimmed == "" or String.starts_with?(trimmed, "#"),
             [key, value] <- String.split(String.trim_leading(trimmed, "export "), "=", parts: 2) do
          value =
            value
            |> String.trim()
            |> strip_wrapping_quotes.()

          Map.put(acc, String.trim(key), value)
        else
          _ -> acc
        end
      end)

    {:error, _} ->
      %{}
  end

env_value = fn key, default ->
  case System.get_env(key) || Map.get(dotenv, key) || default do
    value when is_binary(value) ->
      trimmed = String.trim(value)
      if trimmed == "", do: nil, else: trimmed

    value ->
      value
  end
end

seed_email = env_value.("SEED_USER_EMAIL", "demo@sokochat.local")
seed_password = env_value.("SEED_USER_PASSWORD", "password123")
workspace_name = env_value.("SEED_WORKSPACE_NAME", "Sokopawa Market")
workspace_slug = env_value.("WA_WORKSPACE_SLUG", "sokopawa")

seed_user =
  case Accounts.get_user_by_email(seed_email) do
    %User{} = user ->
      user

    nil ->
      {:ok, user} =
        Accounts.register_user(%{
          name: "Sokopawa Demo",
          email: seed_email,
          password: seed_password
        })

      user
  end

seed_user =
  if seed_user.confirmed_at do
    seed_user
  else
    seed_user
    |> User.confirm_changeset()
    |> Repo.update!()
  end

workspace =
  case Repo.one(
         from w in Workspace,
           where: w.account_id == ^seed_user.id and w.slug == ^workspace_slug,
           limit: 1
       ) do
    %Workspace{} = workspace ->
      workspace

    nil ->
      {:ok, workspace} =
        Workspaces.create_workspace(
          %{
            name: workspace_name,
            language: "both",
            ai_instructions: """
            You are Sokopawa's WhatsApp sales assistant for a Nairobi-based shop.
            Answer in a warm, concise way. Keep replies short enough for WhatsApp.
            Prefer specific product suggestions with price, stock status, delivery timing,
            and the best next action. If the buyer sounds ready to act, prefer a CTA over a
            long explanation.
            """
          },
          seed_user.id
        )

      workspace
  end

workspace =
  workspace
  |> Workspace.changeset(%{
    name: workspace_name,
    slug: workspace_slug,
    language: "both",
    ai_instructions: """
    You are Sokopawa's WhatsApp sales assistant for a Nairobi-based shop.
    Answer in a warm, concise way. Keep replies short enough for WhatsApp.
    Prefer specific product suggestions with price, stock status, delivery timing,
    and the best next action. If the buyer sounds ready to act, prefer a CTA over a
    long explanation.
    """
  })
  |> Repo.update!()

catalog_data = %{
  "shop" => %{
    "name" => "Sokopawa Market",
    "city" => "Nairobi",
    "hours" => "Mon-Sat 8:00-20:00",
    "delivery" => "Same-day in Nairobi for orders placed before 4pm"
  },
  "categories" => [
    %{"title" => "Fresh Produce", "description" => "Everyday fruits and vegetables"},
    %{"title" => "Pantry", "description" => "Rice, flour, oil, and staples"},
    %{"title" => "Home", "description" => "Household basics and cleaning"}
  ],
  "items" => [
    %{
      "id" => "tomatoes-premium",
      "name" => "Premium Tomatoes",
      "title" => "Premium Tomatoes",
      "description" => "Fresh red tomatoes sold per kilo.",
      "price" => 120,
      "currency" => "KES",
      "category" => "Fresh Produce",
      "stock_status" => "in_stock",
      "image_url" =>
        "https://images.unsplash.com/photo-1546094096-0df4bcaaa337?auto=format&fit=crop&w=1200&q=80",
      "url" => "https://shop.example.com/products/tomatoes-premium",
      "phone" => "+254700000001",
      "whatsapp_number" => "+254700000002"
    },
    %{
      "id" => "red-onions",
      "name" => "Red Onions",
      "title" => "Red Onions",
      "description" => "Clean, medium-sized red onions sold per kilo.",
      "price" => 95,
      "currency" => "KES",
      "category" => "Fresh Produce",
      "stock_status" => "in_stock",
      "image_url" =>
        "https://images.unsplash.com/photo-1508747703725-719777637510?auto=format&fit=crop&w=1200&q=80",
      "url" => "https://shop.example.com/products/red-onions",
      "phone" => "+254700000001",
      "whatsapp_number" => "+254700000002"
    },
    %{
      "id" => "classic-hoodie",
      "name" => "Classic Hoodie",
      "title" => "Classic Hoodie",
      "description" => "Soft unisex hoodie available in black, grey, and navy.",
      "price" => 3500,
      "currency" => "KES",
      "category" => "Home",
      "stock_status" => "limited_stock",
      "image_url" =>
        "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=80",
      "url" => "https://shop.example.com/products/classic-hoodie",
      "phone" => "+254700000001",
      "whatsapp_number" => "+254700000002"
    }
  ]
}

{:ok, endpoint} =
  Endpoints.upsert_endpoint(workspace.id, %{
    "url" => "https://example.com/sokopawa/catalog.json",
    "method" => "GET",
    "headers" => %{"Accept" => "application/json"},
    "refresh_strategy" => "poll_300s",
    "cached_data" => catalog_data,
    "last_fetched_at" => DateTime.utc_now() |> DateTime.truncate(:second)
  })

rules = [
  %{
    cta_type: "website",
    trigger_description:
      "When the buyer asks to browse the full catalog, website, or shop online",
    cta_payload: %{
      "title" => "Open catalog",
      "url" => "https://shop.example.com",
      "image_url" =>
        "https://images.unsplash.com/photo-1488459716781-31db52582fe9?auto=format&fit=crop&w=1200&q=80"
    }
  },
  %{
    cta_type: "phone",
    trigger_description: "When the buyer asks to call the shop or speak to the team by phone",
    cta_payload: %{"number" => "+254700000001"}
  },
  %{
    cta_type: "whatsapp",
    trigger_description: "When the buyer asks to chat with a human agent on WhatsApp",
    cta_payload: %{"number" => "+254700000002"}
  },
  %{
    cta_type: "reply_buttons",
    trigger_description: "When the buyer asks about payment methods or how they can pay",
    cta_payload: %{
      "title" => "Payment options",
      "body" => "How would you like to pay?",
      "buttons" => ["M-Pesa", "Card", "Cash on delivery"]
    }
  },
  %{
    cta_type: "list_message",
    trigger_description:
      "When the buyer asks what categories, departments, or collections are available",
    cta_payload: %{
      "title" => "Browse categories",
      "body" => "Choose a category to explore",
      "items" => [
        %{"title" => "Fresh Produce", "description" => "Tomatoes, onions, greens, and more"},
        %{"title" => "Pantry", "description" => "Staples for everyday cooking"},
        %{"title" => "Home", "description" => "Useful extras for the house"}
      ]
    }
  },
  %{
    cta_type: "location",
    trigger_description: "When the buyer asks where the shop is located or wants directions",
    cta_payload: %{
      "title" => "Sokopawa Market",
      "address" => "Moi Avenue, Nairobi CBD, Kenya",
      "latitude" => -1.2833,
      "longitude" => 36.8167
    }
  },
  %{
    cta_type: "catalog",
    trigger_description:
      "When the buyer specifically asks to see the Classic Hoodie product card",
    cta_payload: %{"product_id" => "classic-hoodie"}
  },
  %{
    cta_type: "custom",
    trigger_description:
      "When the buyer asks about delivery timing, shipping speed, or how long orders take",
    cta_payload: %{
      "template" =>
        "Standard Nairobi delivery is same-day for orders before 4pm. Upcountry delivery is usually 1-3 business days."
    }
  }
]

existing_rules =
  workspace.id
  |> CTARules.list_cta_rules()
  |> Map.new(&{&1.trigger_description, &1})

Enum.with_index(rules, 1)
|> Enum.each(fn {rule, priority} ->
  attrs = Map.put(rule, :priority, priority)

  case Map.get(existing_rules, rule.trigger_description) do
    nil ->
      {:ok, _} = CTARules.create_cta_rule(workspace.id, attrs)

    existing_rule ->
      {:ok, _} = CTARules.update_cta_rule(existing_rule, attrs)
  end
end)

wa_values = %{
  "phone_number_id" => env_value.("WA_PHONE_NUMBER_ID", nil),
  "waba_id" => env_value.("WA_WABA_ID", nil),
  "access_token" => env_value.("WA_ACCESS_TOKEN", nil)
}

present_wa_keys =
  wa_values
  |> Enum.filter(fn {_key, value} -> is_binary(value) and value != "" end)
  |> Enum.map(&elem(&1, 0))

connection_result =
  cond do
    map_size(Map.reject(wa_values, fn {_key, value} -> is_nil(value) end)) == 3 ->
      {:ok, connection} = Meta.upsert_connection(workspace.id, wa_values)
      {:seeded_meta, connection}

    present_wa_keys == [] ->
      :missing_meta_env

    true ->
      missing =
        ["phone_number_id", "waba_id", "access_token"]
        |> Enum.reject(&(&1 in present_wa_keys))
        |> Enum.join(", ")

      {:partial_meta_env, missing}
  end

dashboard_path = "/workspaces/#{workspace.id}"
meta_path = "/workspaces/#{workspace.id}/meta"

IO.puts("""

✅ Sokochat demo data ready

  Owner email:     #{seed_user.email}
  Owner password:  #{seed_password}
  Workspace:       #{workspace.name} (id: #{workspace.id})
  Workspace slug:  #{workspace.slug}
  Dashboard:       #{dashboard_path}
  Meta page:       #{meta_path}
  Endpoint URL:    #{endpoint.url}
  CTA rules:       #{length(rules)} seeded
  Catalog items:   #{length(catalog_data["items"])}
""")

case connection_result do
  {:seeded_meta, connection} ->
    IO.puts("""
      Meta credentials: saved to workspace in pending mode
      Phone number ID:  #{connection.phone_number_id}
      Verify token:     #{connection.verify_token}

    Next on Meta:
      1. Open #{meta_path}
      2. Copy the Callback URL and Verify token into Meta → WhatsApp → Configuration
      3. Subscribe to the messages field and verify the webhook
    """)

  :missing_meta_env ->
    IO.puts("""
      Meta credentials: not seeded

    To finish Meta setup, add these to `.env` and re-run seeds:
      WA_PHONE_NUMBER_ID
      WA_WABA_ID
      WA_ACCESS_TOKEN
    """)

  {:partial_meta_env, missing} ->
    IO.puts("""
      Meta credentials: partially provided, not saved
      Missing values:   #{missing}

    Add the missing WA_* values to `.env` and re-run seeds to prefill the Meta page.
    """)
end
