defmodule July.Stdlib.Coll do

  defp coll do
    %{
      "rev"   => %{function: &Enum.reverse/1},
      "sum"   => %{function: &Enum.sum/1},
      "join1" => %{function: &Enum.join/1},
      "join2" => %{function: &Enum.join/2}
     }
  end

  def import_coll do
    coll_july_source = File.read!("./lib/july/stdlib/coll.july")
    {_, coll_july_env} = July.Evaluator.eval(coll_july_source)
    Dict.merge(coll(), coll_july_env)
  end

end
