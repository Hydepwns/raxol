#!/usr/bin/env elixir

defmodule ApiDocGenerator do
  @moduledoc """
  Generates missing API documentation for public modules and functions.
  """
  
  def generate do
    priority_modules = [
      "lib/raxol.ex",
      "lib/raxol/terminal/emulator.ex",
      "lib/raxol/terminal/parser.ex",
      "lib/raxol/ui/components/base/component.ex",
      "lib/raxol/core/renderer.ex",
      "lib/raxol/application.ex"
    ]
    
    Enum.each(priority_modules, &document_module/1)
    IO.puts("Documentation generation complete.")
  end
  
  defp document_module(file) do
    if File.exists?(file) do
      content = File.read!(file)
      module_name = extract_module_name(content)
      
      updated_content = content
      |> ensure_moduledoc(module_name)
      |> add_function_docs(module_name)
      
      if content != updated_content do
        File.write!(file, updated_content)
        IO.puts("Updated: #{file}")
      end
    end
  end
  
  defp extract_module_name(content) do
    case Regex.run(~r/defmodule\s+([\w\.]+)/, content) do
      [_, name] -> name
      _ -> "Module"
    end
  end
  
  defp ensure_moduledoc(content, module_name) do
    if !Regex.match?(~r/@moduledoc/, content) do
      doc = generate_moduledoc(module_name)
      String.replace(content, ~r/(defmodule\s+[\w\.]+\s+do)\n/, "\\1\n#{doc}\n")
    else
      content
    end
  end
  
  defp generate_moduledoc(module_name) do
    base_name = module_name |> String.split(".") |> List.last()
    
    doc = case base_name do
      "Emulator" -> """
        Terminal emulator core functionality.
        Manages terminal state, buffer operations, and ANSI sequence processing.
        """
      "Parser" -> """
        ANSI escape sequence parser.
        Processes terminal input and converts escape sequences to operations.
        """
      "Component" -> """
        Base component behaviour for UI components.
        Defines lifecycle hooks and common functionality.
        """
      "Renderer" -> """
        Core rendering engine.
        Converts component trees to terminal output.
        """
      _ -> """
        #{base_name} module.
        """
    end
    
    "  @moduledoc \"\"\"\n  #{doc}\n  \"\"\""
  end
  
  defp add_function_docs(content, module_name) do
    # Find all public functions without docs
    public_func_pattern = ~r/^(\s*)def\s+([a-z_][a-z0-9_!?]*)\(([^)]*)\)/m
    
    Regex.replace(public_func_pattern, content, fn full_match, indent, func_name, args ->
      # Check if previous line has @doc
      if Regex.match?(~r/@doc.*\n.*#{Regex.escape(full_match)}/s, content) do
        full_match
      else
        doc = generate_function_doc(module_name, func_name, args)
        "#{indent}#{doc}\n#{full_match}"
      end
    end)
  end
  
  defp generate_function_doc(module_name, func_name, args) do
    arg_list = parse_args(args)
    
    base_doc = case func_name do
      "init" -> "Initializes #{module_name}."
      "new" -> "Creates a new instance."
      "update" -> "Updates state."
      "render" -> "Renders output."
      "handle_event" -> "Handles events."
      "mount" -> "Component mount lifecycle."
      "unmount" -> "Component unmount lifecycle."
      "start_link" -> "Starts the process."
      "handle_call" -> "Handles synchronous calls."
      "handle_cast" -> "Handles asynchronous messages."
      "handle_info" -> "Handles info messages."
      _ -> "#{func_name |> String.replace("_", " ") |> String.capitalize()}."
    end
    
    if length(arg_list) > 0 do
      "@doc \"\"\"\n  #{base_doc}\n  \"\"\""
    else
      "@doc \"#{base_doc}\""
    end
  end
  
  defp parse_args(args_string) do
    args_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end
end

ApiDocGenerator.generate()