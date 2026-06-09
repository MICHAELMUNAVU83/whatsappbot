defmodule WhatsappbotWeb.ErrorJSONTest do
  use WhatsappbotWeb.ConnCase, async: true

  test "renders 404" do
    assert WhatsappbotWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert WhatsappbotWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
