defmodule Raxol.Payments.Req.AgentPluginTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Req.AgentPlugin

  describe "auto_pay/1" do
    test "returns a function" do
      plugin = AgentPlugin.auto_pay(wallet: SomeWallet)
      assert is_function(plugin, 1)
    end

    test "returned function attaches auto_pay step to Req request" do
      plugin = AgentPlugin.auto_pay(wallet: SomeWallet, protocols: [:x402])
      req = Req.new(url: "https://example.com")

      result = plugin.(req)

      step_names = Enum.map(result.response_steps, fn {name, _fn} -> name end)
      assert :auto_pay in step_names
    end

    test "preserves existing request options" do
      plugin = AgentPlugin.auto_pay(wallet: SomeWallet)

      req =
        Req.new(url: "https://example.com")
        |> Req.Request.put_header("x-existing", "value")

      result = plugin.(req)

      assert result.headers["x-existing"] == ["value"]
    end
  end
end
