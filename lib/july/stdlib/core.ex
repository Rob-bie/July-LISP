defmodule July.Stdlib.Core do

  # Core is the default environment that contains standard
  # July functions.

  def core do
    %{
      "+"      => &(&1 + &2),
      "-"      => &(&1 - &2),
      "*"      => &(&1 * &2),
      "/"      => &(&1 / &2),
      "<"      => &(&1 < &2),
      "<="     => &(&1 <= &2),
      ">="     => &(&1 >= &2),
      ">"      => &(&1 > &2),
      "="      => &(&1 == &2),
      "dec"    => &(&1 - 1),
      "inc"    => &(&1 + 1),
      "head"   => &hd/1,
      "tail"   => &tl/1,
      "push"   => &([&1|&2]),
      "show"   => &IO.puts/1,
      "empty?" => &(&1 == []),
      "else"   => true
     }
  end

end
