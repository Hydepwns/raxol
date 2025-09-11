IO.puts("Testing Termbox2Nif loading...")

# Try to load the module
try do
  result = :termbox2_nif.tb_init()
  IO.puts("tb_init result: #{inspect(result)}")
rescue
  e ->
    IO.puts("Error loading NIF: #{inspect(e)}")
    IO.puts("Stacktrace: #{Exception.format_stacktrace(__STACKTRACE__)}")
end
