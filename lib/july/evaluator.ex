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
  # Body is evaluated inside of a new scope
  defp eval([{:keyword, "cond", line_number}|rest], env) do
    [[_|truthy]|_] = Enum.drop_while(rest, fn(p) -> eval(hd(p), env) != true end)
    {result, _} = eval_all(truthy, create_scope(env))
    result
  end

  # Evaluate let, create a new scope with bindings
  defp eval([{:keyword, "let", line_number}|rest], env) do
    [bindings|body] = rest
    bind = fn(binding, acc) ->
      [{:symbol, symbol, _}, value] = binding
      Dict.put(acc, symbol, eval(value, acc))
    end
    new_scope = Enum.reduce(bindings, create_scope(env), bind)
    {result, _} = eval_all(body, new_scope)
    result
  end

  # Evaluate |>, transforms AST such that the result of each
  # function is passed as the first argument to the next function
  # in the pipeline
  defp eval([{:keyword, "|>", line_number}|rest], env) do
    combine = fn(expr, acc) ->
      [function|args] = expr
      [function, acc] ++ args
    end
    [initial_value|rest] = rest
    pipeline = Enum.reduce(rest, initial_value, combine)
    eval(pipeline, env)
  end

  # Evaluate list, differs from quote in that elements are
  # evaluated instead of returned literally
  defp eval([{:keyword, "list", line_number}|rest], env) do
    case rest do
      [] -> []
      _  -> Enum.map(rest, &eval(&1, env))
    end
  end

  # Evaluate import, return corresponding environment
  # A symbol following import keywords indicates a built-in
  # library, a string indicates a path to an external July library
  defp eval([{:keyword, "import", line_number}, july_import], env) do
    import_name = eval(july_import, env)
    import_type = if is_atom(import_name), do: :builtin, else: :external
    case import_type do
      :builtin  ->
        case import_name do
          :math -> Dict.merge(env, July.Stdlib.Math.math)
        end
      :external ->
        :to_do
    end
  end

  # Evaluate fun, return function parameters, body and scope
  defp eval([{:keyword, "fun", line_number}|rest], env) do
    [parameters, body] = rest
    %{params: parameters, body: body, closure: env}
  end

  # Evaluate defun, insert function into current environment
  defp eval([{:keyword, "defun", line_number}|rest], env) do
    [{:symbol, variable, _}|bodies] = rest
    val = %{bodies: bodies, closure: env}
    Dict.put(env, variable, val)
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
    case result do
      built_in=%{function: function} -> # Built-in function
        case built_in[:variadic] do
          true ->
            args = for arg <- args, do: eval(arg, env)
            function.(args)
          _    ->
            args = for arg <- args, do: eval(arg, env)
            apply(function, args)
        end
      %{params: params, body: body, closure: closure} -> # fun
        args = for arg <- args, do: eval(arg, env)
        params = for param <- params, do: elem(param, 1)
        closure = Enum.zip(params, args) |> Enum.into(Map.merge(closure, env))
        eval(body, closure)
      %{bodies: bodies, closure: closure} -> # defun
        [match|_] = Enum.drop_while(bodies, fn(body) -> length(args) != length(hd(body)) end)
        [params, body] = match
        args = for arg <- args, do: eval(arg, env)
        params = for param <- params, do: elem(param, 1)
        closure = Enum.zip(params, args) |> Enum.into(Map.merge(closure, env))
        eval(body, closure)
      _ ->
        :to_dof # Throw error here (expected function)
    end
  end

  # Return literal
  defp eval({:string, literal, _}, _), do: literal
  defp eval({literal, _}, _),          do: literal
  defp eval(literal, _),               do: literal

  # Create a new scope for explicit and implicit *do blocks
  # * Do has not been implemented yet
  defp create_scope(env), do: %{outer: env}
 
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
