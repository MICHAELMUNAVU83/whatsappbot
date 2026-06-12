defmodule Whatsappbot.Encrypted.String do
  use Cloak.Ecto.Binary, vault: Whatsappbot.Vault
end
