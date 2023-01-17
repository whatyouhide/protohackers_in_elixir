defmodule Protohackers.MITM.Boguscoin do
  @tonys_address "7YWHMfk9JZe0LM0g1ZauHuiSxhI"

  def rewrite_addresses(string) when is_binary(string) do
    regex = ~r/(^|\s)\K(7[[:alnum:]]{25,34})(?= [^[:alnum:]]|\s|$)/
    Regex.replace(regex, string, @tonys_address)
  end
end
