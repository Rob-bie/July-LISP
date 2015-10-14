defmodule July.Repl.JulyRepl do

  # July's REPL, evaluates in it's own environment (default is core)
  # Multi-line expressions are suported.

  def start_repl do
    IO.puts("July REPL")
    IO.puts("(exit) to quit")
    read_input(1, July.Stdlib.Core.core, [], [])
  end

  defp read_input(line_number, repl_env, expr, stack) do
    message = "july@repl(#{line_number})> "
    offset = message |> continuation_offset
    read_next = IO.gets(message)
    case read_next do
      "(exit)\n" ->
        Kernel.exit(:shutdown)
        # System.halt(0) # Use when not testing?
      _ ->
        process_next(read_next |> to_char_list, line_number, repl_env,  [], [], offset)
    end
  end

  # Keep reading from stdin until a complete expression is formed,
  # an expression is considered complete when it is either a literal
  # or parens and brackets are properly matched
  defp process_next([], line_number, repl_env, expr, stack, offset) do
    case stack do
      [] ->
        expr = expr |> Enum.reverse |> to_string
        {result, new_env} = July.Evaluator.eval(expr, repl_env, :repl)
        case result do
          :void -> # Don't display void in REPL
            read_input(line_number + 1, new_env, [], [])
          _ ->
            July.Repl.Printer.convert(result) |> IO.puts
            read_input(line_number + 1, new_env, [], [])
        end
      _ ->
        read_more = IO.gets(offset) |> to_char_list
        process_next(read_more, line_number, repl_env, expr, stack, offset)
    end

  catch
    {:error, message} ->
      IO.puts(message)
      read_input(line_number + 1, repl_env, [], [])
  end

  defp process_next([next|rest], line_number, repl_env, expr, stack, offset) do
    case next do
      ?\( ->
        process_next(rest, line_number, repl_env, [next|expr], [next|stack], offset)
      ?\) ->
        case stack do
          [?\(|stack] -> process_next(rest, line_number, repl_env, [next|expr], stack, offset)
          [?\[|stack] ->
            throw({:error, "ERR: Expecting <]> but got <)>"})
          _ ->
            throw({:error, "ERR: Extra leading paren or missing trailing paren"})
        end
      ?\[ ->
        process_next(rest, line_number, repl_env, [next|expr], [next|stack], offset)
      ?\] ->
        case stack do
          [?\[|stack] -> process_next(rest, line_number, repl_env, [next|expr], stack, offset)
          [?\(|stack] ->
            throw({:error, "ERR: Expecting <)> but got <]>"})
          _ ->
            throw({:error, "ERR: Extra leading bracket or missing trailing bracket"})
        end
      _ ->
        process_next(rest, line_number, repl_env, [next|expr], stack, offset)
    end

  catch
    {:error, message} ->
      IO.puts(message)
      read_input(line_number + 1, repl_env, [], [])
  end

  # Returns the base offset for aligning multi-line expressions in REPL
  defp continuation_offset(message) do
    message
    |> to_char_list
    |> Enum.map((fn(_) -> " " end))
    |> Enum.join
  end

end
