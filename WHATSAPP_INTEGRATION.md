# WhatsApp Integration Step-by-Step

This guide is for **this codebase specifically**. It explains what you need to do to connect a workspace to the **WhatsApp Business Platform (Cloud API)** and what is **already present** vs what is **still missing** in the app.

## Current status in this repo

The core bot engine is already here:

- Workspaces
- Data endpoint setup
- CTA rules
- Playground chat UI
- AI reply generation through `Dispatcher.dispatch/4`

The actual **Meta / WhatsApp live integration is not finished yet**.

As of now:

- `/workspaces/:id/meta` exists, but it is still a placeholder screen in [lib/whatsappbot_web/live/workspaces_live/section.ex](/Users/michaelmunavu/Documents/projects/whatsappbot/lib/whatsappbot_web/live/workspaces_live/section.ex:36)
- webhook routes are **not** in [lib/whatsappbot_web/router.ex](/Users/michaelmunavu/Documents/projects/whatsappbot/lib/whatsappbot_web/router.ex:1)
- there is no Meta connection schema yet
- there is no webhook controller yet
- there is no worker yet for inbound WhatsApp messages
- there is no Meta sender module yet

So the work is really in two parts:

1. Finish the app-side Meta integration.
2. Connect Meta's dashboard to your deployed app.

---

## Step 1. Finish the bot setup inside the app first

Before touching Meta, make sure one workspace is already working well in the browser.

Checklist:

- create the workspace
- configure its data endpoint
- configure CTA rules
- test the full flow in the Playground

Why this matters:

- the live WhatsApp channel should reuse the same bot behavior the Playground already validated
- your dispatcher already does that in [lib/whatsappbot/conversations/dispatcher.ex](/Users/michaelmunavu/Documents/projects/whatsappbot/lib/whatsappbot/conversations/dispatcher.ex:10)

Do not start webhook work until the Playground replies look correct.

---

## Step 2. Prepare your Meta assets

In Meta's developer tools, create or confirm the following:

- a Meta app
- the WhatsApp product enabled on that app
- a WhatsApp Business Account
- a phone number connected to that WABA
- an access token you can use from your server

You will need these values:

- `phone_number_id`
- `waba_id`
- `access_token`

Recommended approach:

- start with Meta's test number first
- switch to your real business number only after webhook verification and end-to-end messaging work

Also make sure your business/domain setup can support:

- a public HTTPS URL
- a stable production hostname

---

## Step 3. Add a Meta connection model to the app

Create a table to store one WhatsApp connection per workspace.

Use the task plan in [tasks.md](/Users/michaelmunavu/Documents/projects/whatsappbot/tasks.md:432) as the base. The intended schema is:

```bash
mix phx.gen.schema Meta.Connection meta_connections \
  workspace_id:references:workspaces \
  phone_number_id:string \
  waba_id:string \
  access_token_encrypted:binary \
  verify_token:string \
  webhook_verified_at:utc_datetime \
  status:string

mix ecto.migrate
```

Implementation notes:

- auto-generate `verify_token` as a UUID
- keep one connection record per workspace
- use status values like `pending`, `active`, and `error`

Files to add:

- `lib/whatsappbot/meta/connection.ex`
- migration under `priv/repo/migrations/...`

---

## Step 4. Encrypt the WhatsApp access token

Do not store the Meta access token as plain text.

This repo already has encryption support through:

- [lib/whatsappbot/vault.ex](/Users/michaelmunavu/Documents/projects/whatsappbot/lib/whatsappbot/vault.ex:1)
- `ENCRYPTION_KEY` in [config/runtime.exs](/Users/michaelmunavu/Documents/projects/whatsappbot/config/runtime.exs:56)

What to add:

- `lib/whatsappbot/encrypted/string.ex`

Use the same pattern already used for encrypted endpoint-style fields in the project.

Goal:

- the app works with a normal `access_token` field in code
- the database stores the encrypted binary field

---

## Step 5. Build the Meta Connection screen

The route already exists:

- `/workspaces/:id/meta`

