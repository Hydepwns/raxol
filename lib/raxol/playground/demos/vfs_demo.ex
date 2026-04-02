defmodule Raxol.Playground.Demos.VfsDemo do
  @moduledoc "Playground demo: in-memory virtual file system with shell-like commands."
  use Raxol.Core.Runtime.Application

  alias Raxol.Commands.FileSystem

  @visible_lines 14
  @box_width 70
  @box_height 16
  @max_history 50

  @impl true
  def init(_context) do
    %{
      fs: seed_filesystem(),
      input: "",
      cursor: 0,
      output: [{"# Virtual FS -- type 'help' for commands", :info}],
      output_offset: 0,
      input_history: [],
      history_index: nil
    }
  end

  @impl true
  def update(message, model) do
    case message do
      key_match(:enter) ->
        {exec_input(model), []}

      key_match(:backspace) ->
        input = String.slice(model.input, 0..-2//1)
        {%{model | input: input, cursor: max(model.cursor - 1, 0)}, []}

      key_match("l", ctrl: true) ->
        {%{model | output: [], output_offset: 0}, []}

      key_match("u", ctrl: true) ->
        {%{model | input: "", cursor: 0}, []}

      key_match(:up) ->
        {history_prev(model), []}

      key_match(:down) ->
        {history_next(model), []}

      key_match("j", ctrl: true) ->
        {scroll_output(model, 1), []}

      key_match("k", ctrl: true) ->
        {scroll_output(model, -1), []}

      key_match(:char, char: ch) when byte_size(ch) == 1 ->
        {%{model | input: model.input <> ch, cursor: model.cursor + 1}, []}

      _ ->
        {model, []}
    end
  end

  @impl true
  def view(model) do
    visible =
      model.output
      |> Enum.reverse()
      |> Enum.drop(model.output_offset)
      |> Enum.take(@visible_lines)
      |> Enum.map(&output_line/1)

    column style: %{gap: 0} do
      [
        text("Virtual File System", style: [:bold]),
        text("cwd: #{FileSystem.pwd(model.fs)}", style: [:dim]),
        divider(),
        box style: %{
              border: :single,
              padding: 1,
              width: @box_width,
              height: @box_height
            } do
          column style: %{gap: 0} do
            if visible == [],
              do: [text("(empty)", style: [:dim])],
              else: visible
          end
        end,
        prompt_line(model),
        divider(),
        text(
          "[Enter] exec  [Up/Down] history  [Ctrl+L] clear  [Ctrl+U] clear input",
          style: [:dim]
        ),
        text(
          "Commands: ls [dir] | cd <dir> | cat <file> | pwd | mkdir <dir> | rm <path> | tree [dir] [depth]",
          style: [:dim]
        )
      ]
    end
  end

  @impl true
  def subscribe(_model), do: []

  # -- Command execution --

  defp exec_input(%{input: ""} = model), do: model

  defp exec_input(model) do
    cmd = String.trim(model.input)
    {argv0, args} = parse_command(cmd)
    {output_lines, new_fs} = dispatch(argv0, args, model.fs)

    %{
      model
      | fs: new_fs,
        input: "",
        cursor: 0,
        history_index: nil,
        input_history: [cmd | model.input_history] |> Enum.take(@max_history)
    }
    |> add_output([{"$ #{cmd}", :input} | output_lines])
  end

  defp parse_command(cmd) do
    case String.split(cmd, ~r/\s+/, trim: true) do
      [] -> {"", []}
      [argv0 | args] -> {argv0, args}
    end
  end

  defp dispatch("ls", args, fs) do
    dir = List.first(args, ".")

    case FileSystem.ls(fs, dir) do
      {:ok, entries} ->
        {FileSystem.format_ls(entries, fs, dir), fs}

      {:error, reason} ->
        {[{error_msg("ls", reason), :error}], fs}
    end
  end

  defp dispatch("cd", [], fs), do: {[{"cd: missing argument", :error}], fs}

  defp dispatch("cd", [dir | _], fs) do
    case FileSystem.cd(fs, dir) do
      {:ok, new_fs} -> {[], new_fs}
      {:error, reason} -> {[{error_msg("cd", reason), :error}], fs}
    end
  end

  defp dispatch("cat", [], fs), do: {[{"cat: missing argument", :error}], fs}

  defp dispatch("cat", [path | _], fs) do
    case FileSystem.cat(fs, path) do
      {:ok, content} ->
        lines =
          content
          |> FileSystem.format_cat(@box_width - 4, @visible_lines)
          |> Enum.map(fn {line, num} ->
            {"#{String.pad_leading(Integer.to_string(num), 3)} | #{line}",
             :file}
          end)

        {lines, fs}

      {:error, reason} ->
        {[{error_msg("cat", reason), :error}], fs}
    end
  end

  defp dispatch("pwd", _args, fs) do
    {[{FileSystem.pwd(fs), :result}], fs}
  end

  defp dispatch("mkdir", [], fs),
    do: {[{"mkdir: missing argument", :error}], fs}

  defp dispatch("mkdir", [dir | _], fs) do
    case FileSystem.mkdir(fs, dir) do
      {:ok, new_fs} -> {[{"created: #{dir}", :result}], new_fs}
      {:error, reason} -> {[{error_msg("mkdir", reason), :error}], fs}
    end
  end

  defp dispatch("rm", [], fs), do: {[{"rm: missing argument", :error}], fs}

  defp dispatch("rm", [path | _], fs) do
    case FileSystem.rm(fs, path) do
      {:ok, new_fs} -> {[{"removed: #{path}", :result}], new_fs}
      {:error, reason} -> {[{error_msg("rm", reason), :error}], fs}
    end
  end

  defp dispatch("tree", args, fs) do
    dir = Enum.at(args, 0, ".")
    depth = parse_depth(Enum.at(args, 1))

    case FileSystem.tree(fs, dir, depth) do
      {:ok, tree_data} ->
        lines = tree_data |> format_tree("") |> Enum.map(&{&1, :file})
        {lines, fs}

      {:error, reason} ->
        {[{error_msg("tree", reason), :error}], fs}
    end
  end

  defp dispatch("help", _args, fs) do
    lines = [
      {"ls [dir]           -- list directory", :info},
      {"cd <dir>           -- change directory (supports .., -)", :info},
      {"cat <file>         -- show file content", :info},
      {"pwd                -- print working directory", :info},
      {"mkdir <dir>        -- create directory", :info},
      {"rm <path>          -- remove file or empty dir", :info},
      {"tree [dir] [depth] -- show directory tree", :info}
    ]

    {lines, fs}
  end

  defp dispatch(cmd, _args, fs) do
    {[{"unknown command: #{cmd} (try 'help')", :error}], fs}
  end

  # -- Helpers --

  defp error_msg(cmd, reason) do
    "#{cmd}: #{reason |> Atom.to_string() |> String.replace("_", " ")}"
  end

  defp parse_depth(nil), do: 3

  defp parse_depth(str) do
    case Integer.parse(str) do
      {n, ""} when n >= 0 -> n
      _ -> 3
    end
  end

  defp format_tree({name, :file, _}, prefix), do: [prefix <> name]

  defp format_tree({name, :directory, children}, prefix) do
    last_idx = length(children) - 1

    child_lines =
      children
      |> Enum.with_index()
      |> Enum.flat_map(fn {{child_name, type, grandchildren}, idx} ->
        is_last = idx == last_idx
        connector = if is_last, do: "`-- ", else: "|-- "
        continuation = if is_last, do: "    ", else: "|   "

        format_tree({child_name, type, grandchildren}, prefix <> connector)
        |> Enum.with_index()
        |> Enum.map(fn
          {line, 0} -> line
          {line, _} -> prefix <> continuation <> String.trim_leading(line)
        end)
      end)

    [prefix <> name <> "/" | child_lines]
  end

  # -- Seed data --

  defp seed_filesystem do
    fs = FileSystem.new()
    {:ok, fs} = FileSystem.mkdir(fs, "/home")
    {:ok, fs} = FileSystem.mkdir(fs, "/home/user")
    {:ok, fs} = FileSystem.mkdir(fs, "/home/user/docs")
    {:ok, fs} = FileSystem.mkdir(fs, "/home/user/projects")

    {:ok, fs} =
      FileSystem.create_file(
        fs,
        "/home/user/readme.txt",
        "Welcome to Raxol VFS!\n\nThis is a virtual file system demo.\nAll data lives in memory."
      )

    {:ok, fs} =
      FileSystem.create_file(
        fs,
        "/home/user/docs/notes.txt",
        "- Learn Elixir\n- Build TUIs\n- Ship to Hex"
      )

    {:ok, fs} =
      FileSystem.create_file(
        fs,
        "/home/user/projects/hello.exs",
        ~s[IO.puts("Hello from VFS!")]
      )

    {:ok, fs} = FileSystem.mkdir(fs, "/tmp")
    {:ok, fs} = FileSystem.cd(fs, "/home/user")
    fs
  end

  # -- History navigation --

  defp history_prev(%{input_history: []} = model), do: model

  defp history_prev(model) do
    idx = (model.history_index || -1) + 1
    idx = min(idx, length(model.input_history) - 1)
    input = Enum.at(model.input_history, idx, model.input)
    %{model | history_index: idx, input: input, cursor: String.length(input)}
  end

  defp history_next(model) do
    case model.history_index do
      nil ->
        model

      0 ->
        %{model | history_index: nil, input: "", cursor: 0}

      idx ->
        new_idx = idx - 1
        input = Enum.at(model.input_history, new_idx, "")

        %{
          model
          | history_index: new_idx,
            input: input,
            cursor: String.length(input)
        }
    end
  end

  # -- Scroll --

  defp scroll_output(model, delta) do
    max_offset = max(0, length(model.output) - @visible_lines)

    new_offset =
      Raxol.Core.Utils.Math.clamp(model.output_offset + delta, 0, max_offset)

    %{model | output_offset: new_offset}
  end

  # -- Output --

  defp add_output(model, lines) do
    new_output =
      Enum.reduce(lines, model.output, fn line, acc -> [line | acc] end)

    %{model | output: new_output, output_offset: 0}
  end

  # -- View helpers --

  defp output_line({line, :input}), do: text(line, style: [:bold])
  defp output_line({line, :result}), do: text(line, fg: :green)
  defp output_line({line, :file}), do: text(line)

  defp output_line({line, :directory}),
    do: text(line, fg: :blue, style: [:bold])

  defp output_line({line, :error}), do: text(line, fg: :red)
  defp output_line({line, :info}), do: text(line, style: [:dim])

  defp prompt_line(model) do
    row style: %{gap: 0} do
      [
        text("vfs> ", style: [:bold], fg: :cyan),
        text(model.input <> "_")
      ]
    end
  end
end
