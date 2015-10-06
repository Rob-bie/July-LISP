defmodule July.Parser do

  # Converts a list a tokens into an AST, token values are converted
  # to their native types during this phase. Discards type information
  # but preserves line numbers. The only exception is symbols and strings,
  # type information is preserved solely to differentiate the two.

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
    |> parse([]) # Accumulator
  end

  defp parse([], acc), do: acc |> Enum.reverse

  # Open paren found, parse and insert expression into AST
  defp parse([{:l_paren, _, _}|rest], acc) do
    {remainder, list} = parse(rest, [])
    parse(remainder, [list|acc])
  end

  # Closing paren found, return parsed expression
  defp parse([{:r_paren, _, _}|rest], acc) do
    {rest, acc |> Enum.reverse}
  end

  # Convert other tokens to their respective types and insert into AST
  defp parse([token|rest], acc) do
    converted_token = convert_type(token)
    parse(rest, [converted_token|acc])
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
