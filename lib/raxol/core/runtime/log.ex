defmodule Raxol.Core.Runtime.Log do
  @moduledoc """
  Standardized logging helpers for error and warning messages with context and stacktraces.
  """
  
  require Logger

  @doc """
  Logs an error with stacktrace and context.
  """
  def error_with_stacktrace(msg, error, stacktrace, context \\ nil) do
    error(
      "#{msg}\nError: #{inspect(error)}\nStacktrace: #{Exception.format_stacktrace(stacktrace)}",
      context
    )
  end

  @doc """
  Logs a warning with context.
  """
  def warning_with_context(msg, context) do
    Logger.warning("#{msg} | Context: #{inspect(context)}")
  end

  def info_with_context(msg, context) do
    Logger.info("#{msg} | Context: #{inspect(context)}")
  end

  def debug_with_context(msg, context) do
    Logger.debug("#{msg} | Context: #{inspect(context)}")
  end

  def error_with_context(msg, context) do
    Logger.error("#{msg} | Context: #{inspect(context)}")
  end

  def info(msg), do: log(:info, msg)
  def debug(msg), do: log(:debug, msg)
  def warning(msg), do: log(:warn, msg)
  def error(msg), do: log(:error, msg)

  def info(msg, context), do: log(:info, msg, context)
  def debug(msg, context), do: log(:debug, msg, context)
  def warning(msg, context), do: log(:warn, msg, context)
  def error(msg, context), do: log(:error, msg, context)

  def info_with_context(msg) do
    info_with_context(msg, %{})
  end

  defp log(level, msg, context \\ nil) do
    message = if context, do: "#{msg} | Context: #{inspect(context)}", else: msg
    
    case level do
      :info -> Logger.info(message)
      :debug -> Logger.debug(message)
      :warn -> Logger.warning(message)
      :error -> Logger.error(message)
    end
  end
end
