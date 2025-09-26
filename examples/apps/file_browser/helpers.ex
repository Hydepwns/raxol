defmodule Examples.FileBrowser.Helpers do
  @moduledoc """
  Helper functions for the file browser explorer.

  Provides formatting utilities for file icons, sizes, and timestamps.
  """

  def file_icon(entry) do
    case entry.type do
      :directory ->
        "[DIR]"

      :symlink ->
        "[LINK]"

      _ ->
        case entry.extension do
          ext when ext in [".ex", ".exs"] -> "[ELIXIR]"
          ext when ext in [".js", ".ts"] -> "[JS]"
          ext when ext in [".py"] -> "[PYTHON]"
          ext when ext in [".rb"] -> "[RUBY]"
          ext when ext in [".md"] -> "[MD]"
          ext when ext in [".txt", ".log"] -> "[TXT]"
          ext when ext in [".jpg", ".png", ".gif"] -> "[IMG]"
          ext when ext in [".mp3", ".wav", ".ogg"] -> "[AUDIO]"
          ext when ext in [".mp4", ".avi", ".mov"] -> "[VIDEO]"
          ext when ext in [".zip", ".tar", ".gz"] -> "[ARCHIVE]"
          _ -> "[TXT]"
        end
    end
  end

  def format_size(size) when size < 1024, do: "#{size} B"

  def format_size(size) when size < 1024 * 1024,
    do: "#{Float.round(size / 1024, 1)} KB"

  def format_size(size) when size < 1024 * 1024 * 1024,
    do: "#{Float.round(size / 1024 / 1024, 1)} MB"

  def format_size(size),
    do: "#{Float.round(size / 1024 / 1024 / 1024, 2)} GB"

  def format_time(time) do
    {{year, month, day}, {hour, minute, _}} = time

    month_name =
      ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)
      |> Enum.at(month - 1)

    "#{month_name} #{String.pad_leading("#{day}", 2)} #{year} " <>
      "#{String.pad_leading("#{hour}", 2, "0")}:#{String.pad_leading("#{minute}", 2, "0")}"
  end
end
