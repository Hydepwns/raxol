defmodule Raxol.Audit do
  @moduledoc """
  Top-level audit logging API for Raxol.

  Provides convenient access to audit logging and querying functionality.
  Delegates to `Raxol.Audit.Logger` and related modules for implementation.

  ## Example

      Raxol.Audit.log(:authentication, %{
        user: user_id,
        action: :login,
        ip: client_ip,
        success: true
      })

      events = Raxol.Audit.query(
        user: user_id,
        from: ~U[2024-01-01 00:00:00Z],
        actions: [:login, :logout]
      )
  """

  alias Raxol.Audit.Exporter
  alias Raxol.Audit.Logger
  alias Raxol.Audit.Storage

  @doc """
  Log an audit event.

  ## Parameters

    - `type` - Event type atom (e.g., :authentication, :authorization, :data_access)
    - `data` - Map containing event details

  ## Example

      Raxol.Audit.log(:authentication, %{
        user: "user123",
        action: :login,
        ip: "192.168.1.1",
        success: true
      })
  """
  @spec log(atom(), map()) :: :ok | {:error, term()}
  def log(:authentication, data) do
    Logger.log_authentication(
      Map.get(data, :user, "unknown"),
      Map.get(data, :method, :password),
      Map.get(data, :success, false),
      metadata: data
    )
  end

  def log(:authorization, data) do
    Logger.log_authorization(
      Map.get(data, :user, "unknown"),
      Map.get(data, :resource, "unknown"),
      Map.get(data, :action, :unknown),
      Map.get(data, :success, false),
      metadata: data
    )
  end

  def log(:data_access, data) do
    Logger.log_data_access(
      Map.get(data, :user, "unknown"),
      Map.get(data, :operation, :read),
      Map.get(data, :resource_type, "unknown"),
      metadata: data
    )
  end

  def log(:security, data) do
    Logger.log_security_event(
      Map.get(data, :event_type, :unknown),
      Map.get(data, :severity, :info),
      Map.get(data, :description, ""),
      metadata: data
    )
  end

  def log(type, data) when is_atom(type) and is_map(data) do
    # Generic logging for other event types
    Logger.log_security_event(
      type,
      Map.get(data, :severity, :info),
      inspect(data),
      metadata: data
    )
  end

  @doc """
  Query audit events.

  ## Options

    - `:user` - Filter by user ID
    - `:from` - Start datetime
    - `:to` - End datetime (default: now)
    - `:actions` - List of action types to include
    - `:limit` - Maximum number of results (default: 100)

  ## Example

      events = Raxol.Audit.query(
        user: "user123",
        from: ~U[2024-01-01 00:00:00Z],
        actions: [:login, :logout]
      )
  """
  @spec query(keyword()) :: {:ok, list(map())} | {:error, term()}
  def query(opts \\ []) do
    filters = build_filters(opts)
    query_opts = Keyword.take(opts, [:limit, :offset, :order])
    Storage.query(filters, query_opts)
  end

  @doc """
  Verify integrity of audit logs within a time range.

  Checks that audit logs have not been tampered with using cryptographic verification.
  """
  @spec verify_integrity(DateTime.t(), DateTime.t()) ::
          {:ok, :verified} | {:error, term()}
  def verify_integrity(
        start_time \\ DateTime.add(DateTime.utc_now(), -24, :hour),
        end_time \\ DateTime.utc_now()
      ) do
    Logger.verify_integrity(start_time, end_time)
  end

  @doc """
  Export audit logs for compliance reporting.

  ## Options

    - `:format` - Export format (:json, :csv, :pdf)
    - `:period` - Time period (:last_month, :last_quarter, :last_year, or date range)
    - `:types` - Event types to include
  """
  @spec export(keyword()) :: {:ok, binary()} | {:error, term()}
  def export(opts \\ []) do
    format = Keyword.get(opts, :format, :json)
    filters = build_filters(opts)
    export_opts = Keyword.take(opts, [:compress, :encrypt])
    Exporter.export(format, filters, export_opts)
  end

  # Private helpers

  defp build_filters(opts) do
    %{}
    |> maybe_add_filter(:user_id, Keyword.get(opts, :user))
    |> maybe_add_filter(:from, Keyword.get(opts, :from))
    |> maybe_add_filter(:to, Keyword.get(opts, :to))
    |> maybe_add_filter(:actions, Keyword.get(opts, :actions))
  end

  defp maybe_add_filter(filters, _key, nil), do: filters
  defp maybe_add_filter(filters, key, value), do: Map.put(filters, key, value)
end
