# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :whatsappbot,
  ecto_repos: [Whatsappbot.Repo],
  generators: [timestamp_type: :utc_datetime]

config :whatsappbot, Oban,
  repo: Whatsappbot.Repo,
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       {"* * * * *", Whatsappbot.Workers.EndpointRefreshWorker,
        args: %{"strategy" => "poll_60s"}, queue: :endpoint_refresh},
       {"*/5 * * * *", Whatsappbot.Workers.EndpointRefreshWorker,
        args: %{"strategy" => "poll_300s"}, queue: :endpoint_refresh}
     ]}
  ],
  queues: [default: 10, endpoint_refresh: 5, meta_send: 10]

# Configures the endpoint
config :whatsappbot, WhatsappbotWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: WhatsappbotWeb.ErrorHTML, json: WhatsappbotWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Whatsappbot.PubSub,
  live_view: [signing_salt: "wLJMZoN2"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :whatsappbot, Whatsappbot.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  whatsappbot: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  whatsappbot: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
