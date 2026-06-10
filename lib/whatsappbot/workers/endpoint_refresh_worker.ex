defmodule Whatsappbot.Workers.EndpointRefreshWorker do
  use Oban.Worker, queue: :endpoint_refresh, max_attempts: 3

  alias Whatsappbot.Endpoints

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"strategy" => strategy}}) do
    strategy
    |> Endpoints.list_endpoints_for_refresh_strategy()
    |> Enum.each(fn endpoint ->
      _ = Endpoints.refresh_cached_data(endpoint)
    end)

    :ok
  end
end
