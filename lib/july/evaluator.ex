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
        closure=%{bodies: _, closure: _} ->
          %{value: closure, env: acc.env}
        %{function: function} ->
          %{value: function, env: acc.env}
        res when is_map(res) ->
          %{value: acc.value, env: res}
        :ok -> # Ignore IO
          %{value: acc.value, env: acc.env}
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
    case res=eval(expr, env) do
      true  -> eval(truthy, env)
      false -> eval(falsy, env)
      _     ->
        throw({:error, "ERR: <if> condition must evaluate to type <bool> but got <#{res}> "
                    <> "<line: #{line_number}>"})
    end
  end

  # Evaluate cond, short circuit when truthy expression is found
  # Body is evaluated inside of a new scope
  defp eval([{:keyword, "cond", line_number}|rest], env) do
    truthy = Enum.drop_while(rest, fn(p) -> eval(hd(p), env) != true end)
    case truthy do
      [] ->
        throw({:error, "ERR: No <cond> clause evaluated to <#t> "
                    <> "<line: #{line_number}>"})
      _  ->
        [[_|truthy]|_] = truthy
        {result, _} = eval_all(truthy, env)
        result
    end
  end

  # Evaluate let, create a new scope with bindings
  defp eval([{:keyword, "let", line_number}|rest], env) do
    [bindings|body] = rest
    bind = fn(binding, acc) ->
      [{:symbol, symbol, _}, value] = binding
      Dict.put(acc, symbol, eval(value, acc))
    end
    new_scope = Enum.reduce(bindings, env, bind)
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
  # A symbol following the import keyword indicates a built-in
  # library, a string indicates a path to an external July library
  defp eval([{:keyword, "import", line_number}, july_import], env) do
    import_name = eval(july_import, env)
    import_type = if is_atom(import_name), do: :builtin, else: :external
    case import_type do
      :builtin  ->
        case import_name do
          :math -> Dict.merge(env, July.Stdlib.Math.import_math)
          :coll -> Dict.merge(env, July.Stdlib.Coll.import_coll)
          :str  -> Dict.merge(env, July.Stdlib.Str.import_str)
          _ ->
            import_name = import_name |> to_string
            throw({:error, "ERR: <#{import_name}> is not a valid "
                        <> "stdlib module, did you mean (import \"#{import_name}.july\")?"})
        end
      :external ->
        :to_do
    end
  end

  # Evaluate fun, return function parameters, body and scope
  defp eval([{:keyword, "fun", line_number}|rest], env) do
    [parameters, body] = rest
    %{params: parameters, body: body, closure: env, line_number: line_number}
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
        throw({:error, "ERR: Symbol <#{symbol}> undefined or out of scope <line: #{line_number}>"})
      _   -> value
    end
  end

  # Catch error when function is expected but passed a value
  defp eval([{type, value, line_number}|_], _) when type != :symbol do
    throw({:error, "ERR: Expected function but got <#{value}> <line: #{line_number}>"})
  end

  defp eval([{value, line_number}|_], _) do
    throw({:error, "ERR: Expected function but got <#{value}> <line: #{line_number}>"})
  end

  # Evaluate a function and return it's result
  defp eval([function|args], env) do

    fun_information = fn
      {:symbol, name, line_number} -> {"<#{name}>", line_number}
      _ -> {"#<july-closure>", :ignore}
    end

    {name, line_number} = fun_information.(function)

    try do
      result = eval(function, env)
      case result do
        %{function: func, variadic: true} -> # Built-in function (variadic)
          args = for arg <- args, do: eval(arg, env)
          func.(args)
        %{function: func} -> # Built-in function (non-variadic)
          {:arity, arity} = :erlang.fun_info(func, :arity)
          case length(args) != arity do
            true  ->
              throw({:error, "ERR: #{name} called with <#{length(args)}> arguments "
                          <> "but expected <#{arity}> <line: #{line_number}>"})
            false ->
              args = for arg <- args, do: eval(arg, env)
              apply(func, args)
          end
        %{params: params, body: body, closure: closure, line_number: line_number} -> # fun
          case length(params) != length(args) do
            true  ->
              throw({:error, "ERR: #{name} called with <#{length(args)}> arguments "
                          <> "but expected <#{length(params)}> <line: #{line_number}>"})
            false ->
              args = for arg <- args, do: eval(arg, env)
              params = for param <- params, do: elem(param, 1)
              closure = Enum.zip(params, args) |> Enum.into(Dict.merge(closure, env))
              eval(body, closure)
          end
        %{bodies: bodies, closure: closure} -> # defun
          match = Enum.drop_while(bodies, fn(body) -> length(args) != length(hd(body)) end)
          case match do
            [] ->
              arities = Enum.map(bodies, fn(body) -> length(hd(body)) end)
              arities = "<#{Enum.join(arities, ",")}>"
              throw({:error, "ERR: #{name} called with <#{length(args)}> arguments "
                          <> "but expected #{arities} <line: #{line_number}>"})
            _  ->
              [match|_] = match
              [params|bodies] = match
              args = for arg <- args, do: eval(arg, env)
              params = for param <- params, do: elem(param, 1)
              closure = Enum.zip(params, args) |> Enum.into(Dict.merge(closure, env))
              eval_all(bodies, closure)
          end
       _ ->

            throw({:error, "ERR: bad argument(s) in #{name} "
                     <> "<line: #{line_number}>"})
      end
    rescue
      _ in ArithmeticError -> throw({:error, "ERR: bad argument(s) in #{name} "
                                          <> "<line: #{line_number}>"})
      _ in ArgumentError   -> throw({:error, "ERR: bad argument(s) in #{name} "
                                          <> "<line: #{line_number}>"})
    end
  end

  # Return literal
  defp eval({:string, literal, _}, _), do: literal
  defp eval({literal, _}, _),          do: literal
  defp eval(literal, _),               do: literal

  # Unpack values for quote
  defp unpack([], acc), do: Enum.reverse(acc)

  defp unpack({:symbol, symbol, _}, _),   do: String.to_atom(symbol)
  defp unpack({:string, string, _}, _),   do: string
  defp unpack({:keyword, keyword, _}, _), do: keyword
  defp unpack({literal,  _}, _),          do: literal

  defp unpack(list, _) do
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