Right now it only shows a placeholder in [lib/whatsappbot_web/live/workspaces_live/section.ex](/Users/michaelmunavu/Documents/projects/whatsappbot/lib/whatsappbot_web/live/workspaces_live/section.ex:36).

Replace that placeholder with a real setup screen.

Suggested flow:

### Step 5.1 Credentials form

Fields:

- Phone Number ID
- WABA ID
- Access Token

On save:

- insert or update the workspace's Meta connection
- set status to `pending`

### Step 5.2 Webhook setup panel

Show:

- webhook URL
- verify token
- copy buttons
- clear setup instructions

Webhook URL format:

```text
https://your-domain.com/webhooks/whatsapp/<workspace.slug>
```

The workspace already has a slug field in [lib/whatsappbot/workspaces/workspace.ex](/Users/michaelmunavu/Documents/projects/whatsappbot/lib/whatsappbot/workspaces/workspace.ex:8).

### Step 5.3 Status panel

Show:

- current status badge
- `webhook_verified_at`
- last error, if any
- a small checklist for "credentials saved", "webhook verified", and "test message received"

---

## Step 6. Add webhook routes

Add these routes to [lib/whatsappbot_web/router.ex](/Users/michaelmunavu/Documents/projects/whatsappbot/lib/whatsappbot_web/router.ex:1):

```elixir
get "/webhooks/whatsapp/:slug", WebhookController, :handle_verification
post "/webhooks/whatsapp/:slug", WebhookController, :handle_message
```

These should go through the `:api` pipeline, not the browser pipeline.

Why:

- Meta will call them as plain HTTP webhook requests
- they must not depend on session auth or CSRF browser behavior

---

## Step 7. Build the webhook controller

Create:

- `lib/whatsappbot_web/controllers/webhook_controller.ex`

### GET verification endpoint

Implement:

- read `hub.mode`
- read `hub.verify_token`
- read `hub.challenge`
- find the workspace by slug
- load the workspace's Meta connection
- compare the stored `verify_token`

If valid:

- return `hub.challenge` as plain text
- set `webhook_verified_at`
- move status toward `active`

If invalid:

- return `403`

### POST inbound message endpoint

Implement:

- parse Meta's JSON payload
- extract:
  - workspace
  - sender phone number
  - message text
  - WhatsApp message id
- return `200` immediately
- enqueue background processing with Oban

Important:

- ignore delivery status callbacks at first if they are not needed
- process only actual inbound user messages
- make parsing defensive because Meta payloads can contain multiple event shapes

---

## Step 8. Add an Oban worker for inbound WhatsApp messages

Create:

- `lib/whatsappbot/workers/process_inbound_message.ex`

Inputs:

- `workspace_id`
- `phone_number`
- `message_text`
- `whatsapp_message_id`

Worker flow:

1. load the workspace's Meta connection
2. call `Dispatcher.dispatch(workspace_id, phone_number, message_text, :whatsapp)`
3. take the assistant reply and CTA
4. send the reply back through Meta's API

This is the key reuse point:

- the Playground already uses the same conversation engine
- the live channel should only change the transport layer, not the AI logic

Use [lib/whatsappbot/conversations/dispatcher.ex](/Users/michaelmunavu/Documents/projects/whatsappbot/lib/whatsappbot/conversations/dispatcher.ex:10) as the integration seam.

Also add:

- duplicate protection using `whatsapp_message_id`
- `max_attempts: 3`
- useful error logging

---

## Step 9. Build the Meta sender

Create:

- `lib/whatsappbot/meta/sender.ex`

Responsibility:

- turn your internal reply format into a WhatsApp Cloud API request
- send it to Meta
- return `{:ok, message_id}` or `{:error, reason}`

It needs to support:

- plain text replies
- `website`
- `phone`
- `whatsapp`
- `reply_buttons`
- `list_message`
- `location`

The CTA types already exist in the app, especially in:

