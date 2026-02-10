defmodule Raxol.Demo.SSHServer do
  @moduledoc """
  SSH server for terminal demo access.
  Allows users to connect via: ssh -p 2222 demo@localhost
  """

  use GenServer
  require Logger

  @default_port 2222

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :port, @default_port)

    # Generate or load host keys
    system_dir = ensure_host_keys()

    ssh_opts = [
      system_dir: String.to_charlist(system_dir),
      shell: &start_shell/2,
      pwdfun: fn _user, _password, _peer, _state -> true end,
      parallel_login: true,
      max_sessions: 100,
      idle_time: 1_800_000,
      negotiation_timeout: 60_000
    ]

    case :ssh.daemon(port, ssh_opts) do
      {:ok, daemon_ref} ->
        Logger.info("SSH demo server started on port #{port}")
        Logger.info("Connect with: ssh -p #{port} demo@localhost")
        {:ok, %{daemon_ref: daemon_ref, port: port}}

      {:error, reason} ->
        Logger.error("Failed to start SSH server: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:stop, _from, state) do
    :ssh.stop_daemon(state.daemon_ref)
    {:stop, :normal, :ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state[:daemon_ref] do
      :ssh.stop_daemon(state.daemon_ref)
    end
  end

  defp start_shell(_user, _peer) do
    spawn(__MODULE__, :shell_loop_init, [])
  end

  def shell_loop_init do
    # Get the group leader (IO device) for this shell
    gl = Process.group_leader()

    # Send welcome message
    welcome = Raxol.Demo.DemoHandler.welcome_message()
    :io.put_chars(gl, welcome)
    :io.put_chars(gl, prompt())

    # Enter shell loop
    shell_loop(gl, "")
  end

  defp shell_loop(gl, _buffer) do
    # Use :io.get_line for line-based input (SSH handles char echo)
    case :io.get_line(gl, ~c"") do
      :eof ->
        :io.put_chars(gl, "\r\nGoodbye!\r\n")

      {:error, _} ->
        :ok

      line when is_list(line) ->
        cmd = line |> List.to_string() |> String.trim()
        handle_command(gl, cmd)
        :io.put_chars(gl, prompt())
        shell_loop(gl, "")

      line when is_binary(line) ->
        cmd = String.trim(line)
        handle_command(gl, cmd)
        :io.put_chars(gl, prompt())
        shell_loop(gl, "")
    end
  end

  defp handle_command(_gl, ""), do: :ok

  defp handle_command(gl, cmd) do
    case Raxol.Demo.CommandWhitelist.execute(cmd) do
      {:ok, output} ->
        :io.put_chars(gl, output)

      {:error, msg} ->
        :io.put_chars(gl, "\e[31m#{msg}\e[0m\r\n")

      {:animate, fun} ->
        # Run animation function with the IO device
        fun.(gl)

      {:exit, msg} ->
        :io.put_chars(gl, msg)
        Process.exit(self(), :normal)
    end
  end

  defp prompt do
    "\e[32mraxol>\e[0m "
  end

  defp ensure_host_keys do
    ssh_dir = Path.join([System.tmp_dir!(), "raxol_ssh"])
    File.mkdir_p!(ssh_dir)

    host_key_path = Path.join(ssh_dir, "ssh_host_rsa_key")

    _ =
      if not File.exists?(host_key_path) do
        Logger.info("Generating SSH host key...")

        {_, 0} =
          System.cmd("ssh-keygen", [
            "-t",
            "rsa",
            "-b",
            "2048",
            "-f",
            host_key_path,
            "-N",
            "",
            "-q"
          ])
      end

    ssh_dir
  end
end
