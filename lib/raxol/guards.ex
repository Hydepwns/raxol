defmodule Raxol.Guards do
  @moduledoc """
  Provides guard macros for type checking in Elixir.

  This module defines macro wrappers around Elixir's built-in `is_*` functions, allowing
  you to use more readable type-checking functions in guard clauses and pattern matching.

  ## Why This Module Exists

  Elixir's built-in type checking functions like `is_number/1`, `is_tuple/1`, etc. are
  already available in guards. However, this module provides a more consistent and
  readable API by offering predicate-style function names (ending with `?`) that match
  Elixir's naming conventions for boolean functions.

  ## Usage

  ```elixir
  def process_data(data) when number?(data) do
    # Handle numeric data
  end

  def process_data(data) when map?(data) and map_size(data) > 0 do
    # Handle non-empty maps
  end

  def process_data(data) when list?(data) and length(data) > 0 do
    # Handle non-empty lists
  end
  ```

  ## Available Guards

  * `number?/1` - Checks if term is a number (integer or float)
  * `tuple?/1` - Checks if term is a tuple
  * `list?/1` - Checks if term is a list
  * `map?/1` - Checks if term is a map
  * `function?/2` - Checks if term is a function with specific arity
  * `float?/1` - Checks if term is a float
  * `integer?/1` - Checks if term is an integer
  * `boolean?/1` - Checks if term is a boolean
  * `binary?/1` - Checks if term is a binary
  * `atom?/1` - Checks if term is an atom
  * `pid?/1` - Checks if term is a process identifier
  * `nil?/1` - Checks if term is nil
  * `struct?/1` - Checks if term is any struct
  * `struct?/2` - Checks if term is a struct of a given module
  * `map_key?/2` - Checks if a map contains a given key
  """

  defmacro number?(term), do: quote(do: is_number(unquote(term)))
  defmacro tuple?(term), do: quote(do: is_tuple(unquote(term)))
  defmacro list?(term), do: quote(do: is_list(unquote(term)))
  defmacro map?(term), do: quote(do: is_map(unquote(term)))
  defmacro function?(term), do: quote(do: is_function(unquote(term)))
  defmacro function?(term, arity), do: quote(do: is_function(unquote(term), unquote(arity)))
  defmacro float?(term), do: quote(do: is_float(unquote(term)))
  defmacro integer?(term), do: quote(do: is_integer(unquote(term)))
  defmacro boolean?(term), do: quote(do: is_boolean(unquote(term)))
  defmacro binary?(term), do: quote(do: is_binary(unquote(term)))
  defmacro atom?(term), do: quote(do: is_atom(unquote(term)))
  defmacro pid?(term), do: quote(do: is_pid(unquote(term)))
  defmacro nil?(term), do: quote(do: is_nil(unquote(term)))
  defmacro struct?(term), do: quote(do: is_struct(unquote(term)))
  defmacro struct?(term, module), do: quote(do: is_struct(unquote(term), unquote(module)))
  defmacro map_key?(map, key), do: quote(do: is_map(unquote(map)) and :erlang.is_map_key(unquote(key), unquote(map)))
end
