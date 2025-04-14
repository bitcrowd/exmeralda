defmodule Exmeralda.Topics.LineCheck do
  @max_legnth 2000
  def valid?(string) when is_binary(string) do
    length_count(string, 0)
  end

  defp length_count(<<>>, _line_length), do: true

  defp length_count(<<"\n", rest::binary>>, _line_length) do
    length_count(rest, 0)
  end

  defp length_count(<<_char, _rest::binary>>, line_length) when line_length >= @max_legnth do
    false
  end

  defp length_count(<<_char, rest::binary>>, line_length) do
    length_count(rest, line_length + 1)
  end
end
