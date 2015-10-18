defmodule July.Stdlib.Str do

  defp str do
    %{
      "split1"     => %{function: &String.split/1},
      "split2"     => %{function: &String.split/2},
      "str->chars" => %{function: &String.codepoints/1},
      "->lower"    => %{function: &String.downcase/1},
      "->upper"    => %{function: &String.upcase/1},
      "contains?"  => %{function: &String.contains?/2},
      "str-len"    => %{function: &String.length/1},
      "strip"      => %{function: &String.strip/1},
      "replace"    => %{function: &String.replace/3},
      "str->num"   => %{function: &str_to_num/1},
     }
  end

  def import_str do
    str_july_source = File.read!("./lib/july/stdlib/str.july")
    {_, str_july_env} = July.Evaluator.eval(str_july_source)
    Dict.merge(str(), str_july_env)
  end

  defp str_to_num(str) do
    case {Integer.parse(str), Float.parse(str)} do
      {{integer, ""}, _}    -> integer
      {{_, _}, {float, ""}} -> float
    end
  end

end
