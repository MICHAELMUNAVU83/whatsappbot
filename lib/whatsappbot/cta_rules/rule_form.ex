defmodule Whatsappbot.CTARules.RuleForm do
  use Ecto.Schema
  import Ecto.Changeset

  alias Whatsappbot.CTARules.CTARule

  @cta_types CTARule.cta_types()
  @button_fields Enum.map(1..3, &String.to_atom("button_#{&1}"))

  @list_title_fields Enum.map(1..10, &String.to_atom("list_item_#{&1}_title"))
  @list_description_fields Enum.map(1..10, &String.to_atom("list_item_#{&1}_description"))
  @list_fields @list_title_fields ++ @list_description_fields

  @base_fields [
    :trigger_description,
    :cta_type,
    :priority,
    :url,
    :phone_number,
    :whatsapp_number,
    :custom_template,
    :catalog_product_id,
    :location_latitude,
    :location_longitude
  ]

  @all_fields @base_fields ++ @button_fields ++ @list_fields

  embedded_schema do
    field :trigger_description, :string
    field :cta_type, :string, default: "website"
    field :priority, :integer
    field :url, :string
    field :phone_number, :string
    field :whatsapp_number, :string
    field :custom_template, :string
    field :catalog_product_id, :string
    field :location_latitude, :float
    field :location_longitude, :float

    for field_name <- @button_fields do
      field field_name, :string
    end

    for field_name <- @list_fields do
      field field_name, :string
    end
  end

  def blank(next_priority) do
    %__MODULE__{
      cta_type: "website",
      priority: next_priority
    }
  end

  def from_rule(%CTARule{} = rule) do
    rule.cta_payload
    |> normalize_payload()
    |> Enum.reduce(
      %__MODULE__{
        trigger_description: rule.trigger_description,
        cta_type: rule.cta_type,
        priority: rule.priority
      },
      fn {key, value}, form ->
        Map.put(form, key, value)
      end
    )
  end

  def changeset(%__MODULE__{} = rule_form, attrs \\ %{}) do
    rule_form
    |> cast(attrs, @all_fields)
    |> validate_required([:trigger_description, :cta_type, :priority])
    |> validate_length(:trigger_description, min: 5, max: 500)
    |> validate_inclusion(:cta_type, @cta_types)
    |> validate_number(:priority, greater_than_or_equal_to: 1)
    |> validate_payload_fields()
  end

  def to_cta_rule_attrs(%__MODULE__{} = rule_form) do
    %{
      "trigger_description" => String.trim(rule_form.trigger_description || ""),
      "cta_type" => rule_form.cta_type,
      "priority" => rule_form.priority,
      "cta_payload" => payload_for(rule_form)
    }
  end

  def cta_type_options do
    [
      {"Website link", "website"},
      {"Phone call", "phone"},
      {"WhatsApp handoff", "whatsapp"},
      {"Reply buttons", "reply_buttons"},
      {"List message", "list_message"},
      {"Location pin", "location"},
      {"Catalog item", "catalog"},
      {"Custom template", "custom"}
    ]
  end

  def button_fields, do: @button_fields

  def list_item_indexes, do: 1..10

  defp validate_payload_fields(%Ecto.Changeset{} = changeset) do
    case get_field(changeset, :cta_type) do
      "website" ->
        changeset
        |> validate_required([:url])
        |> validate_format(:url, ~r/^https?:\/\//, message: "must start with http:// or https://")

      "phone" ->
        validate_required(changeset, [:phone_number])

      "whatsapp" ->
        validate_required(changeset, [:whatsapp_number])

      "reply_buttons" ->
        if Enum.any?(button_values(changeset), &(&1 != "")) do
          changeset
        else
          add_error(changeset, :button_1, "add at least one button label")
        end

      "list_message" ->
        validate_list_items(changeset)

      "location" ->
        changeset
        |> validate_required([:location_latitude, :location_longitude])
        |> validate_number(:location_latitude,
          greater_than_or_equal_to: -90,
          less_than_or_equal_to: 90
        )
        |> validate_number(:location_longitude,
          greater_than_or_equal_to: -180,
          less_than_or_equal_to: 180
        )

      "catalog" ->
        validate_required(changeset, [:catalog_product_id])

      "custom" ->
        validate_required(changeset, [:custom_template])

      _ ->
        changeset
    end
  end

  defp validate_list_items(%Ecto.Changeset{} = changeset) do
    list_items = list_item_values(changeset)

    cond do
      list_items == [] ->
        add_error(changeset, :list_item_1_title, "add at least one list item")

      Enum.any?(list_items, fn item ->
        item.title == "" or item.description == ""
      end) ->
        add_error(
          changeset,
          :list_item_1_title,
          "each list item needs both a title and description"
        )

      true ->
        changeset
    end
  end

  defp payload_for(%__MODULE__{cta_type: "website"} = rule_form) do
    %{"url" => String.trim(rule_form.url || "")}
  end

  defp payload_for(%__MODULE__{cta_type: "phone"} = rule_form) do
    %{"number" => String.trim(rule_form.phone_number || "")}
  end

  defp payload_for(%__MODULE__{cta_type: "whatsapp"} = rule_form) do
    %{"number" => String.trim(rule_form.whatsapp_number || "")}
  end

  defp payload_for(%__MODULE__{cta_type: "reply_buttons"} = rule_form) do
    %{"buttons" => Enum.filter(button_values(rule_form), &(&1 != ""))}
  end

  defp payload_for(%__MODULE__{cta_type: "list_message"} = rule_form) do
    %{
      "items" =>
        Enum.map(list_item_values(rule_form), fn item ->
          %{"title" => item.title, "description" => item.description}
        end)
    }
  end

  defp payload_for(%__MODULE__{cta_type: "location"} = rule_form) do
    %{
      "latitude" => rule_form.location_latitude,
      "longitude" => rule_form.location_longitude
    }
  end

  defp payload_for(%__MODULE__{cta_type: "catalog"} = rule_form) do
    %{"product_id" => String.trim(rule_form.catalog_product_id || "")}
  end

  defp payload_for(%__MODULE__{cta_type: "custom"} = rule_form) do
    %{"template" => String.trim(rule_form.custom_template || "")}
  end

  defp payload_for(_rule_form), do: %{}

  defp button_values(%Ecto.Changeset{} = changeset) do
    Enum.map(@button_fields, fn field_name ->
      changeset
      |> get_field(field_name)
      |> normalize_string()
    end)
  end

  defp button_values(%__MODULE__{} = rule_form) do
    Enum.map(@button_fields, fn field_name ->
      rule_form
      |> Map.get(field_name)
      |> normalize_string()
    end)
  end

  defp list_item_values(%Ecto.Changeset{} = changeset) do
    Enum.map(list_item_indexes(), fn index ->
      %{
        title: normalize_string(get_field(changeset, String.to_atom("list_item_#{index}_title"))),
        description:
          normalize_string(get_field(changeset, String.to_atom("list_item_#{index}_description")))
      }
    end)
    |> Enum.reject(fn item -> item.title == "" and item.description == "" end)
  end

  defp list_item_values(%__MODULE__{} = rule_form) do
    Enum.map(list_item_indexes(), fn index ->
      %{
        title: normalize_string(Map.get(rule_form, String.to_atom("list_item_#{index}_title"))),
        description:
          normalize_string(Map.get(rule_form, String.to_atom("list_item_#{index}_description")))
      }
    end)
    |> Enum.reject(fn item -> item.title == "" and item.description == "" end)
  end

  defp normalize_payload(payload) when not is_map(payload), do: []

  defp normalize_payload(payload) do
    case payload["type"] || payload[:type] do
      _ -> payload_fields(payload)
    end
  end

  defp payload_fields(payload) do
    case payload["buttons"] || payload[:buttons] do
      buttons when is_list(buttons) and buttons != [] ->
        buttons
        |> Enum.take(3)
        |> Enum.with_index(1)
        |> Enum.map(fn {label, index} ->
          {String.to_atom("button_#{index}"), label}
        end)

      _ ->
        payload
        |> payload_by_type()
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    end
  end

  defp payload_by_type(payload) do
    cond do
      payload["url"] || payload[:url] ->
        [url: payload["url"] || payload[:url]]

      payload["number"] || payload[:number] ->
        [
          phone_number: payload["number"] || payload[:number],
          whatsapp_number: payload["number"] || payload[:number]
        ]

      is_list(payload["items"] || payload[:items]) ->
        payload["items"] ||
          payload[:items]
          |> Enum.take(10)
          |> Enum.with_index(1)
          |> Enum.flat_map(fn {item, index} ->
            [
              {String.to_atom("list_item_#{index}_title"), item["title"] || item[:title]},
              {String.to_atom("list_item_#{index}_description"),
               item["description"] || item[:description]}
            ]
          end)

      not is_nil(payload["latitude"] || payload[:latitude]) or
          not is_nil(payload["longitude"] || payload[:longitude]) ->
        [
          location_latitude: payload["latitude"] || payload[:latitude],
          location_longitude: payload["longitude"] || payload[:longitude]
        ]

      payload["product_id"] || payload[:product_id] ->
        [catalog_product_id: payload["product_id"] || payload[:product_id]]

      payload["template"] || payload[:template] ->
        [custom_template: payload["template"] || payload[:template]]

      true ->
        []
    end
  end

  defp normalize_string(nil), do: ""
  defp normalize_string(value), do: value |> to_string() |> String.trim()
end
