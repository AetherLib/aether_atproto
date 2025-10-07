defmodule Aether.ATProto.DID.Document do
  @moduledoc """
  Pure data structures and logic for ATProto DID Documents.

  This module contains no network I/O and can be used by both clients and servers.
  """

  alias Aether.ATProto.DID.Document.Service

  defstruct [:id, :alsoKnownAs, :verificationMethod, :service]

  @type t :: %__MODULE__{
          id: String.t(),
          alsoKnownAs: [String.t()] | nil,
          verificationMethod: [map()] | nil,
          service: [Service.t()] | nil
        }

  @doc """
  Get the PDS (Personal Data Server) endpoint from a DID Document.
  """
  @spec get_pds_endpoint(t()) :: {:ok, String.t()} | {:error, :not_found}
  def get_pds_endpoint(%__MODULE__{service: services}) when is_list(services) do
    case Enum.find(services, fn service ->
           service.type == "AtprotoPersonalDataServer"
         end) do
      %Service{serviceEndpoint: endpoint} -> {:ok, endpoint}
      nil -> {:error, :not_found}
    end
  end

  def get_pds_endpoint(_), do: {:error, :not_found}

  @doc """
  Get a service endpoint by type from a DID Document.
  """
  @spec get_service(t(), String.t()) :: {:ok, Service.t()} | {:error, :not_found}
  def get_service(%__MODULE__{service: services}, type) when is_list(services) do
    case Enum.find(services, fn service -> service.type == type end) do
      nil -> {:error, :not_found}
      service -> {:ok, service}
    end
  end

  def get_service(_, _), do: {:error, :not_found}

  @doc """
  Get the handle from a DID Document's alsoKnownAs field.
  """
  @spec get_handle(t()) :: String.t() | nil
  def get_handle(%__MODULE__{alsoKnownAs: also_known_as}) when is_list(also_known_as) do
    Enum.find_value(also_known_as, fn aka ->
      case String.split(aka, "at://", parts: 2) do
        ["", handle] -> handle
        _ -> nil
      end
    end)
  end

  def get_handle(_), do: nil

  @doc """
  Get the signing key (atproto verification method) from a DID Document.
  """
  @spec get_signing_key(t()) :: {:ok, map()} | {:error, :not_found}
  def get_signing_key(%__MODULE__{verificationMethod: methods}) when is_list(methods) do
    case Enum.find(methods, fn method ->
           String.ends_with?(method["id"] || "", "#atproto")
         end) do
      nil -> {:error, :not_found}
      key -> {:ok, key}
    end
  end

  def get_signing_key(_), do: {:error, :not_found}

  @doc """
  Parse a raw document map into a structured Document.
  """
  @spec parse_document(map()) :: {:ok, t()}
  def parse_document(doc_map) when is_map(doc_map) do
    services =
      doc_map
      |> Map.get("service", [])
      |> Enum.map(&parse_service/1)
      |> Enum.reject(&is_nil/1)

    {:ok,
     %__MODULE__{
       id: doc_map["id"],
       alsoKnownAs: doc_map["alsoKnownAs"],
       verificationMethod: doc_map["verificationMethod"],
       service: services
     }}
  end

  @doc """
  Parse a service map into a structured Service.
  """
  @spec parse_service(map()) :: Service.t() | nil
  def parse_service(%{"id" => id, "type" => type, "serviceEndpoint" => endpoint}) do
    %Service{
      id: id,
      type: type,
      serviceEndpoint: endpoint
    }
  end

  def parse_service(_), do: nil

  @doc """
  Create a new DID document for a PDS-hosted user.
  """
  @spec create(String.t(), keyword()) :: t()
  def create(did, opts \\ []) do
    handle = Keyword.get(opts, :handle)
    pds_endpoint = Keyword.get(opts, :pds_endpoint)
    signing_key = Keyword.get(opts, :signing_key)
    also_known_as = Keyword.get(opts, :also_known_as) || build_also_known_as(handle)

    %__MODULE__{
      id: did,
      alsoKnownAs: also_known_as,
      verificationMethod: build_verification_method(did, signing_key),
      service: build_services(pds_endpoint)
    }
  end

  @doc """
  Create a DID document for did:web.
  """
  @spec create_web(String.t(), keyword()) :: t()
  def create_web(domain, opts \\ []) do
    did = "did:web:#{domain}"
    signing_key = Keyword.get(opts, :signing_key)
    service_endpoint = Keyword.get(opts, :service_endpoint)

    %__MODULE__{
      id: did,
      alsoKnownAs: Keyword.get(opts, :also_known_as, []),
      verificationMethod: build_verification_method(did, signing_key),
      service: build_services(service_endpoint)
    }
  end

  @doc """
  Add a service endpoint to a DID document.
  """
  @spec add_service(t(), keyword()) :: t()
  def add_service(%__MODULE__{service: services} = doc, opts) do
    service = %Service{
      id: Keyword.fetch!(opts, :id),
      type: Keyword.fetch!(opts, :type),
      serviceEndpoint: Keyword.fetch!(opts, :endpoint)
    }

    %{doc | service: (services || []) ++ [service]}
  end

  @doc """
  Update the verification method (signing key) in a DID document.
  """
  @spec update_signing_key(t(), String.t()) :: t()
  def update_signing_key(%__MODULE__{id: did} = doc, signing_key) do
    %{doc | verificationMethod: build_verification_method(did, signing_key)}
  end

  # Private helper functions

  defp build_also_known_as(nil), do: []
  defp build_also_known_as(handle), do: ["at://#{handle}"]

  defp build_verification_method(_did, nil), do: []

  defp build_verification_method(did, signing_key) do
    [
      %{
        "id" => "#{did}#atproto",
        "type" => "Multikey",
        "controller" => did,
        "publicKeyMultibase" => signing_key
      }
    ]
  end

  defp build_services(nil), do: []

  defp build_services(pds_endpoint) do
    [
      %Service{
        id: "#atproto_pds",
        type: "AtprotoPersonalDataServer",
        serviceEndpoint: pds_endpoint
      }
    ]
  end
end
