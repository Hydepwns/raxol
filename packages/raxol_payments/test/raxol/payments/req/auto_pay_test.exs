defmodule Raxol.Payments.Req.AutoPayTest do
  use ExUnit.Case, async: true

  alias Raxol.Payments.Req.AutoPay

  describe "attach/2" do
    test "adds auto_pay response step to the request" do
      req =
        Req.new(url: "https://example.com")
        |> AutoPay.attach(wallet: SomeWallet)

      step_names = Enum.map(req.response_steps, fn {name, _fun} -> name end)
      assert :auto_pay in step_names
    end

    test "preserves existing response steps" do
      noop = fn {req, resp} -> {req, resp} end

      req =
        Req.new(url: "https://example.com")
        |> Req.Request.append_response_steps(custom: noop)
        |> AutoPay.attach(wallet: SomeWallet)

      step_names = Enum.map(req.response_steps, fn {name, _fun} -> name end)
      assert :custom in step_names
      assert :auto_pay in step_names
    end
  end

  describe "non-402 passthrough" do
    test "200 response passes through unchanged" do
      req =
        Req.new(url: "https://example.com", retry: false)
        |> AutoPay.attach(wallet: SomeWallet)
        |> Req.Request.prepend_request_steps(
          stub: fn req ->
            {req, Req.Response.new(status: 200, body: "ok")}
          end
        )

      resp = Req.Request.run!(req)
      assert resp.status == 200
      assert resp.body == "ok"
    end

    test "500 response passes through unchanged" do
      req =
        Req.new(url: "https://example.com", retry: false)
        |> AutoPay.attach(wallet: SomeWallet)
        |> Req.Request.prepend_request_steps(
          stub: fn req ->
            {req, Req.Response.new(status: 500, body: "error")}
          end
        )

      resp = Req.Request.run!(req)
      assert resp.status == 500
      assert resp.body == "error"
    end
  end

  describe "402 with no matching protocol" do
    test "returns original 402 when no protocol headers match" do
      req =
        Req.new(url: "https://example.com", retry: false)
        |> AutoPay.attach(wallet: SomeWallet, protocols: [:x402, :mpp])
        |> Req.Request.prepend_request_steps(
          stub: fn req ->
            resp = Req.Response.new(status: 402, body: "payment required")
            {req, resp}
          end
        )

      resp = Req.Request.run!(req)
      assert resp.status == 402
      assert resp.body == "payment required"
    end
  end

  describe "auto_pay step removal on retry" do
    test "auto_pay step is not present after attach + strip cycle" do
      req =
        Req.new(url: "https://example.com")
        |> AutoPay.attach(wallet: SomeWallet)

      # Simulate what remove_auto_pay_step does internally
      stripped = %{
        req
        | response_steps: Enum.reject(req.response_steps, fn {name, _} -> name == :auto_pay end)
      }

      step_names = Enum.map(stripped.response_steps, fn {name, _fun} -> name end)
      refute :auto_pay in step_names
    end
  end
end
