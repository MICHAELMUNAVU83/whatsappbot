defmodule WhatsappbotWeb.UserRegistrationControllerTest do
  use WhatsappbotWeb.ConnCase, async: true

  import Whatsappbot.AccountsFixtures

  describe "GET /users/register" do
    test "renders registration page", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ ~p"/users/log_in"
      assert response =~ ~p"/users/register"
    end

    test "redirects if already logged in", %{conn: conn} do
      conn = conn |> log_in_user(user_fixture()) |> get(~p"/users/register")

      assert redirected_to(conn) == ~p"/"
    end
  end

  describe "POST /users/register" do
    @tag :capture_log
    test "creates account and logs the user in", %{conn: conn} do
      email = unique_user_email()
      name = "Amina"

      conn =
        post(conn, ~p"/users/register", %{
          "user" => valid_user_attributes(name: name, email: email)
        })

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/workspaces/new"

      conn = get(conn, ~p"/workspaces/new")
      response = html_response(conn, 200)
      assert response =~ "New workspace"
      assert response =~ name
    end

    test "render errors for invalid data", %{conn: conn} do
      conn =
        post(conn, ~p"/users/register", %{
          "user" => %{"name" => "", "email" => "with spaces", "password" => "too short"}
        })

      response = html_response(conn, 200)
      assert response =~ "Register"
      assert response =~ "can&#39;t be blank"
      assert response =~ "must have the @ sign and no spaces"
      assert response =~ "should be at least 12 character"
    end

    test "shows an error for duplicate email", %{conn: conn} do
      user = user_fixture()

      conn =
        post(conn, ~p"/users/register", %{
          "user" => valid_user_attributes(name: "Another User", email: user.email)
        })

      response = html_response(conn, 200)
      assert response =~ "has already been taken"
    end
  end
end
