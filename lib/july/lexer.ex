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

  # EXAMPLE:
  #          (if (< 3 4)
  #            #t
  #            #f)
  #
  #          [{:l_paren, "(", 1}, {:keyword, "if", 1},
  #           {:l_paren, "(", 1}, {:symbol, "<", 1},
  #           {:integer, "3", 1}, {:integer, "4", 1},
  #           {:r_paren, ")", 1}, {:boolean, "#t", 2},
  #           {:boolean, "#f", 3}, {:r_paren, ")", 3}]

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

  # Tokenize a number OR jump to symbol state for symbol "-"
  defp tokenize([c|rest], token_acc, tokens, line_number) when c in '-0123456789' do
    case c do
      ?- ->
        [lookahead|_] = rest
        cond do
          lookahead in '0123456789' ->
            integer_digits(rest, [c|token_acc], tokens, line_number)
          true ->
            symbol_chars(rest, [c|token_acc], tokens, line_number)
        end
      _ ->
        integer_digits(rest, [c|token_acc], tokens, line_number)
    end
  end

  # Tokenize a string
  defp tokenize([?\" |rest], token_acc, tokens, line_number) do
    string_chars(rest, token_acc, tokens, line_number)
  end

  # Tokenize a boolean (#t|#f)
  defp tokenize([?\#, ?t |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:boolean, "#t", line_number}|tokens], line_number)
  end

  defp tokenize([?\#, ?f |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:boolean, "#f", line_number}|tokens], line_number)
  end

  # Tokenize a keyword (q'|'|if|cond|fun|defun|def|let||>|list|import)
  defp tokenize([?q, ?\' |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "q'", line_number}|tokens], line_number)
  end

  defp tokenize([?\' |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "'", line_number}|tokens], line_number)
  end

  defp tokenize([?i, ?f |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "if", line_number}|tokens], line_number)
  end

  defp tokenize([?c, ?o, ?n, ?d |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "cond", line_number}|tokens], line_number)
  end

  defp tokenize([?f, ?u, ?n |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "fun", line_number}|tokens], line_number)
  end

  defp tokenize([?d, ?e, ?f, ?u, ?n |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "defun", line_number}|tokens], line_number)
  end

  defp tokenize([?d, ?e, ?f |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "def", line_number}|tokens], line_number)
  end

  defp tokenize([?l, ?e, ?t |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "let", line_number}|tokens], line_number)
  end

  defp tokenize([?|, ?> |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "|>", line_number}|tokens], line_number)
  end

  defp tokenize([?l, ?i, ?s, ?t |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "list", line_number}|tokens], line_number)
  end

  defp tokenize([?i, ?m, ?p, ?o, ?r, ?t |rest], token_acc, tokens, line_number) do
    tokenize(rest, token_acc, [{:keyword, "import", line_number}|tokens], line_number)
  end

  # Tokenize a symbol
  defp tokenize([c|rest], token_acc, tokens, line_number) do
    symbol_chars(rest, [c|token_acc], tokens, line_number)
  end

  # If a digit is found, prepend it to the token accumulator
  defp integer_digits([c|rest], token_acc, tokens, line_number) when c in '0123456789' do
    integer_digits(rest, [c|token_acc], tokens, line_number)
  end

  # Accept integer (literal or early eof)
  defp integer_digits([], token_acc, tokens, line_number) do
    token = get_token(token_acc)
    tokenize([], [], [{:integer, token, line_number}|tokens], line_number)
  end

  # Accept integer, increment line number
  defp integer_digits([?\n |rest], token_acc, tokens, line_number) do
    token = get_token(token_acc)
    tokenize(rest, [], [{:integer, token, line_number}|tokens], line_number + 1)
  end

  # Accept integer
  defp integer_digits(chars=[c|_], token_acc, tokens, line_number) when c in '[]()\s\r\t' do
    token = get_token(token_acc)
    tokenize(chars, [], [{:integer, token, line_number}|tokens], line_number)
  end

  # If a decimal point is found, jump to float state
  defp integer_digits([c=?\. |rest], token_acc, tokens, line_number) do
    float_digits(rest, [c|token_acc], tokens, line_number)
  end

  # Wasn't an integer, jump to symbol state
  defp integer_digits([c|rest], token_acc, tokens, line_number) do
    symbol_chars(rest, [c|token_acc], tokens, line_number)
  end

  # If a digit is found, prepend it to the token accumulator
  defp float_digits([c|rest], token_acc, tokens, line_number) when c in '0123456789' do
    float_digits(rest, [c|token_acc], tokens, line_number)
  end

  # Accept float (literal or early eof)
  defp float_digits([], token_acc, tokens, line_number) do
    token = get_token(token_acc)
    tokenize([], [], [{:float, token, line_number}|tokens], line_number)
  end

  # Accept float, increment line number
  defp float_digits([?\n |rest], token_acc, tokens, line_number) do
    token = get_token(token_acc)
    tokenize(rest, [], [{:float, token, line_number}|tokens], line_number + 1)
  end

  # Accept float
  defp float_digits(chars=[c|_], token_acc, tokens, line_number) when c in '[]()\s\r\t' do
    token = get_token(token_acc)
    tokenize(chars, [], [{:float, token, line_number}|tokens], line_number)
  end

  # Wasn't a float, jump to symbol state
  defp float_digits([c|rest], token_acc, tokens, line_number) do
    symbol_chars(rest, [c|token_acc], tokens, line_number)
  end

  # Escape sequence support in strings (\"|\n|\t|\r|\\)
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

  # Accept symbol (literal or early eof)
  defp symbol_chars([], token_acc, tokens, line_number) do
    token = get_token(token_acc)
    tokenize([], [], [{:symbol, token, line_number}|tokens], line_number)
  end

  # Accept symbol, increment line number
  defp symbol_chars([?\n |rest], token_acc, tokens, line_number) do
    token = get_token(token_acc)
    tokenize(rest, [], [{:symbol, token, line_number}|tokens], line_number + 1)
  end

  # Accept symbol
  defp symbol_chars(chars=[c|_], token_acc, tokens, line_number) when c in '[]()\s\r\t' do
    token = get_token(token_acc)
    tokenize(chars, [], [{:symbol, token, line_number}|tokens], line_number)
  end

  # If any other character is found, prepend to token accumulator
  defp symbol_chars([c|rest], token_acc, tokens, line_number) do
    symbol_chars(rest, [c|token_acc], tokens, line_number)
  end

  # Convert a token accumulator to a string
  defp get_token(token_acc), do: Enum.reverse(token_acc) |> to_string

end
