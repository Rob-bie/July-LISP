defmodule July.Evaluator do

  # Evaluates July expressions

  def eval(july_input) do
    July.Parser.parse(july_input)
    |> eval_all(July.Stdlib.Core.core) # Core is the default, outermost environment
  end

  # Evaluates a sequence of expressions
  defp eval_all(expressions, env) do
    eval_block = fn(expression, acc) ->
      res = eval(expression, acc.env)
      case res do
        res when is_map(res) ->
          %{value: acc.value, env: res}
        _ ->
          %{value: res, env: acc.env}
      end
    end
    result = Enum.reduce(expressions, %{value: :void, env: env}, eval_block)
    {result.value, result.env}
  end

  # Evaluate def, insert variable and value into current environment
  defp eval([{:symbol, "def", line_number}|rest], env) do
    arg_length = length(rest)
    case arg_length do
      2 ->
        [variable, value] = rest
        case variable do
          {:symbol, variable, _} ->
            Dict.put(env, variable, eval(value, env))
          _ ->
            :to_do # Throw error here (def must be of the form: <def> <symbol> <val>)
        end
      _ ->
        :to_do # Throw errror here (invalid argument quantity passed to <def>)
    end
  end

  # Evaluate fn, return function parameters and body
  defp eval([{:keyword, "fn", line_number}|rest], env) do
    [parameters, body] = rest
    %{params: parameters, body: body}
  end

  # Look up symbol and return value
  defp eval({:symbol, symbol, line_number}, env) do
    value = lookup_symbol(symbol, env)
    case value do
      nil -> :to_do # Throw error here (symbol not defined or not in scope)
      _   -> value
    end
  end

  defp eval([function={:symbol, symbol, line_number}|args], env) do
    result = eval(function, env)
    cond do
      is_function(result) ->
        args = for arg <- args, do: eval(arg, env)
        apply(result, args)
      is_map(result) ->
        args = for arg <- args, do: eval(arg, env)
        params = for param <- result.params, do: elem(param, 1)
        inner = Enum.zip(params, args) |> Enum.into(%{}) |> Dict.put(:outer, env)
        eval(result.body, inner)
      true ->
        result
    end
  end

  # Return literal
  defp eval({literal, _}, _), do: literal
  defp eval(literal, _),      do: literal

  # Look up a symbol starting in the innermost
  # environment, if it is not found return nil
  defp lookup_symbol(_, nil), do: nil

  defp lookup_symbol(symbol, env) do
    case Dict.has_key?(env, symbol) do
      true  -> env[symbol]
      false -> lookup_symbol(symbol, env[:outer])
    end
  end

end
