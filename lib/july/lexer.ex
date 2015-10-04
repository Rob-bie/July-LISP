defmodule July.Lexer do

  # Breaks up a list of characters into tokens of the form
  # {TYPE, TOKEN, LINE_NUMBER}, where TYPE is an atom.

  # TYPES:
  #        l_paren
  #        r_paren
  #        l_bracket
  #        r_bracket
  #        keyword
  #        symbol
  #        integer
  #        float
  #        boolean
  #        string

  def tokenize(july_input) do
    july_input
    |> to_char_list
    |> tokenize([], 1) # Token accumulator, line number
  end

  # End of input, return tokens
  defp tokenize([], token_acc, _) do
    token_acc |> Enum.reverse
  end

  # Accept left paren
  defp tokenize([?\( |rest], token_acc, line_number) do
    tokenize(rest, [{:l_paren, "(", line_number}|token_acc], line_number)
  end

  # Accept right paren
  defp tokenize([?\) |rest], token_acc, line_number) do
    tokenize(rest, [{:r_paren, ")", line_number}|token_acc], line_number)
  end

  # Accept left bracket
  defp tokenize([?\[ |rest], token_acc, line_number) do
    tokenize(rest, [{:l_bracket, "[", line_number}|token_acc], line_number)
  end

  # Accept right bracket
  defp tokenize([?\] |rest], token_acc, line_number) do
    tokenize(rest, [{:r_bracket, "]", line_number}|token_acc], line_number)
  end  

end
