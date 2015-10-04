defmodule JulyTest do
  use ExUnit.Case
  doctest July

  test "Tokenize parens and brackets" do
    input = "[()]"
    output = [{:l_bracket, "[", 1}, {:l_paren, "(", 1},
              {:r_paren, ")", 1}, {:r_bracket, "]", 1}]

    assert July.Lexer.tokenize(input) == output
  end

end
