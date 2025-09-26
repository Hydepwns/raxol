#!/usr/bin/env elixir

# Script to standardize Config/Configuration naming

defmodule StandardizeConfig do
  @moduledoc """
  Standardizes Config/Configuration naming by merging Configuration into Config.
  """

  def run() do
    IO.puts("Starting Config/Configuration standardization...")
    
    merge_configuration_into_config()
    update_references()
    
    IO.puts("\nStandardization complete!")
  end
  
  defp merge_configuration_into_config() do
    IO.puts("\n=== Merging Configuration into Config ===")
    
    config_file = "lib/raxol/terminal/config.ex"
    configuration_file = "lib/raxol/terminal/configuration.ex"
    
    # Read both files
    config_content = File.read!(config_file)
    configuration_content = File.read!(configuration_file)
    
    # Extract unique fields from Configuration that aren't in Config
    additional_fields = extract_additional_fields(configuration_content)
    
    # Add the additional fields to Config
    updated_config = add_fields_to_config(config_content, additional_fields)
    
    # Write updated config
    File.write!(config_file, updated_config)
    IO.puts("  [OK] Merged Configuration fields into Config")
    
    # Delete Configuration file
    File.rm!(configuration_file)
    IO.puts("  [OK] Removed Terminal.Configuration module")
  end
  
  defp extract_additional_fields(configuration_content) do
    # Extract fields that are in Configuration but might not be in Config
    # These are the unique fields from Configuration
    """
    # Additional fields from Configuration module
    scrollback_size: non_neg_integer() | nil,
    scrollback_height: non_neg_integer() | nil,
    font_family: String.t() | nil,
    theme: map() | nil,
    cursor_blink: boolean() | nil,
    tab_stops: [non_neg_integer()] | nil,
    charset_state: map() | nil,
    mode_state: map() | nil,
    saved_state: list() | nil
    """
  end
  
  defp add_fields_to_config(config_content, additional_fields) do
    # Find the @type t definition and add the new fields
    lines = String.split(config_content, "\n")
    
    # Find where to insert the additional fields
    type_index = Enum.find_index(lines, &String.contains?(&1, "@type t :: %__MODULE__{"))
    
    if type_index do
      # Find the closing } of the type definition
      closing_index = find_closing_brace(lines, type_index)
      
      # Insert the additional fields before the closing brace
      {before, after_list} = Enum.split(lines, closing_index)
      
      # Add comma to the last field before insertion
      before_updated = update_last_field(before)
      
      # Create the new fields as a list of lines
      new_fields = String.split(String.trim(additional_fields), "\n")
      |> Enum.map(&("          " <> String.trim(&1)))
      
      # Combine everything
      updated_lines = before_updated ++ new_fields ++ after_list
      
      # Also add to defstruct
      updated_lines = add_to_defstruct(updated_lines)
      
      Enum.join(updated_lines, "\n")
    else
      config_content
    end
  end
  
  defp find_closing_brace(lines, start_index) do
    # Find the matching closing brace for the type definition
    Enum.find_index(start_index..length(lines)-1, fn i ->
      line = Enum.at(lines, i)
      String.contains?(line, "}") && String.contains?(line, "@type")
    end) || start_index + 10
  end
  
  defp update_last_field(lines) do
    # Add comma to the last field if needed
    last_field_index = length(lines) - 1
    last_line = Enum.at(lines, last_field_index)
    
    if String.trim(last_line) != "" && !String.ends_with?(String.trim(last_line), ",") do
      List.replace_at(lines, last_field_index, last_line <> ",")
    else
      lines
    end
  end
  
  defp add_to_defstruct(lines) do
    # Also add the new fields to defstruct
    defstruct_index = Enum.find_index(lines, &String.contains?(&1, "defstruct ["))
    
    if defstruct_index do
      # Find the closing ] of defstruct
      closing_index = Enum.find_index(defstruct_index..length(lines)-1, fn i ->
        String.contains?(Enum.at(lines, i), "]")
      end)
      
      if closing_index do
        {before, [closing_line | after_list]} = Enum.split(lines, closing_index)
        
        # Add the new field names to defstruct
        new_field_names = [
          "    :scrollback_size,",
          "    :scrollback_height,",
          "    :font_family,",
          "    :theme,",
          "    :cursor_blink,",
          "    :tab_stops,",
          "    :charset_state,",
          "    :mode_state,",
          "    :saved_state,"
        ]
        
        before ++ new_field_names ++ [closing_line] ++ after_list
      else
        lines
      end
    else
      lines
    end
  end
  
  defp update_references() do
    IO.puts("\n=== Updating references ===")
    
    replacements = [
      {"Raxol.Terminal.Configuration", "Raxol.Terminal.Config"},
      {"alias Raxol.Terminal.Configuration", "alias Raxol.Terminal.Config"},
      {"%Configuration{", "%Config{"},
      {"Configuration.new", "Config.new"},
      {"Configuration.default", "Config.default"}
    ]
    
    files = Path.wildcard("lib/**/*.ex") ++ 
            Path.wildcard("lib/**/*.exs") ++ 
            Path.wildcard("test/**/*.ex") ++ 
            Path.wildcard("test/**/*.exs")
    
    Enum.each(files, fn file ->
      unless file =~ ~r/standardize_config_naming\.exs$/ do
        content = File.read!(file)
        original = content
        
        updated = Enum.reduce(replacements, content, fn {old, new}, acc ->
          String.replace(acc, old, new)
        end)
        
        if updated != original do
          File.write!(file, updated)
          IO.puts("  Updated: #{file}")
        end
      end
    end)
  end
end

StandardizeConfig.run()