#!/usr/bin/env elixir

defmodule DocChecker do
  def check do
    lib_files = Path.wildcard("lib/**/*.ex")
    |> Enum.reject(&String.contains?(&1, "_test.ex"))
    
    results = Enum.map(lib_files, &analyze_file/1)
    |> Enum.reject(&(&1 == nil))
    
    missing_docs = Enum.filter(results, fn {_, _, missing, _} -> length(missing) > 0 end)
    
    IO.puts("API Documentation Report")
    IO.puts("=" |> String.duplicate(50))
    
    if length(missing_docs) > 0 do
      IO.puts("\nModules with missing documentation:")
      Enum.each(missing_docs, fn {file, has_moduledoc, missing_funcs, _} ->
        module = Path.basename(file, ".ex") |> Macro.camelize()
        IO.puts("\n#{module} (#{file})")
        unless has_moduledoc, do: IO.puts("  - Missing @moduledoc")
        Enum.each(missing_funcs, fn func -> 
          IO.puts("  - Missing @doc for: #{func}")
        end)
      end)
    end
    
    total_modules = length(results)
    modules_with_moduledoc = Enum.count(results, fn {_, has_doc, _, _} -> has_doc end)
    total_public_funcs = results |> Enum.map(fn {_, _, _, funcs} -> length(funcs) end) |> Enum.sum()
    documented_funcs = total_public_funcs - (missing_docs |> Enum.map(fn {_, _, missing, _} -> length(missing) end) |> Enum.sum())
    
    IO.puts("\nSummary:")
    IO.puts("Modules with @moduledoc: #{modules_with_moduledoc}/#{total_modules}")
    IO.puts("Functions with @doc: #{documented_funcs}/#{total_public_funcs}")
    IO.puts("Coverage: #{Float.round(documented_funcs / max(total_public_funcs, 1) * 100, 1)}%")
  end
  
  defp analyze_file(file) do
    content = File.read!(file)
    
    # Skip generated files or test support
    return_nil = String.contains?(content, "@moduledoc false") || 
                 String.contains?(content, "# Generated") ||
                 String.contains?(file, "/test/")
    
    if return_nil do
      nil
    else
      has_moduledoc = Regex.match?(~r/@moduledoc\s+("""|\"|')/, content)
      
      # Find public functions
      public_funcs = Regex.scan(~r/^\s*def\s+([a-z_][a-z0-9_!?]*)/m, content)
      |> Enum.map(fn [_, name] -> name end)
      |> Enum.reject(&String.starts_with?(&1, "_"))
      
      # Find documented functions
      doc_pattern = ~r/@doc\s+(?:"""[^"]*"""|"[^"]*")\s*(?:@spec[^\n]*\n)?\s*def\s+([a-z_][a-z0-9_!?]*)/ms
      documented_funcs = Regex.scan(doc_pattern, content)
      |> Enum.map(fn [_, name] -> name end)
      
      missing_docs = public_funcs -- documented_funcs
      
      {file, has_moduledoc, missing_docs, public_funcs}
    end
  end
end

DocChecker.check()