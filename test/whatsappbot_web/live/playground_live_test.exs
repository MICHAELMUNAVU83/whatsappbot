defmodule WhatsappbotWeb.PlaygroundLiveTest do
  use WhatsappbotWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Whatsappbot.AccountsFixtures
  import Whatsappbot.CTARulesFixtures
  import Whatsappbot.EndpointsFixtures
  import Whatsappbot.WorkspacesFixtures

  alias Whatsappbot.Conversations

  setup {Req.Test, :verify_on_exit!}

  setup do
    on_exit(fn ->
      Process.delete(:endpoint_req_options)
      Process.delete(:claude_req_options)
      Application.delete_env(:whatsappbot, :endpoint_req_options)
      Application.delete_env(:whatsappbot, :claude_req_options)
    end)

    :ok
  end

  test "sending a message shows the assistant reply", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      method: "GET",
      refresh_strategy: "on_demand"
    })

    stub_endpoint(%{"items" => [%{"name" => "Tomatoes", "price" => 120}]})

    stub_claude(~s({"reply":"Tomatoes are available today.","cta":null}))

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/playground")

    view
    |> form("form", playground: %{message: "Do you have tomatoes?"})
    |> render_submit()

    html = render(view)

    assert html =~ "Do you have tomatoes?"
    assert html =~ "Tomatoes are available today."
  end

  test "cta appears in the assistant bubble when the reply includes one", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    endpoint_fixture(workspace, %{
      url: "https://catalog.test/products",
      method: "GET",
      refresh_strategy: "on_demand"
    })

    cta_rule_fixture(workspace)

    stub_endpoint(%{"items" => [%{"name" => "Tomatoes", "price" => 120}]})

    stub_claude(
      ~s({"reply":"You can order tomatoes now.","cta":{"type":"website","payload":{"url":"https://shop.example.com/checkout"}}})
    )

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/playground")

    view
    |> form("form", playground: %{message: "I want to buy tomatoes"})
    |> render_submit()

    html = render(view)

    assert html =~ "You can order tomatoes now."
    assert html =~ "Open link"
    assert html =~ "https://shop.example.com/checkout"
  end

  test "clear chat removes the playground messages", %{conn: conn} do
    user = user_fixture()
    workspace = workspace_fixture(user)

    {:ok, conversation} =
      Conversations.get_or_create_conversation(
        workspace.id,
        Conversations.playground_phone_number(workspace.id),
        :playground
      )

    {:ok, _user_message} = Conversations.add_message(conversation, :user, "Hello there")

    {:ok, _assistant_message} =
      Conversations.add_message(conversation, :assistant, "Hi, welcome back")

    {:ok, view, _html} =
      conn
      |> log_in_user(user)
      |> live(~p"/workspaces/#{workspace.id}/playground")

    assert render(view) =~ "Hi, welcome back"

    view
    |> element("button", "Clear chat")
    |> render_click()

    html = render(view)

    refute html =~ "Hi, welcome back"
    refute html =~ "Hello there"
    assert html =~ "Send a message to simulate a buyer conversation."

    assert Conversations.get_conversation(
             workspace.id,
             Conversations.playground_phone_number(workspace.id),
             :playground
           ) == nil
  end

  defp stub_endpoint(payload) do
    Req.Test.expect(__MODULE__.EndpointStub, fn conn ->
      assert conn.method == "GET"
      Req.Test.json(conn, payload)
    end)

    stub_options = [plug: {Req.Test, __MODULE__.EndpointStub}]
    Process.put(:endpoint_req_options, stub_options)
    Application.put_env(:whatsappbot, :endpoint_req_options, stub_options)
  end

  defp stub_claude(response_text) do
    Req.Test.expect(__MODULE__.ClaudeStub, fn conn ->
      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert is_binary(request["system"])
      assert request["messages"] != []

      Req.Test.json(conn, %{
        "content" => [%{"type" => "text", "text" => response_text}],
        "usage" => %{"input_tokens" => 21, "output_tokens" => 9}
      })
    end)

    stub_options = [plug: {Req.Test, __MODULE__.ClaudeStub}]
    Process.put(:claude_req_options, stub_options)
    Application.put_env(:whatsappbot, :claude_req_options, stub_options)
  end
end
