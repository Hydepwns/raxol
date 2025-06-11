-- A simple hello world script for testing the Raxol terminal emulator

function hello(name)
  name = name or "World"
  return "Hello, " .. name .. "!"
end

function run(args)
  local name = args[1] or "World"
  return hello(name)
end
