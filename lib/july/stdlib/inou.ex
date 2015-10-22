defmodule July.Stdlib.Inou do

  defp inou do
    %{
       "read-file"  => %{function: &File.read!/1},
       "read-input" => %{function: &(IO.gets(&1) |> String.strip)},
       "dir?"       => %{function: &Elixir.IEx.Helpers.pwd/0}
     } 
  end

  def import_inou do
    inou()
  end

end
