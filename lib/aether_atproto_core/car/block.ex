defmodule AetherATProtoCore.CAR.Block do
  @moduledoc """
  A single block in a CAR file.

  Each block contains a CID and its associated data.
  """

  defstruct [:cid, :data]

  @type t :: %__MODULE__{
          cid: AetherATProtoCore.CID.t(),
          data: binary()
        }
end
