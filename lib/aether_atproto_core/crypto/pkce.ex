defmodule AetherATProtoCore.Crypto.PKCE do
  @moduledoc """
  PKCE (Proof Key for Code Exchange) implementation for OAuth 2.1.

  Generates code verifiers and challenges according to RFC 7636.
  """

  @doc """
  Generates PKCE code verifier and code challenge for OAuth flow.

  Returns a map with:
  - code_verifier: Random 43-128 character string
  - code_challenge: Base64 URL-encoded SHA256 hash of verifier
  - code_challenge_method: "S256"
  """
  def generate do
    code_verifier =
      :crypto.strong_rand_bytes(32)
      |> Base.url_encode64(padding: false)

    code_challenge =
      :crypto.hash(:sha256, code_verifier)
      |> Base.url_encode64(padding: false)

    %{
      code_verifier: code_verifier,
      code_challenge: code_challenge,
      code_challenge_method: "S256"
    }
  end
end
