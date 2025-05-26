defmodule Raxol.Core.Runtime.Log do
  @moduledoc """
  Standardized logging helpers for error and warning messages with context and stacktraces.
  """

  @doc """
  Logs an error with stacktrace and context.
  """
  def error_with_stacktrace(msg, error, stacktrace, context \\ nil) do
    error("#{msg}\nError: #{inspect(error)}\nStacktrace: #{Exception.format_stacktrace(stacktrace)}", context)
  end

  @doc """
  Logs a warning with context.
  """
  def warning_with_context(msg, context) do
    IO.puts("[WARN] #{msg} | Context: #{inspect(context)}")
  end

  def info_with_context(msg, context) do
    IO.puts("[INFO] #{msg} | Context: #{inspect(context)}")
  end

  def debug_with_context(msg, context) do
    IO.puts("[DEBUG] #{msg} | Context: #{inspect(context)}")
  end

  def error_with_context(msg, context) do
    IO.puts("[ERROR] #{msg} | Context: #{inspect(context)}")
  end

  def info(msg), do: log(:info, msg)
  def debug(msg), do: log(:debug, msg)
  def warning(msg), do: log(:warn, msg)
  def error(msg), do: log(:error, msg)

  def info(msg, context), do: log(:info, msg, context)
  def debug(msg, context), do: log(:debug, msg, context)
  def warning(msg, context), do: log(:warn, msg, context)
  def error(msg, context), do: log(:error, msg, context)

  defp log(level, msg, context \\ nil) do
    label = level |> Atom.to_string() |> String.upcase()
    output = "[#{label}] #{msg}" <> if context, do: " | Context: #{inspect(context)}", else: ""
    IO.puts(output)
  end
end
