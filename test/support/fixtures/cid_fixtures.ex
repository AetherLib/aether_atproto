defmodule AetherATProtoCore.CIDFixtures do
  @moduledoc """
  Test fixtures for CID testing.
  """

  def cid_v0 do
    "QmY7Yh4UquoXHLPFo2XbhXkhBvFoPwmQUSa92pxnxjQuPU"
  end

  def cid_v1_base32 do
    "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"
  end

  def cid_v1_base58 do
    "zdj7WkLmG2I5E5NTd2y1Hy2fx2c3nK1cC1NvJZ7kY7fYx1cYq"
  end

  def invalid_cids do
    [
      "invalid",
      "QmTooShort",
      # Too long for v0
      "Qm" <> String.duplicate("a", 50),
      "",
      # base32 should be lowercase
      "bmixedcase",
      "Qminvalidchars!!"
    ]
  end
end
