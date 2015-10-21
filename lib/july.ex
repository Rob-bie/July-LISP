defmodule July do

  # July's main module.
  # Invoked with zero arguments: Start REPL
  # Invoked with one argument: Treat as path, evaluate file
  # Invoked with >two arguments: Throw error

  def main(args) do
    process_args(args)

  catch
    {:error, message} -> IO.puts(message)
  end

  defp process_args(args) do
    case args do
      []     ->
        July.Repl.JulyRepl.start_repl
      [path] ->
        case String.ends_with?(path, ".july") do
          true  ->
            content = File.read(path)
            case content do
              {:error, _}    ->
                throw({:error, "ERR: Invalid path"})
              {:ok, content} ->
                {result, _} = July.Evaluator.eval(content)
                result
                |> July.Repl.Printer.convert
                |> IO.puts
            end
          false ->
            throw({:error, "ERR: File must have extension \".july\""})
        end
      _ ->
        throw({:error, "ERR: Bad arguments, expecting no arguments or path"})
    end
  end

end
