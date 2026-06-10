defmodule Whatsappbot.EndpointsTest do
  use Whatsappbot.DataCase, async: true

  import Whatsappbot.AccountsFixtures
  import Whatsappbot.EndpointsFixtures
  import Whatsappbot.WorkspacesFixtures

  alias Whatsappbot.Endpoints
  alias Whatsappbot.Repo

  setup {Req.Test, :verify_on_exit!}

  setup do
    on_exit(fn -> Process.delete(:endpoint_req_options) end)
    :ok
  end

  describe "fetch_live_data/1" do
    test "GET endpoint returns parsed JSON" do
      workspace = workspace_fixture(user_fixture())

      Req.Test.expect(__MODULE__.GetStub, fn conn ->
        assert conn.method == "GET"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer secret-token"]

        products =
          for id <- 1..60 do
            %{"id" => id, "name" => "Product #{id}"}
          end

        Req.Test.json(conn, products)
      end)

      Process.put(:endpoint_req_options, plug: {Req.Test, __MODULE__.GetStub})

      endpoint =
        endpoint_fixture(workspace, %{
          url: "https://catalog.test/products",
          headers: %{"Authorization" => "Bearer secret-token"}
        })

      assert {:ok, data} = Endpoints.fetch_live_data(endpoint)
      assert is_list(data)
      assert length(data) == 50
      assert hd(data)["id"] == 1
    end

    test "POST endpoint substitutes {{query}}" do
      workspace = workspace_fixture(user_fixture())

      Req.Test.expect(__MODULE__.PostStub, fn conn ->
        assert conn.method == "POST"

        body =
          conn
          |> Req.Test.raw_body()
          |> IO.iodata_to_binary()
          |> Jason.decode!()

        assert body == %{"limit" => 5, "query" => "test"}

        Req.Test.json(conn, %{"items" => [%{"name" => "Tomatoes"}]})
      end)

      Process.put(:endpoint_req_options, plug: {Req.Test, __MODULE__.PostStub})

      endpoint =
        endpoint_fixture(workspace, %{
          url: "https://catalog.test/search",
          method: "POST",
          body_template: ~s({"query":"{{query}}","limit":5})
        })

      assert {:ok, data} = Endpoints.fetch_live_data(endpoint)
      assert data["items"] == [%{"name" => "Tomatoes"}]
    end

    test "returns {:error, _} on bad URL" do
      workspace = workspace_fixture(user_fixture())

      Req.Test.expect(__MODULE__.ErrorStub, fn conn ->
        Req.Test.transport_error(conn, :nxdomain)
      end)

      Process.put(:endpoint_req_options, plug: {Req.Test, __MODULE__.ErrorStub})

      endpoint = endpoint_fixture(workspace, %{url: "https://bad-url.test/catalog"})

      assert {:error, reason} = Endpoints.fetch_live_data(endpoint)
      assert reason =~ "nxdomain"
    end
  end

  describe "encrypted headers" do
    test "headers are encrypted at rest" do
      workspace = workspace_fixture(user_fixture())

      endpoint =
        endpoint_fixture(workspace, %{
          headers: %{
            "Authorization" => "Bearer super-secret-token",
            "X-Api-Key" => "abc123"
          }
        })

      assert endpoint.headers["Authorization"] == "Bearer super-secret-token"

      result = Repo.query!("SELECT headers_encrypted FROM endpoints WHERE id = $1", [endpoint.id])
      [[raw_headers]] = result.rows

      assert is_binary(raw_headers)
      assert raw_headers != ""
      assert :binary.match(raw_headers, "super-secret-token") == :nomatch
      assert :binary.match(raw_headers, "abc123") == :nomatch
    end
  end
end
