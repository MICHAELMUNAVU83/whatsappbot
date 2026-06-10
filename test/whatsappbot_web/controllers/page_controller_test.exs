defmodule WhatsappbotWeb.PageControllerTest do
  use WhatsappbotWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ "Launch a WhatsApp sales bot without writing code."
    assert response =~ "WhatsappBot"
  end
end
