defmodule Whatsappbot.AI.ClaudeClientTest do
  use ExUnit.Case, async: true

  alias Whatsappbot.AI.ClaudeClient

  setup {Req.Test, :verify_on_exit!}

  setup do
    on_exit(fn -> Process.delete(:claude_req_options) end)
    :ok
  end

  test "chat/2 parses JSON replies and returns token counts" do
    Req.Test.expect(__MODULE__.JsonReplyStub, fn conn ->
      assert conn.method == "POST"
      assert Plug.Conn.get_req_header(conn, "x-api-key") == ["test-anthropic-key"]
      assert Plug.Conn.get_req_header(conn, "anthropic-version") == ["2023-06-01"]

      request =
        conn
        |> Req.Test.raw_body()
        |> IO.iodata_to_binary()
        |> Jason.decode!()

      assert request["system"] == "System prompt"
      assert request["messages"] == [%{"role" => "user", "content" => "Do you have tomatoes?"}]

      Req.Test.json(conn, %{
        "content" => [
          %{
            "type" => "text",
            "text" =>
              ~s({"reply":"Yes, tomatoes are available.","cta":{"type":"website","payload":{"url":"https://shop.example.com"}}})
          }
        ],
        "usage" => %{"input_tokens" => 120, "output_tokens" => 40}
      })
    end)

    Process.put(:claude_req_options, plug: {Req.Test, __MODULE__.JsonReplyStub})

    assert {:ok, {:ok, result}} =
             {:ok,
              ClaudeClient.chat(
                [%{role: "user", content: "Do you have tomatoes?"}],
                "System prompt"
              )}

    assert result.reply == "Yes, tomatoes are available."

    assert result.cta == %{
             "type" => "website",
             "payload" => %{"url" => "https://shop.example.com"}
           }

    assert result.tokens == 160
  end

  test "chat/2 falls back to raw text when JSON parsing fails" do
    Req.Test.expect(__MODULE__.TextReplyStub, fn conn ->
      Req.Test.json(conn, %{
        "content" => [%{"type" => "text", "text" => "Sorry, I do not know that yet."}],
        "usage" => %{"input_tokens" => 10, "output_tokens" => 5}
      })
    end)

    Process.put(:claude_req_options, plug: {Req.Test, __MODULE__.TextReplyStub})

    assert {:ok, {:ok, result}} =
             {:ok,
              ClaudeClient.chat([%{"role" => "user", "content" => "Question"}], "System prompt")}

    assert result.reply == "Sorry, I do not know that yet."
    assert result.cta == nil
    assert result.tokens == 15
  end

  test "chat/2 returns an error tuple for non-2xx responses" do
    Req.Test.expect(__MODULE__.ErrorStub, fn conn ->
      Plug.Conn.resp(conn, 401, ~s({"error":{"message":"invalid api key"}}))
    end)

    Process.put(:claude_req_options, plug: {Req.Test, __MODULE__.ErrorStub})

    assert {:error, reason} =
             ClaudeClient.chat([%{role: "user", content: "Hello"}], "System prompt")

    assert reason =~ "HTTP 401"
    assert reason =~ "invalid api key"
  end
end
