# credo:disable-for-this-file Credo.Check.Refactor.Apply
defmodule Raxol.Performance.FprofWrapper do
  @moduledoc """
  Thin wrapper around `:fprof` that isolates `apply/3` calls.

  `:fprof` is an optional OTP application that may not be available at
  compile time (e.g. in releases without `:tools`). All interaction goes
  through `apply/3` to avoid undefined-function compile warnings.

  This module centralises those calls so the rest of the codebase can
  use normal function calls instead of `apply(:fprof, ...)`.
  """

  @doc "Start the fprof server."
  @spec start() :: term()
  def start, do: apply(:fprof, :start, [])

  @doc "Stop the fprof server."
  @spec stop() :: term()
  def stop, do: apply(:fprof, :stop, [])

  @doc "Stop fprof, ignoring errors if it isn't running."
  @spec safe_stop() :: :ok
  def safe_stop do
    apply(:fprof, :stop, [])
    :ok
  rescue
    _ -> :ok
  end

  @doc "Start or stop tracing with the given options."
  @spec trace(atom() | list()) :: term()
  def trace(opts), do: apply(:fprof, :trace, [opts])

  @doc "Profile accumulated trace data."
  @spec profile() :: term()
  def profile, do: apply(:fprof, :profile, [])

  @doc "Profile with options."
  @spec profile(keyword()) :: term()
  def profile(opts), do: apply(:fprof, :profile, [opts])

  @doc "Analyse profiling results."
  @spec analyse(keyword()) :: term()
  def analyse(opts), do: apply(:fprof, :analyse, [opts])
end
