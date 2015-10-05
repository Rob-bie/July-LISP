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

  test "Tokenize input with integers and floats" do
    input = "(-12\n\n-65.323 (12.3))"
    output = [{:l_paren, "(", 1}, {:integer, "-12", 1},
              {:float, "-65.323", 3}, {:l_paren, "(", 3},
              {:float, "12.3", 3}, {:r_paren, ")", 3},
              {:r_paren, ")", 3}]

    assert July.Lexer.tokenize(input) == output
  end

  test "Tokenize string with escape sequences" do
    input = "(\"st\\\na\\\"aaar\")"
    output = [{:l_paren, "(", 1}, {:string, "st\na\"aaar", 1},
              {:r_paren, ")", 1}]

    assert July.Lexer.tokenize(input) == output
  end

  test "Tokenize input with symbols" do
    input = "(-13.4a <= \"str\" -13.4)"
    output = [{:l_paren, "(", 1}, {:symbol, "-13.4a", 1},
              {:symbol, "<=", 1}, {:string, "str", 1},
              {:float, "-13.4", 1}, {:r_paren, ")", 1}]

    assert July.Lexer.tokenize(input) == output
  end

end
