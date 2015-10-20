defmodule July.Stdlib.Core do

  # Core is the default environment that contains standard
  # July functions. 

  def core do
    %{
      "+"      => %{function: &sum/1, variadic: true},
      "-"      => %{function: &sub/1, variadic: true},
      "*"      => %{function: &mul/1, variadic: true},
      "/"      => %{function: &div/1, variadic: true},
      "<"      => %{function: &(&1 < &2)},
      "<="     => %{function: &(&1 <= &2)},
      ">="     => %{function: &(&1 >= &2)},
      ">"      => %{function: &(&1 > &2)},
      "="      => %{function: &(&1 == &2)},
      "or"     => %{function: &july_or/1, variadic: true},
      "and"    => %{function: &july_and/1, variadic: true},
      "not"    => %{function: &(!&1)},
      "dec"    => %{function: &(&1 - 1)},
      "inc"    => %{function: &(&1 + 1)},
      "head"   => %{function: &hd/1},
      "tail"   => %{function: &tl/1},
      "push"   => %{function: &([&1|&2])},
      "empty?" => %{function: &(&1 == [])},
      "str?"   => %{function: &(is_binary(&1))},
      "num?"   => %{function: &(is_number(&1))},
      "bool?"  => %{function: &(is_boolean(&1))},
      "coll?"  => %{function: &(is_list(&1))},
      "else"   => true
     }
  end

  defp sum(args) do
    Enum.reduce(args, 0, &(&1 + &2))
  end

  defp sub([acc|args]) do
    Enum.reduce(args, acc, &(&2 - &1))
  end

  defp mul([acc|args]) do
    Enum.reduce(args, acc, &(&1 * &2))
  end

  defp div([acc|args]) do
    Enum.reduce(args, acc, &(&2 / &1))
  end

  defp july_and(args) do
    Enum.all?(args, &(&1 == true))
  end

  defp july_or(args) do
    Enum.any?(args, &(&1 == true))
  end
 
end
