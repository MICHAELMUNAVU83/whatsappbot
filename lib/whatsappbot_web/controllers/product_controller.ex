defmodule WhatsappbotWeb.ProductController do
  use WhatsappbotWeb, :controller

  @products [
    %{
      id: 1,
      name: "Classic Hoodie",
      category: "Apparel",
      description: "Heavyweight cotton hoodie with embroidered logo.",
      image_url:
        "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?fm=jpg&fit=crop&w=900&q=80",
      price: 39.99,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/classic-hoodie"
    },
    %{
      id: 2,
      name: "Wireless Earbuds",
      category: "Electronics",
      description: "Noise-isolating earbuds with charging case.",
      image_url:
        "https://images.unsplash.com/photo-1606220588913-b3aacb4d2f46?fm=jpg&fit=crop&w=900&q=80",
      price: 79.50,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/wireless-earbuds"
    },
    %{
      id: 3,
      name: "Ceramic Mug",
      category: "Home",
      description: "Matte ceramic mug with 350ml capacity.",
      image_url:
        "https://images.unsplash.com/photo-1514228742587-6b1558fcf93a?fm=jpg&fit=crop&w=900&q=80",
      price: 14.25,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/ceramic-mug"
    },
    %{
      id: 4,
      name: "Notebook Set",
      category: "Stationery",
      description: "Three ruled notebooks for school or office use.",
      image_url:
        "https://images.unsplash.com/photo-1531346878377-a5be20888e57?fm=jpg&fit=crop&w=900&q=80",
      price: 18.00,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/notebook-set"
    },
    %{
      id: 5,
      name: "Running Shoes",
      category: "Footwear",
      description: "Lightweight trainers built for daily road runs.",
      image_url:
        "https://images.unsplash.com/photo-1542291026-7eec264c27ff?fm=jpg&fit=crop&w=900&q=80",
      price: 96.75,
      currency: "USD",
      in_stock: false,
      url: "https://shop.example.com/products/running-shoes"
    },
    %{
      id: 6,
      name: "Desk Lamp",
      category: "Home",
      description: "Warm LED lamp with adjustable neck.",
      image_url:
        "https://images.unsplash.com/photo-1507473885765-e6ed057f782c?fm=jpg&fit=crop&w=900&q=80",
      price: 42.10,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/desk-lamp"
    },
    %{
      id: 7,
      name: "Fitness Tracker",
      category: "Electronics",
      description: "Tracks steps, heart rate, and sleep trends.",
      image_url:
        "https://images.unsplash.com/photo-1575311373937-040b8e1fd5b6?fm=jpg&fit=crop&w=900&q=80",
      price: 129.99,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/fitness-tracker"
    },
    %{
      id: 8,
      name: "Leather Wallet",
      category: "Accessories",
      description: "Slim bi-fold wallet with RFID protection.",
      image_url:
        "https://images.unsplash.com/photo-1627123424574-724758594e93?fm=jpg&fit=crop&w=900&q=80",
      price: 34.40,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/leather-wallet"
    },
    %{
      id: 9,
      name: "Water Bottle",
      category: "Outdoors",
      description: "Insulated stainless bottle that keeps drinks cold.",
      image_url:
        "https://images.unsplash.com/photo-1602143407151-7111542de6e8?fm=jpg&fit=crop&w=900&q=80",
      price: 19.95,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/water-bottle"
    },
    %{
      id: 10,
      name: "Bluetooth Speaker",
      category: "Electronics",
      description: "Portable speaker with deep bass and 12-hour battery.",
      image_url:
        "https://images.unsplash.com/photo-1545454675-3531b543be5d?fm=jpg&fit=crop&w=900&q=80",
      price: 58.30,
      currency: "USD",
      in_stock: false,
      url: "https://shop.example.com/products/bluetooth-speaker"
    },
    %{
      id: 11,
      name: "Scented Candle",
      category: "Home",
      description: "Soy wax candle with sandalwood fragrance.",
      image_url:
        "https://images.unsplash.com/photo-1603006905003-be475563bc59?fm=jpg&fit=crop&w=900&q=80",
      price: 22.00,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/scented-candle"
    },
    %{
      id: 12,
      name: "Laptop Sleeve",
      category: "Accessories",
      description: "Padded sleeve sized for 13-inch laptops.",
      image_url:
        "https://images.unsplash.com/photo-1541807084-5c52b6b3adef?fm=jpg&fit=crop&w=900&q=80",
      price: 27.89,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/laptop-sleeve"
    },
    %{
      id: 13,
      name: "Gaming Mouse",
      category: "Electronics",
      description: "Ergonomic mouse with programmable buttons.",
      image_url:
        "https://images.unsplash.com/photo-1527814050087-3793815479db?fm=jpg&fit=crop&w=900&q=80",
      price: 49.99,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/gaming-mouse"
    },
    %{
      id: 14,
      name: "Backpack",
      category: "Travel",
      description: "Carry-on backpack with padded laptop compartment.",
      image_url:
        "https://images.unsplash.com/photo-1548036328-c9fa89d128fa?fm=jpg&fit=crop&w=900&q=80",
      price: 64.00,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/backpack"
    },
    %{
      id: 15,
      name: "Coffee Beans",
      category: "Groceries",
      description: "Medium roast beans with chocolate notes.",
      image_url:
        "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?fm=jpg&fit=crop&w=900&q=80",
      price: 16.50,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/coffee-beans"
    },
    %{
      id: 16,
      name: "Yoga Mat",
      category: "Fitness",
      description: "Non-slip mat with extra cushioning.",
      image_url:
        "https://images.unsplash.com/photo-1518611012118-696072aa579a?fm=jpg&fit=crop&w=900&q=80",
      price: 31.20,
      currency: "USD",
      in_stock: false,
      url: "https://shop.example.com/products/yoga-mat"
    },
    %{
      id: 17,
      name: "Phone Stand",
      category: "Accessories",
      description: "Foldable aluminum stand for phones and mini tablets.",
      image_url:
        "https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?fm=jpg&fit=crop&w=900&q=80",
      price: 12.99,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/phone-stand"
    },
    %{
      id: 18,
      name: "Sunglasses",
      category: "Accessories",
      description: "Polarized frames with UV400 protection.",
      image_url:
        "https://images.unsplash.com/photo-1511499767150-a48a237f0083?fm=jpg&fit=crop&w=900&q=80",
      price: 25.49,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/sunglasses"
    },
    %{
      id: 19,
      name: "Mini Projector",
      category: "Electronics",
      description: "Compact projector for movies and presentations.",
      image_url:
        "https://images.unsplash.com/photo-1516321318423-f06f85e504b3?fm=jpg&fit=crop&w=900&q=80",
      price: 189.00,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/mini-projector"
    },
    %{
      id: 20,
      name: "Travel Pillow",
      category: "Travel",
      description: "Memory foam neck pillow for flights and road trips.",
      image_url:
        "https://images.unsplash.com/photo-1527631746610-bca00a040d60?fm=jpg&fit=crop&w=900&q=80",
      price: 21.75,
      currency: "USD",
      in_stock: true,
      url: "https://shop.example.com/products/travel-pillow"
    }
  ]

  def index(conn, _params) do
    json(conn, %{
      products: @products,
      total: length(@products)
    })
  end
end
