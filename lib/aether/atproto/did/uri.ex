defmodule Aether.ATProto.DID.URI do
  @moduledoc """
  DID fragment validation according to W3C DID Core and RFC3986.
  """

  @doc """
  Checks if a string is a valid DID fragment.
  """
  def is_fragment?(value, start_idx \\ 0, end_idx \\ nil)

  def is_fragment?("", _start_idx, _end_idx), do: true

  def is_fragment?(value, start_idx, nil),
    do: is_fragment?(value, start_idx, String.length(value))

  def is_fragment?(_value, start_idx, end_idx) when start_idx >= end_idx, do: true

  def is_fragment?(value, start_idx, end_idx) do
    value
    |> String.slice(start_idx..(end_idx - 1))
    |> is_fragment_binary?()
  end

  # Base case
  defp is_fragment_binary?(""), do: true

  # Unreserved: ALPHA / DIGIT / "-" / "." / "_" / "~"
  defp is_fragment_binary?(<<char, rest::binary>>) when char in ?A..?Z,
    do: is_fragment_binary?(rest)

  defp is_fragment_binary?(<<char, rest::binary>>) when char in ?a..?z,
    do: is_fragment_binary?(rest)

  defp is_fragment_binary?(<<char, rest::binary>>) when char in ?0..?9,
    do: is_fragment_binary?(rest)

  # "-"
  defp is_fragment_binary?(<<45, rest::binary>>), do: is_fragment_binary?(rest)
  # "."
  defp is_fragment_binary?(<<46, rest::binary>>), do: is_fragment_binary?(rest)
  # "_"
  defp is_fragment_binary?(<<95, rest::binary>>), do: is_fragment_binary?(rest)
  # "~"
  defp is_fragment_binary?(<<126, rest::binary>>), do: is_fragment_binary?(rest)

  # Sub-delims
  # "!"
  defp is_fragment_binary?(<<33, rest::binary>>), do: is_fragment_binary?(rest)
  # "$"
  defp is_fragment_binary?(<<36, rest::binary>>), do: is_fragment_binary?(rest)
  # "&"
  defp is_fragment_binary?(<<38, rest::binary>>), do: is_fragment_binary?(rest)
  # "'"
  defp is_fragment_binary?(<<39, rest::binary>>), do: is_fragment_binary?(rest)
  # "("
  defp is_fragment_binary?(<<40, rest::binary>>), do: is_fragment_binary?(rest)
  # ")"
  defp is_fragment_binary?(<<41, rest::binary>>), do: is_fragment_binary?(rest)
  # "*"
  defp is_fragment_binary?(<<42, rest::binary>>), do: is_fragment_binary?(rest)
  # "+"
  defp is_fragment_binary?(<<43, rest::binary>>), do: is_fragment_binary?(rest)
  # ","
  defp is_fragment_binary?(<<44, rest::binary>>), do: is_fragment_binary?(rest)
  # ";"
  defp is_fragment_binary?(<<59, rest::binary>>), do: is_fragment_binary?(rest)
  # "="
  defp is_fragment_binary?(<<61, rest::binary>>), do: is_fragment_binary?(rest)

  # pchar extra
  # ":"
  defp is_fragment_binary?(<<58, rest::binary>>), do: is_fragment_binary?(rest)
  # "@"
  defp is_fragment_binary?(<<64, rest::binary>>), do: is_fragment_binary?(rest)

  # fragment extra
  # "/"
  defp is_fragment_binary?(<<47, rest::binary>>), do: is_fragment_binary?(rest)
  # "?"
  defp is_fragment_binary?(<<63, rest::binary>>), do: is_fragment_binary?(rest)

  # pct-encoded: "%" HEXDIG HEXDIG - expanded pattern matching for all hex combinations
  # 0-9, 0-9
  defp is_fragment_binary?(<<?%, hex1, hex2, rest::binary>>)
       when hex1 in ?0..?9 and hex2 in ?0..?9,
       do: is_fragment_binary?(rest)

  # 0-9, A-F
  defp is_fragment_binary?(<<?%, hex1, hex2, rest::binary>>)
       when hex1 in ?0..?9 and hex2 in ?A..?F,
       do: is_fragment_binary?(rest)

  # 0-9, a-f
  defp is_fragment_binary?(<<?%, hex1, hex2, rest::binary>>)
       when hex1 in ?0..?9 and hex2 in ?a..?f,
       do: is_fragment_binary?(rest)

  # A-F, 0-9
  defp is_fragment_binary?(<<?%, hex1, hex2, rest::binary>>)
       when hex1 in ?A..?F and hex2 in ?0..?9,
       do: is_fragment_binary?(rest)

  # A-F, A-F
  defp is_fragment_binary?(<<?%, hex1, hex2, rest::binary>>)
       when hex1 in ?A..?F and hex2 in ?A..?F,
       do: is_fragment_binary?(rest)

  # A-F, a-f
  defp is_fragment_binary?(<<?%, hex1, hex2, rest::binary>>)
       when hex1 in ?A..?F and hex2 in ?a..?f,
       do: is_fragment_binary?(rest)

  # a-f, 0-9
  defp is_fragment_binary?(<<?%, hex1, hex2, rest::binary>>)
       when hex1 in ?a..?f and hex2 in ?0..?9,
       do: is_fragment_binary?(rest)

  # a-f, A-F
  defp is_fragment_binary?(<<?%, hex1, hex2, rest::binary>>)
       when hex1 in ?a..?f and hex2 in ?A..?F,
       do: is_fragment_binary?(rest)

  # a-f, a-f
  defp is_fragment_binary?(<<?%, hex1, hex2, rest::binary>>)
       when hex1 in ?a..?f and hex2 in ?a..?f,
       do: is_fragment_binary?(rest)

  # Invalid percent encoding
  defp is_fragment_binary?(<<?%, _rest::binary>>), do: false

  # Any other character is invalid
  defp is_fragment_binary?(<<_char, _rest::binary>>), do: false

  @doc """
  Checks if a character code represents a hex digit (0-9, A-F, a-f).
  """
  def is_hex_digit?(char_code) when char_code in ?0..?9, do: true
  def is_hex_digit?(char_code) when char_code in ?A..?F, do: true
  def is_hex_digit?(char_code) when char_code in ?a..?f, do: true
  def is_hex_digit?(_char_code), do: false
end
