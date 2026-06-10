defmodule Whatsappbot.Endpoints do
  @moduledoc """
  The Endpoints context.
  """

  import Ecto.Query, warn: false

  alias Whatsappbot.Endpoints.Endpoint
  alias Whatsappbot.Repo

  @default_query "test"
  @pubsub Whatsappbot.PubSub

  def get_endpoint(workspace_id) do
    Repo.get_by(Endpoint, workspace_id: workspace_id)
  end

  def list_endpoints_for_refresh_strategy(strategy) do
    Endpoint
    |> where([endpoint], endpoint.refresh_strategy == ^strategy)
    |> Repo.all()
  end

  def upsert_endpoint(workspace_id, attrs) do
    attrs =
      attrs
      |> normalize_attrs()
      |> Map.put("workspace_id", workspace_id)

    case get_endpoint(workspace_id) do
      nil ->
        %Endpoint{}
        |> Endpoint.changeset(attrs)
        |> Repo.insert()

      endpoint ->
        endpoint
        |> Endpoint.changeset(attrs)
        |> Repo.update()
    end
  end

  def change_endpoint(%Endpoint{} = endpoint, attrs \\ %{}) do
    attrs =
      attrs
      |> normalize_attrs()
      |> put_default_headers_text(endpoint)

    Endpoint.changeset(endpoint, attrs)
  end

  def fetch_live_data(%Endpoint{} = endpoint) do
    with {:ok, response} <- perform_request(endpoint),
         {:ok, data} <- parse_response(response) do
      {:ok, truncate_payload(data)}
    end
  rescue
    error in Req.TransportError ->
      {:error, "Request failed: #{inspect(error.reason)}"}

    error in Jason.DecodeError ->
      {:error, "Response was not valid JSON: #{Exception.message(error)}"}

    error in RuntimeError ->
      {:error, Exception.message(error)}
  end

  def refresh_cached_data(%Endpoint{} = endpoint) do
    with {:ok, data} <- fetch_live_data(endpoint),
         {:ok, updated_endpoint} <-
           endpoint
           |> Endpoint.changeset(%{
             "cached_data" => data,
             "last_fetched_at" => DateTime.utc_now() |> DateTime.truncate(:second)
           })
           |> Repo.update() do
      Phoenix.PubSub.broadcast(
        @pubsub,
        endpoint_topic(updated_endpoint.workspace_id),
        {:endpoint_refreshed, updated_endpoint.workspace_id}
      )

      {:ok, updated_endpoint}
    end
  end

  def subscribe_workspace(workspace_id) do
    Phoenix.PubSub.subscribe(@pubsub, endpoint_topic(workspace_id))
  end

  def endpoint_topic(workspace_id), do: "workspace:#{workspace_id}:endpoint"

  defp perform_request(%Endpoint{method: "GET"} = endpoint) do
    {:ok, Req.get!(request_options(endpoint))}
  end

  defp perform_request(%Endpoint{method: "POST"} = endpoint) do
    with {:ok, body} <- build_post_body(endpoint.body_template) do
      {:ok, Req.post!(request_options(endpoint, json: body))}
    end
  end

  defp request_options(%Endpoint{} = endpoint, extra \\ []) do
    default_options =
      Process.get(:endpoint_req_options) ||
        Application.get_env(:whatsappbot, :endpoint_req_options, [])

    default_options
    |> Keyword.merge(url: endpoint.url, headers: normalize_headers(endpoint.headers))
    |> Keyword.merge(extra)
  end

  defp build_post_body(nil), do: {:ok, %{}}
  defp build_post_body(""), do: {:ok, %{}}

  defp build_post_body(body_template) do
    body_template
    |> String.replace("{{query}}", @default_query)
    |> Jason.decode()
    |> case do
      {:ok, body} -> {:ok, body}
      {:error, error} -> {:error, "Body template must be valid JSON: #{Exception.message(error)}"}
    end
  end

  defp parse_response(%Req.Response{status: status} = response) when status in 200..299 do
    parse_response_body(response.body)
  end

  defp parse_response(%Req.Response{status: status, body: body}) do
    {:error, "HTTP #{status}: #{error_body_message(body)}"}
  end

  defp parse_response_body(body) when is_map(body) or is_list(body), do: {:ok, body}

  defp parse_response_body(body) when is_binary(body) do
    Jason.decode(body)
  end

  defp parse_response_body(_body) do
    {:error, "Response was not valid JSON"}
  end

  defp error_body_message(body) when is_binary(body), do: String.slice(body, 0, 200)
  defp error_body_message(body) when is_map(body) or is_list(body), do: Jason.encode!(body)
  defp error_body_message(_body), do: "request failed"

  defp normalize_headers(nil), do: []

  defp normalize_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp truncate_payload(payload) when is_list(payload) do
    payload
    |> Enum.take(50)
    |> Enum.map(&truncate_payload/1)
  end

  defp truncate_payload(payload) when is_map(payload) do
    Map.new(payload, fn {key, value} -> {key, truncate_payload(value)} end)
  end

  defp truncate_payload(payload), do: payload

  defp put_default_headers_text(attrs, %Endpoint{} = endpoint) do
    case Map.has_key?(attrs, "headers_text") do
      true -> attrs
      false -> Map.put(attrs, "headers_text", Endpoint.format_headers(endpoint.headers))
    end
  end

  defp normalize_attrs(attrs) do
    for {key, value} <- Map.new(attrs), into: %{} do
      {to_string(key), value}
    end
  end
end
