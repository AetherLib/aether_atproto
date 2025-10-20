defmodule Aether.ATProto.DID.Document.Client do
  @moduledoc """
  DID Document resolution client.

  This module performs actual HTTP requests to resolve DIDs via req.
  """

  alias Aether.ATProto.DID
  alias Aether.ATProto.DID.Document

  @doc """
  Resolve a DID to its DID Document.

  Automatically determines resolution method based on DID method.
  """
  @spec resolve(String.t()) :: {:ok, Document.t()} | {:error, term()}
  def resolve(did_string) when is_binary(did_string) do
    case DID.parse(did_string) do
      {:ok, %{method: "plc"}} -> resolve_plc(did_string)
      {:ok, %{method: "web"}} -> resolve_web(did_string)
      {:ok, %{method: method}} -> {:error, {:unsupported_method, method}}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Resolve a did:plc identifier via the PLC directory.
  """
  @spec resolve_plc(String.t()) :: {:ok, Document.t()} | {:error, term()}
  def resolve_plc("did:plc:" <> _identifier = did) do
    url = "https://plc.directory/#{did}"

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        Document.parse_document(body)

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end

  @doc """
  Resolve a did:web identifier via HTTPS.
  """
  @spec resolve_web(String.t()) :: {:ok, Document.t()} | {:error, term()}
  def resolve_web("did:web:" <> identifier) do
    url = build_did_web_url(identifier)

    case Req.get(url) do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        Document.parse_document(body)

      {:ok, %{status: 404}} ->
        {:error, :not_found}

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end

  @doc false
  def build_did_web_url(identifier) do
    parts = String.split(identifier, ":")

    case parts do
      [domain] ->
        "https://#{domain}/.well-known/did.json"

      [domain | path_parts] ->
        path = Enum.join(path_parts, "/")
        "https://#{domain}/#{path}/did.json"
    end
  end
end
