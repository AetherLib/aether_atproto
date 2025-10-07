defmodule Aether.ATProto.CAR.Block do
  @moduledoc """
  A single block in a CAR file.

  Each block contains a CID and its associated data.
  """

  defstruct [:cid, :data]

  @type t :: %__MODULE__{
          cid: Aether.ATProto.CID.t(),
          data: binary()
        }
end
