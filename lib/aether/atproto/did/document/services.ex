defmodule Aether.ATProto.DID.Document.Service do
  @moduledoc """
  Represents a service endpoint in a DID Document.
  """

  defstruct [:id, :type, :serviceEndpoint]

  @type t :: %__MODULE__{
          id: String.t(),
          type: String.t(),
          serviceEndpoint: String.t()
        }
end
