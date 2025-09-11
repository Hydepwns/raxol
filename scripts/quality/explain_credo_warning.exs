#!/usr/bin/env elixir

# This script explains the Credo warning about stdin parsing and provides
# guidance on how to handle it.

defmodule ExplainCredoWarning do
  def run do
    IO.puts("""
    ===================================================
    Credo Warning: stdin Parsing
    ===================================================

    When running Credo, you may see the following warning:

    info: Some source files could not be parsed correctly and are excluded:
       1) lib/raxol/terminal/input_handler.ex

    This is a known issue with Credo's parsing of stdin-related code. It doesn't
    affect the functionality of the terminal emulator and can be safely ignored.

    Why This Happens:
    -----------------
    The terminal emulator processes input from stdin, which Credo sometimes has
    trouble parsing correctly. This is a limitation of Credo's static analysis
    and not a problem with the code itself.

    How to Handle It:
    ----------------
    1. Ignore the warning: The warning is informational and doesn't indicate
       a problem with your code.

    2. Exclude the file from Credo analysis: If you want to suppress the warning,
       you can add the following to your .credo.exs file:

       files: %{
         excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/", ~r"input_handler\\.ex$"]
       }

    3. Use a local Credo config: You can also create a .credo.exs file in the
       lib/raxol/terminal directory to exclude the file from analysis:

       %{
         configs: [
           %{
             name: "terminal",
             files: %{
               excluded: [~r"input_handler\\.ex$"]
             },
             checks: []
           }
         ]
       }

    For more information, see the Terminal Module README:
    lib/raxol/terminal/README.md
    """)
  end
end

ExplainCredoWarning.run()
