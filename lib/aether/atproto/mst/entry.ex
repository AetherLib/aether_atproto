defmodule Aether.ATProto.MST.Entry do
  @moduledoc """
  A single entry in an MST node.

  Entries store a key-value pair, where the value is a CID pointing
  to the actual record data. The key is compressed by storing only
  the suffix after a common prefix.
  """
  alias Aether.ATProto.CID

  defstruct [:key, :value, :tree, prefix_len: 0]

  @type t :: %__MODULE__{
          key: String.t(),
          value: CID.t(),
          tree: CID.t() | nil,
          prefix_len: non_neg_integer()
        }
end
