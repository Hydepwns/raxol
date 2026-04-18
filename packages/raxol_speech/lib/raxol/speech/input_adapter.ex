defmodule Raxol.Speech.InputAdapter do
  @moduledoc """
  Translates recognized speech text into Raxol Event structs.

  Single words matching known commands become key events.
  Multi-word phrases become paste events. The command vocabulary
  is configurable via the `:voice_commands` option.
  """

  alias Raxol.Core.Events.Event

  @default_commands %{
    "quit" => {:key, %{key: :char, char: "q"}},
    "exit" => {:key, %{key: :char, char: "q"}},
    "up" => {:key, %{key: :up}},
    "down" => {:key, %{key: :down}},
    "left" => {:key, %{key: :left}},
    "right" => {:key, %{key: :right}},
    "enter" => {:key, %{key: :enter}},
    "tab" => {:key, %{key: :tab}},
    "space" => {:key, %{key: :char, char: " "}},
    "escape" => {:key, %{key: :escape}},
    "backspace" => {:key, %{key: :backspace}},
    "next" => {:key, %{key: :tab}},
    "previous" => {:key, %{key: :tab, modifiers: [:shift]}},
    "yes" => {:key, %{key: :char, char: "y"}},
    "no" => {:key, %{key: :char, char: "n"}},
    "help" => {:key, %{key: :char, char: "h"}},
    "scroll up" => {:key, %{key: :char, char: "k"}},
    "scroll down" => {:key, %{key: :char, char: "j"}},
    "page up" => {:key, %{key: :page_up}},
    "page down" => {:key, %{key: :page_down}}
  }

  @doc """
  Translates recognized speech text to a Raxol Event.

  ## Options

    * `:commands` - custom voice command map (merged with defaults)

  ## Examples

      translate("quit")        #=> Event with char "q"
      translate("up")          #=> Event with key :up
      translate("scroll down") #=> Event with char "j"
      translate("hello world") #=> Event with type :paste
  """
  @spec translate(String.t(), keyword()) :: Event.t() | nil
  def translate(text, opts \\ [])

  def translate(text, opts) when is_binary(text) do
    normalized = text |> String.trim() |> String.downcase()

    case normalized do
      "" ->
        nil

      _ ->
        commands = merge_commands(opts)

        case Map.get(commands, normalized) do
          {:key, data} -> Event.new(:key, data)
          nil -> Event.new(:paste, %{text: String.trim(text)})
        end
    end
  end

  def translate(_, _), do: nil

  @doc "Returns the default voice command vocabulary."
  @spec default_commands() :: map()
  def default_commands, do: @default_commands

  defp merge_commands(opts) do
    case Keyword.get(opts, :commands) do
      nil -> @default_commands
      custom when is_map(custom) -> Map.merge(@default_commands, custom)
      _ -> @default_commands
    end
  end
end
