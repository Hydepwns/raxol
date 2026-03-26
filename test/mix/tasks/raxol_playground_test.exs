defmodule Mix.Tasks.Raxol.PlaygroundTest do
  use ExUnit.Case, async: true

  describe "option parsing" do
    test "parses --ssh flag" do
      {opts, _, _} =
        OptionParser.parse(["--ssh"],
          strict: [ssh: :boolean, port: :integer, max_connections: :integer],
          aliases: [p: :port]
        )

      assert opts[:ssh] == true
    end

    test "parses --ssh with --port" do
      {opts, _, _} =
        OptionParser.parse(["--ssh", "--port", "3333"],
          strict: [ssh: :boolean, port: :integer, max_connections: :integer],
          aliases: [p: :port]
        )

      assert opts[:ssh] == true
      assert opts[:port] == 3333
    end

    test "parses -p alias for port" do
      {opts, _, _} =
        OptionParser.parse(["--ssh", "-p", "4444"],
          strict: [ssh: :boolean, port: :integer, max_connections: :integer],
          aliases: [p: :port]
        )

      assert opts[:port] == 4444
    end

    test "parses --max-connections" do
      {opts, _, _} =
        OptionParser.parse(["--ssh", "--max-connections", "10"],
          strict: [ssh: :boolean, port: :integer, max_connections: :integer],
          aliases: [p: :port]
        )

      assert opts[:max_connections] == 10
    end

    test "no flags defaults to terminal mode" do
      {opts, _, _} =
        OptionParser.parse([],
          strict: [ssh: :boolean, port: :integer, max_connections: :integer],
          aliases: [p: :port]
        )

      assert opts[:ssh] == nil
    end
  end
end
