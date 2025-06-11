"""
A simple hello world script for testing the Raxol terminal emulator.
"""


def hello(name="World"):
    return f"Hello, {name}!"


def run(args=None):
    if args is None:
        args = []
    name = args[0] if args else "World"
    return hello(name)
