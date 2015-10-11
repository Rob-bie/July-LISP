defmodule July.Evaluator do

  # Evaluates July expressions

  def eval(july_input) do
    July.Parser.parse(july_input)
    |> eval_all(July.Stdlib.Core.core) # Core is the default, outermost environment
  end

  # For evaluating inside of REPL environment
  def eval(july_input, env, :repl) do
    July.Parser.parse(july_input)
    |> eval_all(env)
  end

  # Evaluates a sequence of expressions
  defp eval_all(expressions, env) do
    eval_block = fn(expression, acc) ->
      res = eval(expression, acc.env)
      case res do
        closure=%{params: _, body: _, closure: _} ->
          %{value: closure, env: acc.env}
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
  defp eval([{:keyword, "def", line_number}|rest], env) do
    arg_length = length(rest)
    case arg_length do
      2 ->
        [variable, value] = rest
        case variable do
          {:symbol, variable, _} ->
            Dict.put(env, variable, eval(value, env))
          _ ->
            :to_doa # Throw error here (def must be of the form: <def> <symbol> <val>)
        end
      _ ->
        :to_dob # Throw errror here (invalid argument quantity passed to <def>)
    end
  end

  # Evaluate if
  defp eval([{:keyword, "if", line_number}|rest], env) do
    [expr, truthy, falsy] = rest
    case eval(expr, env) do
      true  -> eval(truthy, env)
      false -> eval(falsy, env)
      _     -> :to_doc # Throw error here (expression must evaluate to boolean value)
    end
  end

  # Evaluate cond, short circuit when truthy expression is found
  defp eval([{:keyword, "cond", line_number}|rest], env) do
    [[_, truthy]|_] = Enum.drop_while(rest, fn(p) -> eval(hd(p), env) != true end)
    eval(truthy, env)
  end

  # Evaluate fn, return function parameters, body and scope
  defp eval([{:keyword, "fn", line_number}|rest], env) do
    [parameters, body] = rest
    %{params: parameters, body: body, closure: env}
  end

  # Evaluate q (quote), return following as literal
  defp eval([{:keyword, "q'", line_number}, rest], _) do
    unpack(rest, [])
  end

  # Look up symbol and return value
  defp eval({:symbol, symbol, line_number}, env) do
    value = lookup_symbol(symbol, env)
    case value do
      nil ->
        :to_doe # Throw error here (symbol not defined or not in scope)
      _   -> value
    end
  end

  # Evaluate a function and return it's result
  defp eval([function|args], env) do
    result = eval(function, env)
    cond do
      is_function(result) -> # Built-in function found
        args = for arg <- args, do: eval(arg, env)
        apply(result, args)
      is_map(result) -> # User defined function found
        args = for arg <- args, do: eval(arg, env)
        params = for param <- result.params, do: elem(param, 1)
        closure = Enum.zip(params, args) |> Enum.into(Map.merge(result.closure, env))
        eval(result.body, closure)
      true ->
        :to_dof # Throw error here (expected function)
    end
  end

  # Return literal
  defp eval({:string, literal, _}, _), do: literal
  defp eval({literal, _}, _),  do: literal
  defp eval(literal, _), do: literal

  # Unpack values for quote
  defp unpack([], acc), do: Enum.reverse(acc)

  defp unpack({:symbol, symbol, _}, _),   do: String.to_atom(symbol)
  defp unpack({:string, string, _}, _),   do: string
  defp unpack({:keyword, keyword, _}, _), do: keyword
  defp unpack({literal,  _}, _),          do: literal

  defp unpack(list, acc) do
    Enum.map(list, &unpack(&1, []))
  end

  # Look up a symbol starting in the innermost
  # environment, return nil if not found
  defp lookup_symbol(_, nil), do: nil

  defp lookup_symbol(symbol, env) do
    case Dict.has_key?(env, symbol) do
      true  -> env[symbol]
      false -> lookup_symbol(symbol, env[:outer])
    end
  end

end
