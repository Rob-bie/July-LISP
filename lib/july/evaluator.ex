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
        :ok -> # Ignore IO return
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
      case binding do
        [{:symbol, symbol, _}, value] ->
          Dict.put(acc, symbol, eval(value, acc))
        [match, value] ->
         case match_list_helper(eval(value, acc), match, acc, %{}) do
           {env, m_env} ->
             Dict.merge(env, m_env)
           :no_match ->
             throw({:error, "ERR: No matching clause for <ERR> <line: #{line_number}>"})
         end
      end
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
    import_type = cond do
      is_atom(import_name)   -> :builtin
      is_binary(import_name) -> :external
      true ->
        throw({:error, "ERR: Expecting stdlib module or path but got <#{import_name}> "
                    <> "<line: #{line_number}>"})
    end

    case import_type do
      :builtin  ->
        case import_name do
          :math -> Dict.merge(env, July.Stdlib.Math.import_math)
          :coll -> Dict.merge(env, July.Stdlib.Coll.import_coll)
          :inou -> Dict.merge(env, July.Stdlib.Inou.import_inou)
          :str  -> Dict.merge(env, July.Stdlib.Str.import_str)
          _ ->
            import_name = import_name |> to_string
            throw({:error, "ERR: <#{import_name}> is not a valid "
                        <> "stdlib module, did you mean (import \"#{import_name}.july\")? "
                        <> "<line: #{line_number}>"})
        end
      :external ->
        case String.ends_with?(import_name, ".july") do
          true  ->
            content = File.read(import_name)
            case content do
              {:error, _}    ->
                throw({:error, "ERR: Invalid path"})
              {:ok, content} ->
                {_, env} = July.Evaluator.eval(content)
                env
            end
          false ->
            throw({:error, "ERR: File must have extension \".july\""})
        end
    end
  end

  # Evaluate fun, return function parameters, body and scope
  defp eval([{:keyword, "fun", line_number}|rest], env) do
    [parameters, body] = rest
    %{params: parameters, body: body, closure: env, line_number: line_number}
  end

  # Evaluate defun, insert function into current environment
  defp eval([{:keyword, "defun", line_number}, {:symbol, var, _}|rest], env) do
    [params|body] = rest
    cond do
      params == [] ->
        val = %{bodies: rest, closure: env}
        Dict.put(env, var, val)
      params |> hd |> is_list ->
        val = %{bodies: rest, closure: env}
        Dict.put(env, var, val)
      true ->
        val = %{bodies: [[params|body]], closure: env} # This is not elegant, change this
        Dict.put(env, var, val)
    end
  end

  # Evaluate match
  defp eval([{:keyword, "match", line_number}, match|rest], env) do
    match_on = eval(match, env)
    cond do
      is_number(match_on)  -> match_literal(match_on, rest, env, line_number)
      is_binary(match_on)  -> match_literal(match_on, rest, env, line_number)
      is_boolean(match_on) -> match_literal(match_on, rest, env, line_number)
      is_atom(match_on)    -> match_literal(match_on, rest, env, line_number)
      is_list(match_on)    -> match_list(match_on, rest, env, line_number)
    end
  end

  # Evaluate q (quote), return following as literal
  defp eval([{:keyword, "q'", line_number}, rest], _) do
    unpack(rest, [])
  end

  # Evaluate show
  defp eval([{:keyword, "show", line_number}|rest], env) do
    expanded = [{:keyword, "<>", line_number}|rest]
    IO.puts(eval(expanded, env))
  end

  # Evaluate <>, convert and concatenate arguments
  defp eval([{:keyword, "<>", line_number}|rest], env) do
    concat = fn(e, acc) ->
      case e do
        {:string, string, _} ->
          acc <> string
        _ ->
          result = eval(e, env) |> July.Repl.Printer.convert
          acc <> result
      end
    end
    Enum.reduce(rest, "", concat)
  end

  # Look up symbol and return value
  defp eval({:symbol, symbol, line_number}, env) do
    value = lookup_symbol(symbol, env)
    case value do
      nil ->
        throw({:error, "ERR: Symbol <#{symbol}> undefined or out of scope "
                    <> "<line: #{line_number}>"})
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
          {params, body} = bind_defun_body(bodies, args, env)
          case {params, body} do
            {:error, "ERR: No match"} ->
              arities = Enum.map(bodies, &hd/1)
              err_arities = fn(body) ->
                variadic? = Enum.any?(body, &(match?({:keyword, "~", _}, &1)))
                case variadic? do
                  true  -> "~#{length(body) - 1}"
                  false -> "#{length(body)}"
                end
              end
              arities = "<#{Enum.map(arities, err_arities) |> Enum.join(",")}>"
              throw({:error, "ERR: #{name} called with <#{length(args)}> arguments "
                          <> "but expected #{arities} <line: #{line_number}>"})
            _ ->
              closure = params |> Enum.into(Dict.merge(closure, env))
              {result, _} = eval_all(body, closure)
              result
          end
        _ ->
            throw({:error, "ERR: bad argument(s) in #{name} "
                     <> "<line: #{line_number}>"})
      end
    rescue
      _ in ArithmeticError -> throw({:error, "ERR: bad argument(s) in #{name} "
                                          <> "<line: #{line_number}>"})
      _ in ArgumentError   ->
        throw({:error, "ERR: bad argument(s) in #{name} "
                                          <> "<line: #{line_number}>"})
    end
  end

  # Return literal
  defp eval({:string, literal, _}, _), do: literal
  defp eval({literal, _}, _),          do: literal
  defp eval(literal, _),               do: literal

  # Match and bind defun args to params
  defp bind_defun_body([], _, _) do
    {:error, "ERR: No match"}
  end

  defp bind_defun_body([[]|body], [], env) do
    {[], body}
  end

  defp bind_defun_body([[params|body]|rest], args, env) do
    variadic? = Enum.any?(params, &(match?({:keyword, "~", _}, &1)))
    case variadic? do
      true  ->
        case (length(params) - 1) <= length(args) do
          true  ->
            params = for param <- params, do: elem(param, 1)
            args = for arg <- args, do: eval(arg, env)
            {bind_variadic(params, args, []), body}
          false ->
            bind_defun_body(rest, args, env)
        end
      false ->
        case length(params) == length(args) do
          true  ->
            args = for arg <- args, do: eval(arg, env)
            params = for param <- params, do: elem(param, 1)
            {Enum.zip(params, args), body}
          false ->
            bind_defun_body(rest, args, env)
        end
    end
  end

  defp bind_variadic([p|params], rest=[a|args], acc) do
    case {p, a} do
      {"~", _} ->
        [p|_] = params
        Enum.reverse([{p, rest}|acc])
      _ ->
        bind_variadic(params, args, [{p, a}|acc])
    end
  end

  # Matching literals in match
  defp match_literal(match_on, [], _, line_number) do
    throw({:error, "ERR: No matching clause for <#{match_on}> <line: #{line_number}>"})
  end

  defp match_literal(match_on, [[e|body]|rest], env, line_number) do
    case e do
      sym=[{:keyword, "q'", _}, _] ->
        match_literal(match_on, [[eval(sym, env)|body]|rest], env, line_number)
      e when is_list(e) ->
        match_literal(match_on, rest, env, line_number)
      {:symbol, "_", _} ->
        {result, _} = eval_all(body, env)
        result
      {:symbol, var, _} ->
        new_env = Dict.put(env, var, match_on)
        {result, _} = eval_all(body, new_env)
        result
      _ ->
        e = eval(e, env)
        case e == match_on do
          true  ->
            {result, _} = eval_all(body, env)
            result
          false ->
            match_literal(match_on, rest, env, line_number)
        end
    end
  end

  defp match_list(match_on, [], _, line_number) do
    throw({:error, "ERR: No matching clause for <#{match_on}> <line: #{line_number}>"})
  end

  defp match_list(match_on, [[e|body]|rest], env, line_number) do
     case match_list_helper(match_on, e, env, %{}) do
       :no_match    ->
         match_list(match_on, rest, env, line_number)
       {env, m_env} ->
         new_env = Dict.merge(env, m_env)
         {result, _} = eval_all(body, new_env)
         result
     end
  end

  defp match_list_helper([], [], env, match_env) do
    {env, match_env}
  end

  defp match_list_helper(_, [], _, _), do: :no_match

  defp match_list_helper([], [{:keyword, "~", _}, {:symbol, var, _}], env, match_env) do
    match_env = Dict.put(match_env, var, [])
    {env, match_env}
  end

  defp match_list_helper([], _, _, _), do: :no_match
  
  defp match_list_helper(match, {:symbol, "_", _}, env, match_env) do
    {env, match_env}
  end

  defp match_list_helper(match, {:symbol, var, _}, env, match_env) do
    match_env = Dict.put(match_env, var, match)
    {env, match_env}
  end

  defp match_list_helper(full=[match|rest], [e|m], env, match_env) do
    case e do
      sym=[{:keyword, "q'", _}, _] ->
        match_list_helper([match|rest], [eval(sym, env)|m], env, match_env)
      e when is_list(e) ->
        list_match = is_list(match) and (length(e) == (length(match)))
        tail_match = is_list(match) and Enum.any?(e, &match?({:keyword, "~", _}, &1))
        cond do
          list_match or tail_match ->
            result = match_list_helper(match, e, env, match_env)
            case result do
              :no_match    -> :no_match
              {env, m_env} -> match_list_helper(rest, m, env, m_env)
            end
          true ->
            :no_match
        end
      {:keyword, "~", _}  ->
        [{:symbol, var, _}|_] = m
        match_env = Dict.put(match_env, var, full)
        {env, match_env}
      {:symbol, "_", _}  ->
        match_list_helper(rest, m, env, match_env)
      {:symbol, var, _}  ->
        case Dict.has_key?(match_env, var) do
          true  ->
            value = Dict.get(match_env, var)
            case match == value do
              true  ->
                match_list_helper(rest, m, env, match_env)
              false ->
                :no_match
            end
          false ->
            match_env = Dict.put(match_env, var, match)
            match_list_helper(rest, m, env, match_env)
        end
      _ ->
        e = eval(e, env)
        case e == match do
          true  ->
            match_list_helper(rest, m, env, match_env)
          false ->
            :no_match
        end
    end
  end

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
