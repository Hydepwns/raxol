defmodule Raxol.SSH.Server do
  @moduledoc """
  Serves a Raxol TEA application over SSH.

  Each SSH connection gets its own Lifecycle process running the TEA app,
  with terminal I/O redirected through the SSH channel.

  ## Usage

      Raxol.SSH.serve(CounterExample, port: 2222)

  Then connect: `ssh localhost -p 2222`
  """

  use GenServer

  require Raxol.Core.Runtime.Log

  defstruct [:daemon_ref, :app_module, :port, :host_keys_dir]

  @doc """
  Starts an SSH server that serves the given TEA app module.

  ## Options
    * `:port` - Port to listen on (default: 2222)
    * `:host_keys_dir` - Directory for SSH host keys (default: "/tmp/raxol_ssh_keys")
  """
  def serve(app_module, opts \\ []) do
    start_link(
      app_module: app_module,
      port: Keyword.get(opts, :port, 2222),
      host_keys_dir: Keyword.get(opts, :host_keys_dir, "/tmp/raxol_ssh_keys")
    )
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    app_module = Keyword.fetch!(opts, :app_module)
    port = Keyword.get(opts, :port, 2222)
    host_keys_dir = Keyword.get(opts, :host_keys_dir, "/tmp/raxol_ssh_keys")

    ensure_host_keys(host_keys_dir)

    daemon_opts = [
      system_dir: String.to_charlist(host_keys_dir),
      shell: &spawn_session(app_module, &1, &2, &3),
      ssh_cli: {Raxol.SSH.CLIHandler, [app_module: app_module]},
      no_auth_needed: true
    ]

    case :ssh.daemon(port, daemon_opts) do
      {:ok, daemon_ref} ->
        Raxol.Core.Runtime.Log.info(
          "[SSH.Server] Listening on port #{port} for #{inspect(app_module)}"
        )

        {:ok,
         %__MODULE__{
           daemon_ref: daemon_ref,
           app_module: app_module,
           port: port,
           host_keys_dir: host_keys_dir
         }}

      {:error, reason} ->
        {:stop, {:ssh_daemon_failed, reason}}
    end
  end

  @impl true
  def terminate(_reason, %__MODULE__{daemon_ref: ref}) when not is_nil(ref) do
    :ssh.stop_daemon(ref)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp spawn_session(app_module, _user, _peer, _channel_info) do
    spawn(fn ->
      Raxol.SSH.Session.run(app_module)
    end)
  end

  defp ensure_host_keys(dir) do
    File.mkdir_p!(dir)
    host_key_path = Path.join(dir, "ssh_host_rsa_key")

    unless File.exists?(host_key_path) do
      Raxol.Core.Runtime.Log.info("[SSH.Server] Generating host keys in #{dir}")
      generate_host_key(dir)
    end
  end

  defp generate_host_key(dir) do
    rsa_key = :public_key.generate_key({:rsa, 2048, 65537})

    rsa_pem =
      :public_key.pem_encode([
        :public_key.pem_entry_encode(:RSAPrivateKey, rsa_key)
      ])

    File.write!(Path.join(dir, "ssh_host_rsa_key"), rsa_pem)
  end
end
