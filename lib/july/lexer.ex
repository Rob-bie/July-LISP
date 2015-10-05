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
    |> tokenize([], [], 1) # Token accumulator, tokens, line number
  end

  # End of input, return tokens
  defp tokenize([], _, tokens, _) do
    tokens |> Enum.reverse
  end

  # Ingore newline, increment line number
  defp tokenize([?\n |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, tokens, line_number + 1)
  end

  # Ingore all other whitespace
  defp tokenize([c|rest], token_acc, tokens, line_number) when c in '\s\r\t' do
    tokenize(rest, token_acc, tokens, line_number)
  end

  # Accept left paren
  defp tokenize([?\( |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:l_paren, "(", line_number}|tokens], line_number)
  end

  # Accept right paren
  defp tokenize([?\) |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:r_paren, ")", line_number}|tokens], line_number)
  end

  # Accept left bracket
  defp tokenize([?\[ |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:l_bracket, "[", line_number}|tokens], line_number)
  end

  # Accept right bracket
  defp tokenize([?\] |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:r_bracket, "]", line_number}|tokens], line_number)
  end

  # Tokenize a number
  defp tokenize([c|rest], token_acc, tokens, line_number) when c in '0123456789' do
    integer_digits(rest, [c|token_acc], tokens, line_number)
  end

  # Tokenize a string
  defp tokenize([?\" |rest], token_acc, tokens, line_number) do
    string_chars(rest, token_acc, tokens, line_number)
  end

  # If a digit is found, prepend it to the token accumulator
  defp integer_digits([c|rest], token_acc, tokens, line_number) when c in '0123456789' do
    integer_digits(rest, [c|token_acc], tokens, line_number)
  end

  # Accept integer, increment line number
  defp integer_digits([?\n |rest], token_acc, tokens, line_number) do
    token = get_token(token_acc)
    tokenize(rest, [], [{:integer, token, line_number}|tokens], line_number + 1)
  end

  # Accept integer
  defp integer_digits(chars=[c|_], token_acc, tokens, line_number) when c in '()\s\r\t' do
    token = get_token(token_acc)
    tokenize(chars, [], [{:integer, token, line_number}|tokens], line_number)
  end

  # If a decimal point is found, jump to float state
  defp integer_digits([c=?\. |rest], token_acc, tokens, line_number) do
    float_digits(rest, [c|token_acc], tokens, line_number)
  end

  # Wasn't an integer, jump to symbol state
  defp integer_digits([c|rest], token_acc, tokens, line_number) do
    :to_do
  end

  # If a digit is found, prepend it to the token accumulator
  defp float_digits([c|rest], token_acc, tokens, line_number) when c in '0123456789' do
    float_digits(rest, [c|token_acc], tokens, line_number)
  end

  # Accept float, increment line number
  defp float_digits([?\n |rest], token_acc, tokens, line_number) do
    token = get_token(token_acc)
    tokenize(rest, [], [{:float, token, line_number}|tokens], line_number + 1)
  end

  # Accept float
  defp float_digits(chars=[c|_], token_acc, tokens, line_number) when c in '()\s\r\t' do
    token = get_token(token_acc)
    tokenize(chars, [], [{:float, token, line_number}|tokens], line_number)
  end

  # Wasn't a float, jump to symbol state
  defp float_digits([c|rest], token_acc, tokens, line_number) do
    :to_do
  end

  # Escape sequence support in strings (\", \n, \t, \r, \\)
  defp string_chars([?\\, ?\\ |rest], token_acc, tokens, line_number) do
    string_chars(rest, [?\ |token_acc], tokens, line_number)
  end

  defp string_chars([?\\, ?\" |rest], token_acc, tokens, line_number) do
    string_chars(rest, [?\" |token_acc], tokens, line_number)
  end

  defp string_chars([?\\, ?\n |rest], token_acc, tokens, line_number) do
    string_chars(rest, [?\n |token_acc], tokens, line_number)
  end

  defp string_chars([?\\, ?\t |rest], token_acc, tokens, line_number) do
    string_chars(rest, [?\t |token_acc], tokens, line_number)
  end

  defp string_chars([?\\, ?\r |rest], token_acc, tokens, line_number) do
    string_chars(rest, [?\r |token_acc], tokens, line_number)
  end

  # Accept string
  defp string_chars([?\" |rest], token_acc, tokens, line_number) do
    token = get_token(token_acc)
    tokenize(rest, [], [{:string, token, line_number}|tokens], line_number)
  end

  # If any other character is found, prepend to token accumulator
  defp string_chars([c|rest], token_acc, tokens, line_number) do
    string_chars(rest, [c|token_acc], tokens, line_number)
  end

  # Convert a token accumulator to a string
  defp get_token(token_acc), do: Enum.reverse(token_acc) |> to_string

end
