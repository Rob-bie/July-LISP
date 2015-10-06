defmodule July.Stdlib.Core do

  # Core is the default environment that contains standard
  # July functions.

  def core do
    %{
      "+" => &(&1 + &2),
      "-" => &(&1 - &2),
      "*" => &(&1 * &2),
      "/" => &(&1 / &2),
      "<" => &(&1 < &2),
      ">" => &(&1 > &2)
     }
  end

end
