defmodule Raxol.Command.Parser do
  @moduledoc """
  Command parser with tab completion, history, and argument parsing.

  Features:
  - Command tokenization with quoted strings
  - Flag and argument parsing
  - Tab completion
  - Command history (↑/↓ navigation)
  - Fuzzy history search (Ctrl+R)
  - Command aliases

  ## Example

      parser = Parser.new()
      parser = Parser.register_command(parser, "echo", &echo_handler/1)
      parser = Parser.register_alias(parser, "e", "echo")

      {:ok, result, parser} = Parser.parse_and_execute(parser, "echo Hello World")
      # => {:ok, "Hello World", parser}

  ## Tab Completion

      parser = Parser.handle_key(parser, "ec")
      parser = Parser.handle_key(parser, "Tab")
      # Autocompletes to "echo"
  """

  @type command_fn :: (list(String.t()) -> {:ok, any()} | {:error, String.t()})

  @type t :: %__MODULE__{
          commands: map(),
          aliases: map(),
          history: list(String.t()),
          history_index: non_neg_integer(),
          input: String.t(),
          cursor_pos: non_neg_integer(),
          completion_candidates: list(String.t()),
          completion_index: non_neg_integer(),
          search_mode: boolean(),
          search_query: String.t()
        }

  defstruct commands: %{},
            aliases: %{},
            history: [],
            history_index: 0,
            input: "",
            cursor_pos: 0,
            completion_candidates: [],
            completion_index: 0,
            search_mode: false,
            search_query: ""

  @doc """
  Create a new command parser.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @doc """
  Register a command handler.
  """
  @spec register_command(t(), String.t(), command_fn()) :: t()
  def register_command(%__MODULE__{commands: commands} = parser, name, handler) do
    %{parser | commands: Map.put(commands, name, handler)}
  end

  @doc """
  Register a command alias.
  """
  @spec register_alias(t(), String.t(), String.t()) :: t()
  def register_alias(
        %__MODULE__{aliases: aliases} = parser,
        alias_name,
        command_name
      ) do
    %{parser | aliases: Map.put(aliases, alias_name, command_name)}
  end

  @doc """
  Parse and execute a command string.
  """
  @spec parse_and_execute(t(), String.t()) ::
          {:ok, any(), t()} | {:error, String.t(), t()}
  def parse_and_execute(parser, command_str) do
    with {:ok, tokens} <- tokenize(command_str),
         {:ok, command, args} <- extract_command(tokens),
         resolved_command <- resolve_alias(parser, command),
         {:ok, handler} <- get_handler(parser, resolved_command) do
      case handler.(args) do
        {:ok, result} ->
          new_parser = add_to_history(parser, command_str)
          {:ok, result, new_parser}

        {:error, reason} ->
          {:error, reason, parser}
      end
    else
      {:error, reason} -> {:error, reason, parser}
    end
  end

  @doc """
  Handle a key press for interactive command input.
  """
  @spec handle_key(t(), String.t()) :: t()
  def handle_key(%__MODULE__{search_mode: true} = parser, key) do
    handle_search_key(parser, key)
  end

  def handle_key(parser, "Enter") do
    execute_current_input(parser)
  end

  def handle_key(parser, "Tab") do
    handle_tab_completion(parser)
  end

  def handle_key(parser, "ArrowUp") do
    navigate_history_up(parser)
  end

  def handle_key(parser, "ArrowDown") do
    navigate_history_down(parser)
  end

  def handle_key(parser, "Ctrl+R") do
    enter_search_mode(parser)
  end

  def handle_key(parser, "Backspace") do
    delete_char(parser)
  end

  def handle_key(parser, "ArrowLeft") do
    move_cursor_left(parser)
  end

  def handle_key(parser, "ArrowRight") do
    move_cursor_right(parser)
  end

  def handle_key(parser, char) when byte_size(char) == 1 do
    insert_char(parser, char)
  end

  def handle_key(parser, _key), do: parser

  # Tokenization

  defp tokenize(command_str) do
    try do
      tokens = do_tokenize(command_str, "", [], false)
      {:ok, tokens}
    rescue
      e -> {:error, "Tokenization failed: #{Exception.message(e)}"}
    end
  end

  defp do_tokenize("", "", acc, _in_quotes), do: Enum.reverse(acc)

  defp do_tokenize("", current, acc, _in_quotes),
    do: Enum.reverse([current | acc])

  defp do_tokenize(~s(") <> rest, current, acc, false) do
    # Start quoted string
    new_acc = if current == "", do: acc, else: [current | acc]
    do_tokenize(rest, "", new_acc, true)
  end

  defp do_tokenize(~s(") <> rest, current, acc, true) do
    # End quoted string
    do_tokenize(rest, "", [current | acc], false)
  end

  defp do_tokenize(" " <> rest, current, acc, false) do
    # Space separator (not in quotes)
    new_acc = if current == "", do: acc, else: [current | acc]
    do_tokenize(rest, "", new_acc, false)
  end

  defp do_tokenize(<<char::utf8, rest::binary>>, current, acc, in_quotes) do
    # Regular character
    do_tokenize(rest, current <> <<char::utf8>>, acc, in_quotes)
  end

  defp extract_command([]), do: {:error, "Empty command"}
  defp extract_command([command | args]), do: {:ok, command, args}

  defp resolve_alias(%{aliases: aliases}, command) do
    Map.get(aliases, command, command)
  end

  defp get_handler(%{commands: commands}, command) do
    case Map.get(commands, command) do
      nil -> {:error, "Unknown command: #{command}"}
      handler -> {:ok, handler}
    end
  end

  # History management

  defp add_to_history(%{history: history} = parser, command) do
    # Don't add duplicates consecutively
    new_history =
      if List.first(history) == command do
        history
      else
        [command | Enum.take(history, 99)]
      end

    %{parser | history: new_history, history_index: 0}
  end

  defp navigate_history_up(%{history: history, history_index: idx} = parser) do
    max_idx = length(history)

    if idx < max_idx do
      new_idx = idx + 1
      command = Enum.at(history, new_idx - 1)

      %{
        parser
        | input: command,
          cursor_pos: String.length(command),
          history_index: new_idx
      }
    else
      parser
    end
  end

  defp navigate_history_down(%{history: history, history_index: idx} = parser) do
    if idx > 0 do
      new_idx = idx - 1

      if new_idx == 0 do
        %{parser | input: "", cursor_pos: 0, history_index: 0}
      else
        command = Enum.at(history, new_idx - 1)

        %{
          parser
          | input: command,
            cursor_pos: String.length(command),
            history_index: new_idx
        }
      end
    else
      parser
    end
  end

  # Tab completion

  defp handle_tab_completion(
         %{input: input, commands: commands, completion_candidates: []} = parser
       ) do
    # First tab press - find candidates
    candidates = find_completion_candidates(input, commands)

    case candidates do
      [] ->
        parser

      [single] ->
        # Single match - complete it
        %{parser | input: single, cursor_pos: String.length(single)}

      multiple ->
        # Multiple matches - show candidates
        %{parser | completion_candidates: multiple, completion_index: 0}
    end
  end

  defp handle_tab_completion(
         %{completion_candidates: candidates, completion_index: idx} = parser
       ) do
    # Cycle through candidates
    new_idx = rem(idx + 1, length(candidates))
    command = Enum.at(candidates, new_idx)

    %{
      parser
      | input: command,
        cursor_pos: String.length(command),
        completion_index: new_idx
    }
  end

  defp find_completion_candidates(input, commands) do
    prefix = String.trim(input)

    commands
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, prefix))
    |> Enum.sort()
  end

  # Search mode

  defp enter_search_mode(parser) do
    %{parser | search_mode: true, search_query: ""}
  end

  defp handle_search_key(parser, "Escape") do
    %{parser | search_mode: false, search_query: ""}
  end

  defp handle_search_key(parser, "Enter") do
    # Execute search
    result = search_history(parser)
    %{parser | search_mode: false, search_query: "", input: result}
  end

  defp handle_search_key(parser, "Backspace") do
    new_query = String.slice(parser.search_query, 0..-2//1)
    %{parser | search_query: new_query}
  end

  defp handle_search_key(parser, char) when byte_size(char) == 1 do
    new_query = parser.search_query <> char
    %{parser | search_query: new_query}
  end

  defp handle_search_key(parser, _key), do: parser

  defp search_history(%{history: history, search_query: query}) do
    history
    |> Enum.find("", &String.contains?(&1, query))
  end

  # Character editing

  defp insert_char(%{input: input, cursor_pos: pos} = parser, char) do
    {before, after_part} = String.split_at(input, pos)
    new_input = before <> char <> after_part

    %{parser | input: new_input, cursor_pos: pos + 1, completion_candidates: []}
  end

  defp delete_char(%{input: input, cursor_pos: pos} = parser) when pos > 0 do
    {before, after_part} = String.split_at(input, pos)
    new_before = String.slice(before, 0..-2//1)
    new_input = new_before <> after_part

    %{parser | input: new_input, cursor_pos: pos - 1, completion_candidates: []}
  end

  defp delete_char(parser), do: parser

  defp move_cursor_left(%{cursor_pos: pos} = parser) when pos > 0 do
    %{parser | cursor_pos: pos - 1}
  end

  defp move_cursor_left(parser), do: parser

  defp move_cursor_right(%{input: input, cursor_pos: pos} = parser) do
    max_pos = String.length(input)

    if pos < max_pos do
      %{parser | cursor_pos: pos + 1}
    else
      parser
    end
  end

  defp execute_current_input(%{input: input} = parser) do
    case parse_and_execute(parser, input) do
      {:ok, _result, new_parser} ->
        %{new_parser | input: "", cursor_pos: 0, completion_candidates: []}

      {:error, _reason, new_parser} ->
        %{new_parser | input: "", cursor_pos: 0, completion_candidates: []}
    end
  end

  @doc """
  Get completion candidates for current input.
  """
  @spec get_completions(t()) :: list(String.t())
  def get_completions(%{completion_candidates: candidates}), do: candidates

  @doc """
  Get current input string.
  """
  @spec get_input(t()) :: String.t()
  def get_input(%{input: input}), do: input

  @doc """
  Get cursor position.
  """
  @spec get_cursor_pos(t()) :: non_neg_integer()
  def get_cursor_pos(%{cursor_pos: pos}), do: pos

  @doc """
  Get command history.
  """
  @spec get_history(t()) :: list(String.t())
  def get_history(%{history: history}), do: history
end
