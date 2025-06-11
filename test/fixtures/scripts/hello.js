/**
 * A simple hello world script for testing the Raxol terminal emulator.
 */

function hello(name = "World") {
  return `Hello, ${name}!`;
}

function run(args = []) {
  const name = args[0] || "World";
  return hello(name);
}
