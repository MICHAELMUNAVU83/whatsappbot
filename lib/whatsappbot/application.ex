defmodule Whatsappbot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WhatsappbotWeb.Telemetry,
      Whatsappbot.Repo,
      {DNSCluster, query: Application.get_env(:whatsappbot, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Whatsappbot.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Whatsappbot.Finch},
      # Start a worker by calling: Whatsappbot.Worker.start_link(arg)
      # {Whatsappbot.Worker, arg},
      # Start to serve requests, typically the last entry
      WhatsappbotWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Whatsappbot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WhatsappbotWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
