defmodule July.Stdlib.Inou do

  defp inou do
    %{
       "read-file" => %{function: &File.read!/1}
     }
  end

  def import_inou do
    inou()
  end

end
