defmodule Whatsappbot.Endpoints.Endpoint do
  use Ecto.Schema
  import Ecto.Changeset

  alias Whatsappbot.Workspaces.Workspace

  @methods ~w(GET POST)
  @refresh_strategies ~w(on_demand poll_60s poll_300s)

  schema "endpoints" do
    belongs_to :workspace, Workspace

    field :url, :string
    field :method, :string, default: "GET"
    field :headers, Whatsappbot.Encrypted.Map, source: :headers_encrypted
    field :headers_text, :string, virtual: true
    field :body_template, :string
    field :refresh_strategy, :string, default: "on_demand"
    field :last_fetched_at, :utc_datetime
    field :cached_data, :map

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(endpoint, attrs) do
    endpoint
    |> cast(attrs, [
      :workspace_id,
      :url,
      :method,
      :headers,
      :headers_text,
      :body_template,
      :refresh_strategy,
      :last_fetched_at,
      :cached_data
    ])
    |> parse_headers_text()
    |> put_default_headers()
    |> validate_required([:workspace_id, :url, :method, :refresh_strategy])
    |> validate_length(:url, max: 2000)
    |> validate_length(:body_template, max: 10_000)
    |> validate_format(:url, ~r/^https?:\/\//, message: "must start with http:// or https://")
    |> validate_inclusion(:method, @methods)
    |> validate_inclusion(:refresh_strategy, @refresh_strategies)
    |> foreign_key_constraint(:workspace_id)
    |> unique_constraint(:workspace_id)
  end

  def format_headers(headers) when headers in [%{}, nil], do: ""

  def format_headers(headers) when is_map(headers) do
    headers
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map_join("\n", fn {key, value} -> "#{key}: #{value}" end)
  end

  defp parse_headers_text(%Ecto.Changeset{} = changeset) do
    case get_change(changeset, :headers_text) do
      nil ->
        changeset

      headers_text ->
        case headers_from_text(headers_text) do
          {:ok, headers} -> put_change(changeset, :headers, headers)
          {:error, message} -> add_error(changeset, :headers_text, message)
        end
    end
  end

  defp put_default_headers(%Ecto.Changeset{} = changeset) do
    if get_field(changeset, :headers) in [nil, %{}] do
      put_change(changeset, :headers, %{})
    else
      changeset
    end
  end

  defp headers_from_text(headers_text) do
    headers_text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce_while({:ok, %{}}, fn {line, index}, {:ok, headers} ->
      line = String.trim(line)

      cond do
        line == "" ->
          {:cont, {:ok, headers}}

        String.contains?(line, ":") ->
          [key, value] = String.split(line, ":", parts: 2)
          key = String.trim(key)

          if key == "" do
            {:halt, {:error, "header line #{index} is missing a key"}}
          else
            {:cont, {:ok, Map.put(headers, key, String.trim(value))}}
          end

        true ->
          {:halt, {:error, "header line #{index} must use the format Key: Value"}}
      end
    end)
  end
end
