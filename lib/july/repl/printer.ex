defmodule July.Repl.Printer do

  # Converts July output to their appropriate string representation.

  # EXAMPLE:
  #          [1, 2, 3]   => (1 2 3)
  #         :july_symbol => 'july_symbol
  #          "july_str"  => "july_str"
  #              1       => 1
  #            -12.3     => -12.3

  def convert(list) when is_list(list) do
    case length(list) > 25 do
      true  ->
        truncated_list = Enum.take(25)
        "(#{Enum.map(truncated_list, &convert/1) |> Enum.join(" ")} ...)"
      false ->
        "(#{Enum.map(list, &convert/1) |> Enum.join(" ")})"
    end
  end

  def convert(true),  do: "#t"
  def convert(false), do: "#f"

  def convert(symbol) when is_atom(symbol) do
    "'#{symbol |> to_string}"
  end

  def convert(func) when is_function(func) do
    "#<july-function>"
  end

  def convert(%{closure: _}) do
    "#<july-closure>"
  end

  def convert(string) when is_binary(string) do
    "\"#{string}\""
  end

  def convert(other) do
    other |> to_string
  end

end
