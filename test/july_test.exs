defmodule JulyTest do
  use ExUnit.Case
  doctest July

  test "Tokenize parens and brackets" do
    input = "[()]"
    output = [{:l_bracket, "[", 1}, {:l_paren, "(", 1},
              {:r_paren, ")", 1}, {:r_bracket, "]", 1}]

    assert July.Lexer.tokenize(input) == output
  end

  test "Tokenize input with various whitespace" do
    input = "    ( \r\t\n )\n"
    output = [{:l_paren, "(", 1}, {:r_paren, ")", 2}]

    assert July.Lexer.tokenize(input) == output
  end

end
