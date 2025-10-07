defmodule Aether.ATProto.DID.DocumentTest do
  use ExUnit.Case, async: true
  doctest Aether.ATProto.DID.Document

  alias Aether.ATProto.DID.Document
  alias Aether.ATProto.DID.Document.Service

  describe "parse_document/1" do
    test "parses a complete DID document" do
      doc_map = %{
        "id" => "did:plc:abc123",
        "alsoKnownAs" => ["at://alice.bsky.social"],
        "verificationMethod" => [
          %{
            "id" => "did:plc:abc123#atproto",
            "type" => "Multikey",
            "controller" => "did:plc:abc123",
            "publicKeyMultibase" => "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"
          }
        ],
        "service" => [
          %{
            "id" => "#atproto_pds",
            "type" => "AtprotoPersonalDataServer",
            "serviceEndpoint" => "https://bsky.social"
          }
        ]
      }

      {:ok, doc} = Document.parse_document(doc_map)

      assert doc.id == "did:plc:abc123"
      assert doc.alsoKnownAs == ["at://alice.bsky.social"]
      assert length(doc.verificationMethod) == 1
      assert length(doc.service) == 1
    end

    test "parses services correctly" do
      doc_map = %{
        "id" => "did:plc:test",
        "service" => [
          %{
            "id" => "#atproto_pds",
            "type" => "AtprotoPersonalDataServer",
            "serviceEndpoint" => "https://pds.example.com"
          },
          %{
            "id" => "#appview",
            "type" => "AtprotoAppView",
            "serviceEndpoint" => "https://appview.example.com"
          }
        ]
      }

      {:ok, doc} = Document.parse_document(doc_map)

      assert length(doc.service) == 2
      assert Enum.all?(doc.service, &match?(%Service{}, &1))

      pds = Enum.find(doc.service, &(&1.type == "AtprotoPersonalDataServer"))
      assert pds.serviceEndpoint == "https://pds.example.com"
    end

    test "handles missing optional fields" do
      doc_map = %{
        "id" => "did:plc:test"
      }

      {:ok, doc} = Document.parse_document(doc_map)

      assert doc.id == "did:plc:test"
      assert doc.alsoKnownAs == nil
      assert doc.verificationMethod == nil
      assert doc.service == []
    end
  end

  describe "get_pds_endpoint/1" do
    test "extracts PDS endpoint from document" do
      doc = %Document{
        id: "did:plc:test",
        service: [
          %Service{
            id: "#atproto_pds",
            type: "AtprotoPersonalDataServer",
            serviceEndpoint: "https://pds.example.com"
          }
        ]
      }

      assert {:ok, "https://pds.example.com"} = Document.get_pds_endpoint(doc)
    end

    test "returns error when no PDS service exists" do
      doc = %Document{
        id: "did:plc:test",
        service: [
          %Service{
            id: "#other",
            type: "OtherService",
            serviceEndpoint: "https://other.example.com"
          }
        ]
      }

      assert {:error, :not_found} = Document.get_pds_endpoint(doc)
    end

    test "returns error when services list is empty" do
      doc = %Document{id: "did:plc:test", service: []}
      assert {:error, :not_found} = Document.get_pds_endpoint(doc)
    end

    test "returns error when services is nil" do
      doc = %Document{id: "did:plc:test", service: nil}
      assert {:error, :not_found} = Document.get_pds_endpoint(doc)
    end

    test "finds PDS among multiple services" do
      doc = %Document{
        id: "did:plc:test",
        service: [
          %Service{id: "#other1", type: "OtherService", serviceEndpoint: "https://other1.com"},
          %Service{
            id: "#atproto_pds",
            type: "AtprotoPersonalDataServer",
            serviceEndpoint: "https://pds.example.com"
          },
          %Service{id: "#other2", type: "OtherService", serviceEndpoint: "https://other2.com"}
        ]
      }

      assert {:ok, "https://pds.example.com"} = Document.get_pds_endpoint(doc)
    end
  end

  describe "get_service/2" do
    test "finds service by type" do
      doc = %Document{
        id: "did:plc:test",
        service: [
          %Service{
            id: "#atproto_pds",
            type: "AtprotoPersonalDataServer",
            serviceEndpoint: "https://pds.example.com"
          },
          %Service{
            id: "#appview",
            type: "AtprotoAppView",
            serviceEndpoint: "https://appview.example.com"
          }
        ]
      }

      assert {:ok, service} = Document.get_service(doc, "AtprotoAppView")
      assert service.serviceEndpoint == "https://appview.example.com"
    end

    test "returns error when service type not found" do
      doc = %Document{
        id: "did:plc:test",
        service: [
          %Service{
            id: "#atproto_pds",
            type: "AtprotoPersonalDataServer",
            serviceEndpoint: "https://pds.example.com"
          }
        ]
      }

      assert {:error, :not_found} = Document.get_service(doc, "NonExistentType")
    end

    test "returns error when services is nil" do
      doc = %Document{id: "did:plc:test", service: nil}
      assert {:error, :not_found} = Document.get_service(doc, "AtprotoPersonalDataServer")
    end
  end

  describe "get_handle/1" do
    test "extracts handle from alsoKnownAs" do
      doc = %Document{
        id: "did:plc:test",
        alsoKnownAs: ["at://alice.bsky.social"]
      }

      assert "alice.bsky.social" = Document.get_handle(doc)
    end

    test "finds handle in list of alsoKnownAs" do
      doc = %Document{
        id: "did:plc:test",
        alsoKnownAs: [
          "https://example.com/alice",
          "at://alice.bsky.social",
          "at://alice.example.com"
        ]
      }

      # Returns first handle found
      assert "alice.bsky.social" = Document.get_handle(doc)
    end

    test "returns nil when no handle exists" do
      doc = %Document{
        id: "did:plc:test",
        alsoKnownAs: ["https://example.com/alice"]
      }

      assert nil == Document.get_handle(doc)
    end

    test "returns nil when alsoKnownAs is empty" do
      doc = %Document{id: "did:plc:test", alsoKnownAs: []}
      assert nil == Document.get_handle(doc)
    end

    test "returns nil when alsoKnownAs is nil" do
      doc = %Document{id: "did:plc:test", alsoKnownAs: nil}
      assert nil == Document.get_handle(doc)
    end
  end

  describe "get_signing_key/1" do
    test "extracts signing key from verificationMethod" do
      doc = %Document{
        id: "did:plc:test",
        verificationMethod: [
          %{
            "id" => "did:plc:test#atproto",
            "type" => "Multikey",
            "controller" => "did:plc:test",
            "publicKeyMultibase" => "zQ3shXjHeiBuRCKmM36cuYnm7YEMzhGnCmCyW92sRJ9pribSF"
          }
        ]
      }

      assert {:ok, key} = Document.get_signing_key(doc)
      assert key["type"] == "Multikey"
      assert String.starts_with?(key["publicKeyMultibase"], "z")
    end

    test "finds atproto key among multiple verification methods" do
      doc = %Document{
        id: "did:plc:test",
        verificationMethod: [
          %{"id" => "did:plc:test#other", "type" => "Other"},
          %{
            "id" => "did:plc:test#atproto",
            "type" => "Multikey",
            "publicKeyMultibase" => "zQ3sh..."
          }
        ]
      }

      assert {:ok, key} = Document.get_signing_key(doc)
      assert String.ends_with?(key["id"], "#atproto")
    end

    test "returns error when no atproto key exists" do
      doc = %Document{
        id: "did:plc:test",
        verificationMethod: [
          %{"id" => "did:plc:test#other", "type" => "Other"}
        ]
      }

      assert {:error, :not_found} = Document.get_signing_key(doc)
    end

    test "returns error when verificationMethod is nil" do
      doc = %Document{id: "did:plc:test", verificationMethod: nil}
      assert {:error, :not_found} = Document.get_signing_key(doc)
    end
  end

  describe "create/2" do
    test "creates document with minimal options" do
      doc = Document.create("did:plc:abc123")

      assert doc.id == "did:plc:abc123"
      assert doc.alsoKnownAs == []
      assert doc.verificationMethod == []
      assert doc.service == []
    end

    test "creates document with handle" do
      doc = Document.create("did:plc:abc123", handle: "alice.example.com")

      assert doc.id == "did:plc:abc123"
      assert doc.alsoKnownAs == ["at://alice.example.com"]
    end

    test "creates document with PDS endpoint" do
      doc = Document.create("did:plc:abc123", pds_endpoint: "https://pds.example.com")

      assert doc.id == "did:plc:abc123"
      assert {:ok, pds} = Document.get_pds_endpoint(doc)
      assert pds == "https://pds.example.com"

      [service] = doc.service
      assert service.id == "#atproto_pds"
      assert service.type == "AtprotoPersonalDataServer"
    end

    test "creates document with signing key" do
      doc =
        Document.create("did:plc:abc123",
          signing_key: "zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn2N"
        )

      assert doc.id == "did:plc:abc123"
      assert {:ok, key} = Document.get_signing_key(doc)
      assert key["id"] == "did:plc:abc123#atproto"
      assert key["type"] == "Multikey"
      assert key["controller"] == "did:plc:abc123"
      assert key["publicKeyMultibase"] == "zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn2N"
    end

    test "creates complete document with all options" do
      doc =
        Document.create("did:plc:abc123",
          handle: "alice.example.com",
          pds_endpoint: "https://pds.example.com",
          signing_key: "zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn2N"
        )

      assert doc.id == "did:plc:abc123"
      assert doc.alsoKnownAs == ["at://alice.example.com"]
      assert {:ok, "https://pds.example.com"} = Document.get_pds_endpoint(doc)
      assert {:ok, _key} = Document.get_signing_key(doc)
    end

    test "accepts custom alsoKnownAs" do
      doc =
        Document.create("did:plc:abc123",
          handle: "alice.example.com",
          also_known_as: ["at://alice.example.com", "https://alice.example.com"]
        )

      assert doc.alsoKnownAs == ["at://alice.example.com", "https://alice.example.com"]
    end
  end

  describe "create_web/2" do
    test "creates did:web document for domain" do
      doc = Document.create_web("example.com")

      assert doc.id == "did:web:example.com"
      assert doc.alsoKnownAs == []
      assert doc.verificationMethod == []
      assert doc.service == []
    end

    test "creates did:web document with signing key" do
      doc =
        Document.create_web("example.com",
          signing_key: "zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn2N"
        )

      assert doc.id == "did:web:example.com"
      assert {:ok, key} = Document.get_signing_key(doc)
      assert key["id"] == "did:web:example.com#atproto"
    end

    test "creates did:web document with service endpoint" do
      doc = Document.create_web("example.com", service_endpoint: "https://example.com")

      assert doc.id == "did:web:example.com"
      assert {:ok, endpoint} = Document.get_pds_endpoint(doc)
      assert endpoint == "https://example.com"
    end

    test "creates did:web document with custom alsoKnownAs" do
      doc =
        Document.create_web("example.com",
          also_known_as: ["at://alice.example.com", "https://alice.example.com"]
        )

      assert doc.alsoKnownAs == ["at://alice.example.com", "https://alice.example.com"]
    end

    test "creates complete did:web document" do
      doc =
        Document.create_web("alice.example.com",
          signing_key: "zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn2N",
          service_endpoint: "https://alice.example.com",
          also_known_as: ["at://alice.example.com"]
        )

      assert doc.id == "did:web:alice.example.com"
      assert doc.alsoKnownAs == ["at://alice.example.com"]
      assert {:ok, _key} = Document.get_signing_key(doc)
      assert {:ok, "https://alice.example.com"} = Document.get_pds_endpoint(doc)
    end
  end

  describe "add_service/2" do
    test "adds service to document" do
      doc = Document.create("did:plc:abc123")

      doc =
        Document.add_service(doc,
          id: "#custom_service",
          type: "CustomService",
          endpoint: "https://custom.example.com"
        )

      assert length(doc.service) == 1
      [service] = doc.service
      assert service.id == "#custom_service"
      assert service.type == "CustomService"
      assert service.serviceEndpoint == "https://custom.example.com"
    end

    test "adds multiple services to document" do
      doc = Document.create("did:plc:abc123")

      doc =
        doc
        |> Document.add_service(
          id: "#atproto_pds",
          type: "AtprotoPersonalDataServer",
          endpoint: "https://pds.example.com"
        )
        |> Document.add_service(
          id: "#appview",
          type: "AtprotoAppView",
          endpoint: "https://appview.example.com"
        )

      assert length(doc.service) == 2
      assert {:ok, "https://pds.example.com"} = Document.get_pds_endpoint(doc)
      assert {:ok, service} = Document.get_service(doc, "AtprotoAppView")
      assert service.serviceEndpoint == "https://appview.example.com"
    end

    test "adds service to document with existing services" do
      doc = Document.create("did:plc:abc123", pds_endpoint: "https://pds.example.com")

      doc =
        Document.add_service(doc,
          id: "#custom",
          type: "CustomService",
          endpoint: "https://custom.example.com"
        )

      assert length(doc.service) == 2
    end

    test "requires all service fields" do
      doc = Document.create("did:plc:abc123")

      assert_raise KeyError, fn ->
        Document.add_service(doc, id: "#test", type: "TestService")
      end
    end
  end

  describe "update_signing_key/2" do
    test "updates signing key in document" do
      doc =
        Document.create("did:plc:abc123",
          signing_key: "zQ3shOldKey"
        )

      doc = Document.update_signing_key(doc, "zQ3shNewKey")

      assert {:ok, key} = Document.get_signing_key(doc)
      assert key["publicKeyMultibase"] == "zQ3shNewKey"
    end

    test "adds signing key to document without one" do
      doc = Document.create("did:plc:abc123")

      doc = Document.update_signing_key(doc, "zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn2N")

      assert {:ok, key} = Document.get_signing_key(doc)
      assert key["publicKeyMultibase"] == "zQ3shZc2QzApp2oymGvQbzP8eKheVshBHbU4ZYjeXqwSKEn2N"
      assert key["id"] == "did:plc:abc123#atproto"
      assert key["type"] == "Multikey"
      assert key["controller"] == "did:plc:abc123"
    end

    test "preserves other document fields" do
      doc =
        Document.create("did:plc:abc123",
          handle: "alice.example.com",
          pds_endpoint: "https://pds.example.com",
          signing_key: "zQ3shOldKey"
        )

      doc = Document.update_signing_key(doc, "zQ3shNewKey")

      assert doc.alsoKnownAs == ["at://alice.example.com"]
      assert {:ok, "https://pds.example.com"} = Document.get_pds_endpoint(doc)
      assert {:ok, key} = Document.get_signing_key(doc)
      assert key["publicKeyMultibase"] == "zQ3shNewKey"
    end
  end
end
