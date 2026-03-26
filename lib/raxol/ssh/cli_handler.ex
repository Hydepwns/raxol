defmodule Raxol.SSH.CLIHandler do
  @moduledoc false
  @behaviour :ssh_server_channel

  require Raxol.Core.Runtime.Log

  defstruct [
    :app_module,
    :session_pid,
    :channel_id,
    :connection_ref,
    registered: false
  ]

  @impl true
  def init(opts) do
    app_module = Keyword.fetch!(opts, :app_module)
    {:ok, %__MODULE__{app_module: app_module}}
  end

  @impl true
  def handle_msg({:ssh_channel_up, channel_id, connection_ref}, state) do
    case Raxol.SSH.Server.register_connection() do
      :ok ->
        {:ok,
         %{
           state
           | channel_id: channel_id,
             connection_ref: connection_ref,
             registered: true
         }}

      {:error, :max_connections} ->
        _ =
          :ssh_connection.send(
            connection_ref,
            channel_id,
            "Connection limit reached. Try again later.\r\n"
          )

        _ = :ssh_connection.close(connection_ref, channel_id)
        {:ok, state}
    end
  end

  @impl true
  def handle_msg(msg, state) do
    Raxol.Core.Runtime.Log.debug(
      "[SSH.CLIHandler] Unhandled msg: #{inspect(msg)}"
    )

    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, _conn, {:data, _ch, _type, data}}, state) do
    maybe_send(state.session_pid, {:ssh_data, data})
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg(
        {:ssh_cm, _conn,
         {:pty, _ch, _want_reply, {_term, width, height, _pxw, _pxh, _modes}}},
        state
      ) do
    {:ok, session_pid} =
      Raxol.SSH.Session.start_link(
        app_module: state.app_module,
        connection_ref: state.connection_ref,
        channel_id: state.channel_id,
        width: width,
        height: height
      )

    {:ok, %{state | session_pid: session_pid}}
  end

  @impl true
  def handle_ssh_msg(
        {:ssh_cm, _conn, {:window_change, _ch, width, height, _pxw, _pxh}},
        state
      ) do
    maybe_send(state.session_pid, {:resize, width, height})
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, _conn, {:shell, _ch, _want_reply}}, state) do
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, _conn, {:eof, _ch}}, state) do
    maybe_send(state.session_pid, :eof)
    {:ok, state}
  end

  @impl true
  def handle_ssh_msg({:ssh_cm, _conn, {:closed, _ch}}, state) do
    maybe_send(state.session_pid, :closed)
    {:stop, state.channel_id, state}
  end

  @impl true
  def handle_ssh_msg(_msg, state), do: {:ok, state}

  @impl true
  def terminate(_reason, %__MODULE__{registered: true}) do
    Raxol.SSH.Server.unregister_connection()
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp maybe_send(nil, _msg), do: :ok
  defp maybe_send(pid, msg), do: send(pid, msg)
end
