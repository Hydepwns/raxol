defmodule Raxol.Terminal.CharacterSets do
  @moduledoc '''
  Manages character sets for the terminal emulator.
  '''

  @doc '''
  Creates a new character sets manager with default settings.
  '''
  def new do
    %{
      current_set: :us_ascii,
      sets: %{
        us_ascii: %{
          name: "US ASCII",
          mapping: %{}
        },
        dec_special: %{
          name: "DEC Special",
          mapping: %{
            "`" => "◆",
            "a" => "▒",
            "b" => "␉",
            "c" => "␌",
            "d" => "␍",
            "e" => "␊",
            "f" => "°",
            "g" => "±",
            "h" => "␤",
            "i" => "␋",
            "j" => "┘",
            "k" => "┐",
            "l" => "┌",
            "m" => "└",
            "n" => "┼",
            "o" => "⎺",
            "p" => "⎻",
            "q" => "─",
            "r" => "⎼",
            "s" => "⎽",
            "t" => "├",
            "u" => "┤",
            "v" => "┴",
            "w" => "┬",
            "x" => "│",
            "y" => "≤",
            "z" => "≥",
            "{" => "π",
            "|" => "≠",
            "}" => "£",
            "~" => "·"
          }
        }
      }
    }
  end

  @doc '''
  Gets the current character set.
  '''
  def get_current_set(manager) do
    manager.current_set
  end

  @doc '''
  Sets the current character set.
  '''
  def set_current_set(manager, set_name) when is_atom(set_name) do
    case Map.get(manager.sets, set_name) do
      nil -> {:error, :invalid_set}
      _set -> {:ok, %{manager | current_set: set_name}}
    end
  end

  @doc '''
  Maps a character using the current character set.
  '''
  def map_character(manager, char) do
    case Map.get(manager.sets[manager.current_set].mapping, char) do
      nil -> char
      mapped -> mapped
    end
  end
end
