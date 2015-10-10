defmodule July.Parser do

  # Converts a list a tokens into an AST, token values are converted
  # to their native types during this phase. Discards type information
  # but preserves line numbers. The only exceptions to this rule are
  # symbols, strings and keywords. (Solely for differentiating them)

  # EXAMPLE:
  #          (+ 1
  #            (+ 2
  #              (+ 3 4)))
  #
  #          [{:symbol, "+", 1}, {1, 1},
  #           [{:symbol, "+", 2},  2, 2},
  #            [{:symbol, "+", 3}, {3, 3}, {4, 3}]]]

  def parse(july_input) do
    July.Lexer.tokenize(july_input)
    |> parse([], []) # Accumulator, stack to match brackets/parens
  end

  defp parse([], acc, _), do: acc |> Enum.reverse

  # Open paren found, parse and insert expression into AST
  defp parse([paren={:l_paren, _, line_number}|rest], acc, lb_stack) do
    case parse(rest, [], [paren|lb_stack]) do
      {remainder, list} -> parse(remainder, [list|acc], lb_stack)
      _ ->
        :to_do # Throw error here (parens not balanced)
    end
  end

  # Closing paren found, return parsed expression
  defp parse([{:r_paren, _, _}|rest], acc, lb_stack) do
    case lb_stack do
      [{:l_paren, _, _}|_] -> {rest, acc |> Enum.reverse}
      [{_, bad_token, line_number}|_] ->
        :to_do # Throw error here (mismatched brackets/parens)
      [] ->
        :to_do # Throw error here (extra trailing paren or missing leading)
    end
  end

  # Open bracket found, parse and insert expression into AST
  defp parse([bracket={:l_bracket, _, line_number}|rest], acc, lb_stack) do
    case parse(rest, [], [bracket|lb_stack]) do
      {remainder, list} -> parse(remainder, [list|acc], lb_stack)
      _ ->
        :to_do # Throw error here (brackets not balanced)
    end
  end

  # Closing bracket found, return parsed expression
  defp parse([{:r_bracket, _, _}|rest], acc, lb_stack) do
    case lb_stack do
      [{:l_bracket, _, _}|_] -> {rest, acc |> Enum.reverse}
      [{_, bad_token, line_number}|_] ->
        :to_do # Throw error here (mismatched brackets/parens)
      [] ->
        :to_do # Throw error here (extra trailing bracket or missing leading)
    end
  end

  # Expands ' to (q' ...)
  defp parse([{:keyword, "'", line_number}|rest], acc, lb_stack) do
    list = [lookahead|remainder] = rest
    quote_body = [{:keyword, "q'", line_number}]
    case lookahead do
      {:l_paren, _, _} ->
        {parse_rem, quote_list} = parse(remainder, [], [lookahead|lb_stack])
        parse(parse_rem, [quote_body ++ [quote_list]|acc], lb_stack)
      {:l_bracket, _, _} ->
        {parse_rem, quote_list} = parse(remainder, [], [lookahead|lb_stack])
        parse(parse_rem, [quote_body ++ [quote_list]|acc], lb_stack)
      _ ->
        converted_token = convert_type(lookahead)
        parse(remainder, [quote_body ++ [converted_token]|acc], lb_stack)
    end
  end
  
  # Convert other tokens to their respective types and insert into AST
  defp parse([token|rest], acc, lb_stack) do
    converted_token = convert_type(token)
    parse(rest, [converted_token|acc], lb_stack)
  end

  # Converts token values to their native Elixir types
  defp convert_type({:boolean, "#t", line_number}) do
    {true, line_number}
  end

  defp convert_type({:boolean, "#f", line_number}) do
    {false, line_number}
  end

  defp convert_type({:integer, value, line_number}) do
    value = String.to_integer(value)
    {value, line_number}
  end

  defp convert_type({:float, value, line_number}) do
    value = String.to_float(value)
    {value, line_number}
  end

  # Simply return the token if it doesn't require conversion
  defp convert_type(token), do: token

end
