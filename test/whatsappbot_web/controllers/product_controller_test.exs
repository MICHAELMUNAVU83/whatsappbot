defmodule WhatsappbotWeb.ProductControllerTest do
  use WhatsappbotWeb.ConnCase, async: true

  test "GET /api/test/products returns 20 public products", %{conn: conn} do
    conn = get(conn, ~p"/api/test/products")
    response = json_response(conn, 200)

    assert response["total"] == 20
    assert length(response["products"]) == 20

    assert hd(response["products"]) == %{
             "category" => "Apparel",
             "currency" => "USD",
             "description" => "Heavyweight cotton hoodie with embroidered logo.",
             "id" => 1,
             "image_url" =>
               "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?fm=jpg&fit=crop&w=900&q=80",
             "in_stock" => true,
             "name" => "Classic Hoodie",
             "price" => 39.99,
             "url" => "https://shop.example.com/products/classic-hoodie"
           }
  end
end
