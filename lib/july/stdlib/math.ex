defmodule July.Stdlib.Math do

  defp math do
    %{
      "mod"   => %{function: &rem/2},
      "div"   => %{function: &div/2},
      "sin"   => %{function: &:math.sin/1},
      "cos"   => %{function: &:math.cos/1},
      "tan"   => %{function: &:math.tan/1},
      "pow"   => %{function: &:math.pow/2},
      "sqrt"  => %{function: &:math.sqrt/1},
      "odd?"  => %{function: &(rem(&1, 2) == 1)},
      "even?" => %{function: &(rem(&1, 2) == 0)},
      "pi"    => :math.pi
     }
  end

  def import_math do
    math()
  end

end
