defmodule AetherATProtoCore.DIDFixtures do
  @moduledoc """
  Test fixtures for DID testing.
  """

  def plc_did do
    "did:plc:z72i7hdynmk24r6zlsdc6nxd"
  end

  def web_did do
    "did:web:example.com"
  end

  def web_did_with_port do
    "did:web:example.com:3000"
  end

  def key_did do
    "did:key:zQ3shokFTS3brHcDQrn82RUDfCZESWL1ZdCEJwekUDPQiYBme"
  end

  def web_did_with_fragment do
    "did:web:example.com#key1"
  end

  def web_did_with_query do
    "did:web:example.com?version=1"
  end

  def web_did_with_fragment_and_query do
    "did:web:example.com?version=1#key1"
  end

  def invalid_dids do
    [
      "invalid",
      "did:",
      "did:plc",
      "did:unsupported:test",
      "did:plc:invalidchars!",
      "did:plc:tooshort",
      "did:web:example..com",
      "did:key:invalid"
    ]
  end
end