- [lib/whatsappbot/cta_rules/cta_rule.ex](/Users/michaelmunavu/Documents/projects/whatsappbot/lib/whatsappbot/cta_rules/cta_rule.ex:1)
- [lib/whatsappbot_web/live/playground_live.ex](/Users/michaelmunavu/Documents/projects/whatsappbot/lib/whatsappbot_web/live/playground_live.ex:212)

Important implementation note:

- use the **current Graph API version shown in your Meta app/docs at implementation time**
- do not blindly hard-code an old version from planning notes

Request shape at a high level:

- POST to `https://graph.facebook.com/<version>/<phone_number_id>/messages`
- send `Authorization: Bearer <access_token>`
- send JSON payloads matching the message type

---

## Step 10. Deploy to a public HTTPS domain

Meta cannot verify a localhost webhook.

You need a deployed app with:

- HTTPS
- a stable public hostname
- the Phoenix server enabled

Production settings already expected by this repo include:

- `PHX_SERVER`
- `PHX_HOST`
- `PORT`
- `DATABASE_URL`
- `SECRET_KEY_BASE`
- `ENCRYPTION_KEY`
- `OPENAI_API_KEY`

See [config/runtime.exs](/Users/michaelmunavu/Documents/projects/whatsappbot/config/runtime.exs:43) for the current runtime configuration.

Before webhook setup, confirm this works:

- your deployed app loads normally in the browser
- your database is migrated
- your workspace data exists in production

---

## Step 11. Configure the webhook in Meta

Once deployed:

1. open your Meta app
2. go to the WhatsApp product
3. open webhook configuration
4. paste the callback URL:

   `https://your-domain.com/webhooks/whatsapp/<workspace.slug>`

5. paste the verify token shown in your Meta Connection screen
6. submit verification

Expected result:

- Meta calls your `GET /webhooks/whatsapp/:slug`
- your app returns the challenge
- the connection becomes verified

If verification fails, check:

- the route exists in production
- the workspace slug is correct
- the stored verify token matches exactly
- the endpoint is public and using HTTPS

---

## Step 12. Send a real test message

After verification:

1. send a WhatsApp message from an allowed tester phone number
2. confirm Meta sends the webhook to your app
3. confirm your app enqueues the Oban job
4. confirm the worker calls `Dispatcher.dispatch/4`
5. confirm the app sends the reply back through Meta
6. confirm the reply arrives in WhatsApp

Test these cases:

- plain text question
- product browse request
- reply buttons CTA
- list CTA
- location CTA
- empty or unsupported inbound payload

---

## Step 13. Add tests before going live

Minimum tests:

- correct verification token returns the challenge
- wrong token returns `403`
- inbound message webhook enqueues an Oban job
- duplicate inbound message does not process twice
- Meta sender builds valid payloads for each CTA type
- worker handles sender/API failures cleanly

This matches the unfinished integration tasks already listed in [tasks.md](/Users/michaelmunavu/Documents/projects/whatsappbot/tasks.md:500).

---

## Step 14. Go-live checklist

You are ready to go live when all of these are true:

- the workspace works in Playground
- Meta credentials are saved
- the access token is encrypted at rest
- webhook verification succeeds
- inbound messages enqueue jobs
- outbound replies send successfully
- CTA payloads render correctly in real WhatsApp
- retries and logging are in place
- production secrets are set

---

## Recommended implementation order

If you want the smoothest build sequence, do it in this order:

1. Meta connection schema
2. encrypted access token type
3. Meta Connection LiveView
4. webhook routes
5. webhook controller
6. inbound worker
7. Meta sender
8. tests
9. production deploy
10. Meta dashboard verification

---

## Short version

If you want the simplest summary:

1. Make the workspace perfect in Playground.
2. Add a `meta_connections` table and encrypted access token support.
3. Build the real `/workspaces/:id/meta` setup screen.
4. Add `/webhooks/whatsapp/:slug` GET and POST endpoints.
5. Queue inbound messages into Oban.
6. Reuse `Dispatcher.dispatch/4` for reply generation.
7. Send replies to Meta's Cloud API.
8. Deploy to public HTTPS.
9. Verify the webhook in Meta.
10. Test end-to-end with a real number.

