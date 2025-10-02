defmodule Mix.Tasks.Raxol.Wasm do
  @shortdoc "Build Raxol for WebAssembly deployment"

  @moduledoc """
  Compiles Raxol to WebAssembly for web deployment.

  ## Usage

      mix raxol.wasm [options]

  ## Options

    * `--watch` - Watch for changes and rebuild automatically
    * `--optimize` - Enable WASM optimization (default: true)
    * `--release` - Build in release mode with maximum optimization
    * `--clean` - Clean build artifacts before building
    * `--serve` - Start a web server to test the WASM build

  ## Examples

      # Build WASM module
      mix raxol.wasm

      # Build with watch mode for development
      mix raxol.wasm --watch

      # Build optimized release version
      mix raxol.wasm --release

      # Clean and rebuild
      mix raxol.wasm --clean

      # Build and serve for testing
      mix raxol.wasm --serve

  ## Configuration

  Configure WASM build in `config/wasm.exs`:

      config :raxol, :wasm,
        output_dir: "priv/static/wasm",
        optimization_level: 2,
        initial_memory: 16,
        maximum_memory: 256

  ## Requirements

  Requires Rust toolchain with wasm32-unknown-unknown target:

      rustup target add wasm32-unknown-unknown

  Optional: wasm-opt for optimization:

      npm install -g wasm-opt

  ## Output

  Generates the following files:

    * `priv/static/wasm/raxol.wasm` - WebAssembly module
    * `priv/static/js/raxol-terminal.js` - JavaScript bindings
    * `priv/static/wasm/index.html` - Demo HTML page

  ## Deployment

  Copy the generated files to your web server:

      cp -r priv/static/wasm/* /var/www/html/
      cp -r priv/static/js/* /var/www/html/js/

  Or use with a bundler like Webpack or Vite:

      import { RaxolTerminal } from './raxol-terminal.js';

      const terminal = new RaxolTerminal(80, 24);
      await terminal.initialize('/wasm/raxol.wasm');
  """

  use Mix.Task
  alias Raxol.WASM.Builder
  alias Raxol.Core.Runtime.Log

  @switches [
    watch: :boolean,
    optimize: :boolean,
    release: :boolean,
    clean: :boolean,
    serve: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    # Start application for logging
    Mix.Task.run("app.start")

    # Clean if requested
    if opts[:clean] do
      Log.module_info("Cleaning WASM build artifacts...")
      Builder.clean()
    end

    # Determine build options
    build_opts = build_options(opts)

    # Build or watch
    result =
      if opts[:watch] do
        Log.module_info("Starting WASM watch mode...")
        Builder.watch(build_opts)
      else
        Log.module_info("Building WASM module...")
        Builder.build(build_opts)
      end

    case result do
      {:ok, info} ->
        print_success(info)

        if opts[:serve] do
          start_server()
        end

      {:error, reason} ->
        Mix.shell().error("WASM build failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end

  defp build_options(opts) do
    []
    |> maybe_add_optimization(opts)
    |> maybe_add_release(opts)
  end

  defp maybe_add_optimization(build_opts, opts) do
    if opts[:optimize] != false do
      Keyword.put(build_opts, :optimize, true)
    else
      build_opts
    end
  end

  defp maybe_add_release(build_opts, opts) do
    if opts[:release] do
      build_opts
      |> Keyword.put(:optimization, "-O3")
      |> Keyword.put(:optimize, true)
    else
      build_opts
    end
  end

  defp print_success(info) do
    Mix.shell().info("""

    [OK] WASM Build Successful!

    Output:
      File: #{info.path}
      Size: #{info.size_kb} KB

    Testing:
      Open priv/static/wasm/index.html in your browser

    JavaScript Usage:
      import { RaxolTerminal } from '/js/raxol-terminal.js';

      const terminal = new RaxolTerminal(80, 24);
      await terminal.initialize('/wasm/raxol.wasm');
      terminal.writeLine('Hello from WebAssembly!');
    """)
  end

  defp start_server do
    port = 8080
    root = "priv/static"

    Log.module_info("Starting web server on http://localhost:#{port}")

    # Start a simple HTTP server using Erlang's built-in httpd
    {:ok, _pid} =
      :inets.start(:httpd,
        port: port,
        server_root: root,
        document_root: root,
        server_name: "raxol-wasm",
        directory_index: ["index.html"],
        mime_types: [
          {"wasm", "application/wasm"},
          {"js", "application/javascript"},
          {"html", "text/html"},
          {"css", "text/css"}
        ]
      )

    Mix.shell().info("""

    [WEB] Web Server Started!

    Visit: http://localhost:#{port}/wasm/

    Press Ctrl+C to stop the server.
    """)

    # Keep the process alive
    Process.sleep(:infinity)
  end
end

defmodule Mix.Tasks.Raxol.Wasm.Clean do
  @shortdoc "Clean WASM build artifacts"

  @moduledoc """
  Removes all WASM build artifacts.

  ## Usage

      mix raxol.wasm.clean
  """

  use Mix.Task

  alias Raxol.WASM.Builder

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    Builder.clean()
    Mix.shell().info("WASM build artifacts cleaned.")
  end
end

defmodule Mix.Tasks.Raxol.Wasm.Info do
  @shortdoc "Display WASM build information"

  @moduledoc """
  Shows information about the current WASM build.

  ## Usage

      mix raxol.wasm.info
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    wasm_file = "priv/static/wasm/raxol.wasm"

    if File.exists?(wasm_file) do
      stat = File.stat!(wasm_file)

      Mix.shell().info("""

      WASM Build Information:
      ----------------------
      File: #{wasm_file}
      Size: #{Float.round(stat.size / 1024, 2)} KB
      Modified: #{stat.mtime}

      JavaScript Bindings: priv/static/js/raxol-terminal.js
      Demo Page: priv/static/wasm/index.html

      Browser Support:
      - Chrome 57+
      - Firefox 52+
      - Safari 11+
      - Edge 79+
      """)
    else
      Mix.shell().error("No WASM build found. Run `mix raxol.wasm` to build.")
    end
  end
end
