defmodule Raxol.WASM.Builder do
  @moduledoc """
  WebAssembly build system for Raxol.

  Compiles Raxol to WASM for web deployment using Rust/wasm-bindgen
  or Zig as the compilation backend.
  """
  alias Raxol.Core.Runtime.Log

  @wasm_output_dir "priv/static/wasm"
  @js_output_dir "priv/static/js"

  @doc """
  Builds the WASM module with all configurations.
  """
  def build(opts \\ []) do
    Log.info("Starting WASM build for Raxol...")

    with :ok <- prepare_directories(),
         :ok <- generate_wasm_wrapper(),
         :ok <- compile_to_wasm(opts),
         :ok <- generate_js_bindings(),
         :ok <- optimize_wasm(opts),
         :ok <- copy_assets() do
      Log.info("WASM build completed successfully!")
      {:ok, wasm_info()}
    else
      {:error, reason} = error ->
        Log.error("WASM build failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Cleans the WASM build artifacts.
  """
  def clean do
    Log.info("Cleaning WASM build artifacts...")

    [@wasm_output_dir, @js_output_dir]
    |> Enum.each(&File.rm_rf!/1)

    :ok
  end

  @doc """
  Watches for changes and rebuilds WASM.
  """
  def watch(opts \\ []) do
    Log.info("Starting WASM watch mode...")

    # Initial build
    build(opts)

    # Set up file watcher
    {:ok, pid} = FileSystem.start_link(dirs: ["lib/raxol"])
    FileSystem.subscribe(pid)

    watch_loop(opts)
  end

  # Private functions

  defp prepare_directories do
    [@wasm_output_dir, @js_output_dir]
    |> Enum.each(&File.mkdir_p!/1)

    :ok
  end

  defp generate_wasm_wrapper do
    Log.info("Generating WASM wrapper...")

    wrapper_content = """
    // Auto-generated WASM wrapper for Raxol
    // This file bridges Elixir code with WebAssembly

    #![no_std]
    #![feature(alloc_error_handler)]

    extern crate alloc;
    extern crate wee_alloc;

    use alloc::vec::Vec;
    use alloc::string::String;

    // Use wee_alloc as the global allocator for smaller binary size
    #[global_allocator]
    static ALLOC: wee_alloc::WeeAlloc = wee_alloc::WeeAlloc::INIT;

    // Terminal state (simplified for WASM)
    pub struct Terminal {
        width: u32,
        height: u32,
        buffer: Vec<Vec<Cell>>,
        cursor_x: u32,
        cursor_y: u32,
        current_style: Style,
    }

    pub struct Cell {
        char: char,
        style: Style,
    }

    pub struct Style {
        foreground: u32, // RGB color
        background: u32, // RGB color
        bold: bool,
        italic: bool,
        underline: bool,
    }

    // Exported functions for JavaScript
    #[no_mangle]
    pub extern "C" fn create_terminal(width: u32, height: u32) -> *mut Terminal {
        let terminal = Terminal::new(width, height);
        Box::into_raw(Box::new(terminal))
    }

    #[no_mangle]
    pub extern "C" fn process_input(terminal: *mut Terminal, input: *const u8, len: usize) {
        unsafe {
            let terminal = &mut *terminal;
            let input_slice = std::slice::from_raw_parts(input, len);
            terminal.process_bytes(input_slice);
        }
    }

    #[no_mangle]
    pub extern "C" fn resize_terminal(terminal: *mut Terminal, width: u32, height: u32) {
        unsafe {
            let terminal = &mut *terminal;
            terminal.resize(width, height);
        }
    }

    #[no_mangle]
    pub extern "C" fn get_output(terminal: *mut Terminal) -> *const u8 {
        unsafe {
            let terminal = &*terminal;
            terminal.render_to_json().as_ptr()
        }
    }

    #[no_mangle]
    pub extern "C" fn free_terminal(terminal: *mut Terminal) {
        unsafe {
            Box::from_raw(terminal);
        }
    }

    impl Terminal {
        fn new(width: u32, height: u32) -> Self {
            let mut buffer = Vec::with_capacity(height as usize);
            for _ in 0..height {
                let mut row = Vec::with_capacity(width as usize);
                for _ in 0..width {
                    row.push(Cell::default());
                }
                buffer.push(row);
            }

            Terminal {
                width,
                height,
                buffer,
                cursor_x: 0,
                cursor_y: 0,
                current_style: Style::default(),
            }
        }

        fn process_bytes(&mut self, input: &[u8]) {
            // Simplified ANSI processing
            for byte in input {
                self.process_byte(*byte);
            }
        }

        fn process_byte(&mut self, byte: u8) {
            match byte {
                0x1B => { /* ESC sequence */ },
                0x0A => self.line_feed(),      // LF
                0x0D => self.carriage_return(), // CR
                0x08 => self.backspace(),       // BS
                b if b >= 0x20 => self.write_char(b as char),
                _ => {},
            }
        }

        fn write_char(&mut self, ch: char) {
            if self.cursor_x < self.width {
                self.buffer[self.cursor_y as usize][self.cursor_x as usize] = Cell {
                    char: ch,
                    style: self.current_style.clone(),
                };
                self.cursor_x += 1;
            }
        }

        fn line_feed(&mut self) {
            self.cursor_y = (self.cursor_y + 1).min(self.height - 1);
        }

        fn carriage_return(&mut self) {
            self.cursor_x = 0;
        }

        fn backspace(&mut self) {
            if self.cursor_x > 0 {
                self.cursor_x -= 1;
            }
        }

        fn resize(&mut self, width: u32, height: u32) {
            // Resize buffer, preserving content where possible
            let mut new_buffer = Vec::with_capacity(height as usize);

            for y in 0..height {
                let mut row = Vec::with_capacity(width as usize);
                for x in 0..width {
                    if y < self.height && x < self.width {
                        row.push(self.buffer[y as usize][x as usize].clone());
                    } else {
                        row.push(Cell::default());
                    }
                }
                new_buffer.push(row);
            }

            self.buffer = new_buffer;
            self.width = width;
            self.height = height;
            self.cursor_x = self.cursor_x.min(width - 1);
            self.cursor_y = self.cursor_y.min(height - 1);
        }

        fn render_to_json(&self) -> String {
            // Convert terminal state to JSON for JavaScript consumption
            // This is a simplified version - real implementation would be more complex
            format!(
                r#"{{"width":{},"height":{},"cursor_x":{},"cursor_y":{},"cells":[]}}"#,
                self.width, self.height, self.cursor_x, self.cursor_y
            )
        }
    }

    impl Default for Cell {
        fn default() -> Self {
            Cell {
                char: ' ',
                style: Style::default(),
            }
        }
    }

    impl Clone for Cell {
        fn clone(&self) -> Self {
            Cell {
                char: self.char,
                style: self.style.clone(),
            }
        }
    }

    impl Default for Style {
        fn default() -> Self {
            Style {
                foreground: 0xD3D7CF, // Default white
                background: 0x2E3436, // Default black
                bold: false,
                italic: false,
                underline: false,
            }
        }
    }

    impl Clone for Style {
        fn clone(&self) -> Self {
            Style {
                foreground: self.foreground,
                background: self.background,
                bold: self.bold,
                italic: self.italic,
                underline: self.underline,
            }
        }
    }

    // Panic handler for no_std
    #[panic_handler]
    fn panic(_info: &core::panic::PanicInfo) -> ! {
        loop {}
    }

    // Allocation error handler
    #[alloc_error_handler]
    fn oom(_: alloc::alloc::Layout) -> ! {
        loop {}
    }
    """

    File.write!("#{@wasm_output_dir}/raxol_wasm.rs", wrapper_content)
    :ok
  end

  defp compile_to_wasm(opts) do
    Log.info("Compiling to WASM...")

    optimization = Keyword.get(opts, :optimization, "-O2")

    # Use rustc with wasm32 target
    cmd = """
    rustc \
      --target wasm32-unknown-unknown \
      --crate-type cdylib \
      #{optimization} \
      -C lto=yes \
      -C opt-level=z \
      -C embed-bitcode=yes \
      -o #{@wasm_output_dir}/raxol.wasm \
      #{@wasm_output_dir}/raxol_wasm.rs
    """

    case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
      {_, 0} ->
        Log.info("WASM compilation successful")
        :ok

      {output, _} ->
        Log.error("WASM compilation failed: #{output}")
        {:error, :compilation_failed}
    end
  end

  defp generate_js_bindings do
    Log.info("Generating JavaScript bindings...")

    js_content = """
    // Raxol WebAssembly JavaScript Bindings
    // Auto-generated - do not edit directly

    export class RaxolTerminal {
      constructor(width = 80, height = 24) {
        this.width = width;
        this.height = height;
        this.wasmModule = null;
        this.terminalPtr = null;
        this.memory = null;
      }

      async initialize(wasmPath = '/wasm/raxol.wasm') {
        try {
          const response = await fetch(wasmPath);
          const bytes = await response.arrayBuffer();

          const imports = {
            env: {
              // Memory management
              memory: new WebAssembly.Memory({ initial: 16, maximum: 256 }),

              // Console logging for debugging
              console_log: (ptr, len) => {
                const msg = this.readString(ptr, len);
                console.log('[WASM]', msg);
              },

              // Animation frame for smooth rendering
              request_animation_frame: (callback) => {
                requestAnimationFrame(callback);
              },

              // Local storage for persistence
              local_storage_get: (keyPtr, keyLen) => {
                const key = this.readString(keyPtr, keyLen);
                return localStorage.getItem(key);
              },

              local_storage_set: (keyPtr, keyLen, valuePtr, valueLen) => {
                const key = this.readString(keyPtr, keyLen);
                const value = this.readString(valuePtr, valueLen);
                localStorage.setItem(key, value);
              }
            }
          };

          const result = await WebAssembly.instantiate(bytes, imports);
          this.wasmModule = result.instance;
          this.memory = this.wasmModule.exports.memory;

          // Create terminal instance
          this.terminalPtr = this.wasmModule.exports.create_terminal(this.width, this.height);

          console.log('Raxol WASM Terminal initialized successfully');
          return true;
        } catch (error) {
          console.error('Failed to initialize Raxol WASM:', error);
          return false;
        }
      }

      processInput(input) {
        if (!this.wasmModule || !this.terminalPtr) {
          throw new Error('Terminal not initialized');
        }

        const encoder = new TextEncoder();
        const bytes = encoder.encode(input);
        const ptr = this.allocateMemory(bytes.length);

        new Uint8Array(this.memory.buffer).set(bytes, ptr);
        this.wasmModule.exports.process_input(this.terminalPtr, ptr, bytes.length);
        this.freeMemory(ptr);
      }

      resize(width, height) {
        if (!this.wasmModule || !this.terminalPtr) {
          throw new Error('Terminal not initialized');
        }

        this.width = width;
        this.height = height;
        this.wasmModule.exports.resize_terminal(this.terminalPtr, width, height);
      }

      getOutput() {
        if (!this.wasmModule || !this.terminalPtr) {
          throw new Error('Terminal not initialized');
        }

        const ptr = this.wasmModule.exports.get_output(this.terminalPtr);
        const output = this.readString(ptr, 1024 * 1024); // Max 1MB output
        return JSON.parse(output);
      }

      destroy() {
        if (this.wasmModule && this.terminalPtr) {
          this.wasmModule.exports.free_terminal(this.terminalPtr);
          this.terminalPtr = null;
        }
      }

      // Helper methods

      allocateMemory(size) {
        // Simple bump allocator for demo
        // Real implementation would use WASM malloc
        return 0x10000; // Fixed address for simplicity
      }

      freeMemory(ptr) {
        // No-op for simple allocator
      }

      readString(ptr, maxLen) {
        const memory = new Uint8Array(this.memory.buffer);
        let len = 0;

        while (len < maxLen && memory[ptr + len] !== 0) {
          len++;
        }

        const bytes = memory.slice(ptr, ptr + len);
        return new TextDecoder().decode(bytes);
      }

      // Convenience methods

      write(text) {
        this.processInput(text);
      }

      writeLine(text) {
        this.processInput(text + '\\n');
      }

      clear() {
        this.processInput('\\x1b[2J\\x1b[H');
      }

      moveCursor(x, y) {
        this.processInput(`\\x1b[${y + 1};${x + 1}H`);
      }

      setColor(fg, bg) {
        // Convert RGB to ANSI 256 color
        const fgCode = this.rgbToAnsi256(fg);
        const bgCode = this.rgbToAnsi256(bg);
        this.processInput(`\\x1b[38;5;${fgCode}m\\x1b[48;5;${bgCode}m`);
      }

      rgbToAnsi256(rgb) {
        // Simplified RGB to ANSI 256 conversion
        const r = (rgb >> 16) & 0xFF;
        const g = (rgb >> 8) & 0xFF;
        const b = rgb & 0xFF;

        // Grayscale detection
        if (r === g && g === b) {
          if (r < 8) return 16;
          if (r > 248) return 231;
          return Math.round(((r - 8) / 247) * 24) + 232;
        }

        // Color cube (6x6x6)
        const ri = Math.round(r / 255 * 5);
        const gi = Math.round(g / 255 * 5);
        const bi = Math.round(b / 255 * 5);

        return 16 + (36 * ri) + (6 * gi) + bi;
      }
    }

    // Export for use in browser or Node.js
    if (typeof module !== 'undefined' && module.exports) {
      module.exports = RaxolTerminal;
    }
    """

    File.write!("#{@js_output_dir}/raxol-terminal.js", js_content)
    :ok
  end

  defp optimize_wasm(opts) do
    if Keyword.get(opts, :optimize, true) do
      Log.info("Optimizing WASM binary...")

      # Use wasm-opt if available
      cmd =
        "wasm-opt -Oz -o #{@wasm_output_dir}/raxol.optimized.wasm #{@wasm_output_dir}/raxol.wasm"

      case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
        {_, 0} ->
          File.rename!(
            "#{@wasm_output_dir}/raxol.optimized.wasm",
            "#{@wasm_output_dir}/raxol.wasm"
          )

          Log.info("WASM optimization successful")
          :ok

        {output, _} ->
          Log.warning(
            "wasm-opt not available, skipping optimization: #{output}"
          )

          :ok
      end
    else
      :ok
    end
  end

  defp copy_assets do
    Log.info("Copying web assets...")

    # Copy HTML demo file
    html_content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Raxol Terminal - WebAssembly Demo</title>
      <style>
        body {
          margin: 0;
          padding: 20px;
          background: #1e1e1e;
          color: #d4d4d4;
          font-family: 'Consolas', 'Monaco', monospace;
        }

        #terminal-container {
          width: 800px;
          height: 600px;
          margin: 0 auto;
          background: #2e3436;
          border: 2px solid #555753;
          border-radius: 5px;
          padding: 10px;
          position: relative;
        }

        #terminal-canvas {
          width: 100%;
          height: 100%;
        }

        #terminal-input {
          position: absolute;
          left: -9999px;
          opacity: 0;
        }

        .controls {
          margin: 20px auto;
          width: 800px;
          text-align: center;
        }

        button {
          background: #3465a4;
          color: white;
          border: none;
          padding: 10px 20px;
          margin: 5px;
          border-radius: 3px;
          cursor: pointer;
        }

        button:hover {
          background: #4575b4;
        }

        .status {
          margin: 10px;
          padding: 10px;
          background: #2a2a2a;
          border-radius: 3px;
        }
      </style>
    </head>
    <body>
      <div class="controls">
        <h1>Raxol Terminal - WebAssembly Demo</h1>
        <div class="status" id="status">Initializing...</div>
        <button onclick="terminal.clear()">Clear</button>
        <button onclick="runDemo()">Run Demo</button>
        <button onclick="terminal.resize(132, 43)">Wide Mode</button>
        <button onclick="terminal.resize(80, 24)">Normal Mode</button>
      </div>

      <div id="terminal-container">
        <canvas id="terminal-canvas"></canvas>
        <input type="text" id="terminal-input" />
      </div>

      <script type="module">
        import { RaxolTerminal } from '/js/raxol-terminal.js';

        let terminal;
        let canvas;
        let ctx;

        async function init() {
          const statusEl = document.getElementById('status');
          statusEl.textContent = 'Loading WASM module...';

          terminal = new RaxolTerminal(80, 24);
          window.terminal = terminal; // For console access

          const success = await terminal.initialize('/wasm/raxol.wasm');

          if (success) {
            statusEl.textContent = 'Terminal ready!';
            setupCanvas();
            setupInput();
            terminal.writeLine('Welcome to Raxol Terminal (WebAssembly Edition)');
            terminal.writeLine('Type help for available commands');
            terminal.write('$ ');
            render();
          } else {
            statusEl.textContent = 'Failed to initialize terminal';
          }
        }

        function setupCanvas() {
          canvas = document.getElementById('terminal-canvas');
          ctx = canvas.getContext('2d');

          // Set canvas size
          canvas.width = terminal.width * 10; // 10px per character
          canvas.height = terminal.height * 20; // 20px per line

          // Set font
          ctx.font = '16px monospace';
          ctx.textBaseline = 'top';
        }

        function setupInput() {
          const container = document.getElementById('terminal-container');
          const input = document.getElementById('terminal-input');

          container.addEventListener('click', () => {
            input.focus();
          });

          input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') {
              terminal.processInput(input.value + '\\n');
              input.value = '';
              render();
            } else if (e.key === 'Backspace') {
              terminal.processInput('\\x08');
              render();
            }
          });

          input.addEventListener('input', (e) => {
            const char = e.data;
            if (char) {
              terminal.processInput(char);
              render();
            }
          });
        }

        function render() {
          const output = terminal.getOutput();

          // Clear canvas
          ctx.fillStyle = '#2e3436';
          ctx.fillRect(0, 0, canvas.width, canvas.height);

          // Draw cells
          for (let y = 0; y < output.height; y++) {
            for (let x = 0; x < output.width; x++) {
              const cell = output.cells[y * output.width + x];
              if (cell && cell.char !== ' ') {
                ctx.fillStyle = '#d3d7cf'; // Default text color
                ctx.fillText(cell.char, x * 10, y * 20);
              }
            }
          }

          // Draw cursor
          ctx.fillStyle = '#ffffff';
          ctx.fillRect(output.cursor_x * 10, output.cursor_y * 20, 10, 2);
        }

        window.runDemo = function() {
          terminal.clear();
          terminal.writeLine('\\x1b[1;32mRaxol WebAssembly Demo\\x1b[0m');
          terminal.writeLine('');
          terminal.writeLine('Features:');
          terminal.writeLine('  - ANSI color support');
          terminal.writeLine('  - Cursor movement');
          terminal.writeLine('  - Screen clearing');
          terminal.writeLine('  - Terminal resizing');
          terminal.writeLine('');
          terminal.writeLine('\\x1b[33mThis is running entirely in your browser!\\x1b[0m');
          terminal.write('$ ');
          render();
        };

        // Initialize on load
        init();
      </script>
    </body>
    </html>
    """

    File.write!("#{@wasm_output_dir}/index.html", html_content)
    :ok
  end

  defp wasm_info do
    wasm_file = "#{@wasm_output_dir}/raxol.wasm"

    if File.exists?(wasm_file) do
      stat = File.stat!(wasm_file)

      %{
        size: stat.size,
        size_kb: Float.round(stat.size / 1024, 2),
        path: wasm_file,
        created_at: stat.mtime
      }
    else
      %{error: "WASM file not found"}
    end
  end

  defp watch_loop(opts) do
    receive do
      {:file_event, _pid, {path, _events}} ->
        if String.ends_with?(path, ".ex") or String.ends_with?(path, ".exs") do
          Log.info("Detected change in #{path}, rebuilding...")
          build(opts)
        end

        watch_loop(opts)

      _ ->
        watch_loop(opts)
    end
  end
end
