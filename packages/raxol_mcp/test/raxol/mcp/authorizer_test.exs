defmodule Raxol.MCP.AuthorizerTest do
  # async: false -- the Deployment tests mutate the global :raxol_mcp app env.
  use ExUnit.Case, async: false

  alias Raxol.MCP.{Authorizer, Deployment, Registry, Server}

  defp add_tool do
    %{
      name: "add",
      description: "Add numbers",
      inputSchema: %{type: "object"},
      callback: fn args ->
        {:ok, [%{type: "text", text: "#{Map.get(args, "a", 0) + Map.get(args, "b", 0)}"}]}
      end
    }
  end

  defp secret_tool do
    %{
      name: "secret",
      description: "Reads the vault",
      inputSchema: %{type: "object"},
      callback: fn _args -> {:ok, [%{type: "text", text: "shh"}]} end
    }
  end

  defp list_tool_names(srv) do
    {:reply, resp} = Server.handle_message(srv, %{id: 7, method: "tools/list"})

    resp.result.tools
    |> Enum.map(fn tool -> Map.get(tool, :name) || Map.get(tool, "name") end)
    |> Enum.sort()
  end

  defp start_server(authorizer, tools \\ nil, opts \\ []) do
    tools = tools || [add_tool()]
    reg = :"reg_#{System.unique_integer([:positive])}"
    srv = :"srv_#{System.unique_integer([:positive])}"
    {:ok, _} = Registry.start_link(name: reg)
    Registry.register_tools(reg, tools)

    {:ok, _} =
      Server.start_link([name: srv, registry: reg, authorizer: authorizer] ++ opts)

    srv
  end

  defp call(srv, name \\ "add") do
    msg = %{
      id: 1,
      method: "tools/call",
      params: %{"name" => name, "arguments" => %{"a" => 2, "b" => 3}}
    }

    {:reply, resp} = Server.handle_message(srv, msg)
    resp
  end

  defp payload(resp) do
    resp.result.content |> hd() |> Map.fetch!(:text) |> Jason.decode!()
  end

  # The contained authorizer paths log at :error on purpose; keep that out of
  # the suite's output while still asserting on the response.
  defp capture_log_and_call(srv, name \\ "add") do
    {resp, _log} = ExUnit.CaptureLog.with_log(fn -> call(srv, name) end)
    resp
  end

  describe "Authorizer builders" do
    test "allow_all, deny_all, allowlist, and nil->allow" do
      assert :allow = Authorizer.decide(Authorizer.allow_all(), "x", %{}, %{})
      assert {:deny, :nope} = Authorizer.decide(Authorizer.deny_all(:nope), "x", %{}, %{})

      allow = Authorizer.allowlist(["ok"])
      assert :allow = Authorizer.decide(allow, "ok", %{}, %{})
      assert {:deny, :not_allowlisted} = Authorizer.decide(allow, "no", %{}, %{})

      # nil authorizer allows -- stdio inherits the OS process boundary.
      assert :allow = Authorizer.decide(nil, "anything", %{}, %{})
    end
  end

  describe "tools/call authorization" do
    test "no authorizer allows the tool to run (default)" do
      resp = call(start_server(nil))
      assert resp.result.content == [%{type: "text", text: "5"}]
      refute resp.result[:isError]
    end

    test "allow_all runs the tool" do
      resp = call(start_server(Authorizer.allow_all()))
      assert resp.result.content == [%{type: "text", text: "5"}]
    end

    test "deny returns a machine-readable authorization_required result, not the tool output" do
      resp = call(start_server(Authorizer.deny_all(:blocked)))
      assert resp.result.isError == true
      p = payload(resp)
      assert p["error"] == "authorization_required"
      assert p["tool"] == "add"
      assert p["decision"] == "deny"
      assert p["detail"] == ":blocked"
    end

    test "ASK is denied here (deny-on-ASK), surfacing decision=ask and the prompt as detail" do
      ask = fn _tool, _args, _ctx -> {:ask, "Approve add?"} end
      resp = call(start_server(ask))
      assert resp.result.isError == true
      p = payload(resp)
      assert p["error"] == "authorization_required"
      assert p["decision"] == "ask"
      assert p["detail"] == "Approve add?"
    end

    test "allowlist blocks tools not on the list" do
      resp = call(start_server(Authorizer.allowlist(["something_else"])))
      assert resp.result.isError == true
      assert payload(resp)["decision"] == "deny"
    end

    test "a denied call never reaches the tool callback" do
      test = self()

      spy = %{
        name: "spy",
        description: "records if it ran",
        inputSchema: %{type: "object"},
        callback: fn _args ->
          send(test, :callback_ran)
          {:ok, "x"}
        end
      }

      srv = start_server(Authorizer.deny_all(), [spy])
      call(srv, "spy")
      refute_received :callback_ran
    end

    test "an authorizer that raises denies, and does not take the server down" do
      test = self()

      spy = %{
        name: "spy",
        description: "records if it ran",
        inputSchema: %{type: "object"},
        callback: fn _args ->
          send(test, :callback_ran)
          {:ok, "x"}
        end
      }

      boom = fn _tool, _args, _ctx -> raise "policy blew up" end
      srv = start_server(boom, [spy])

      resp = capture_log_and_call(srv, "spy")

      assert resp.result.isError == true
      assert payload(resp)["decision"] == "deny"
      refute_received :callback_ran

      # The client picks when and how often to call, so a raise here is a lever
      # on the supervisor's restart intensity. The server must still be serving.
      assert Process.alive?(Process.whereis(srv))
      assert capture_log_and_call(srv, "spy").result.isError == true
    end

    test "an authorizer returning an off-contract term denies rather than crashing" do
      # `case` over Authorizer.decision() would raise CaseClauseError from
      # inside the same call, which is the crash above by another route.
      confused = fn _tool, _args, _ctx -> true end
      srv = start_server(confused)

      resp = capture_log_and_call(srv)

      assert resp.result.isError == true
      assert payload(resp)["decision"] == "deny"
      assert Process.alive?(Process.whereis(srv))
    end
  end

  describe "authorization context" do
    # An authorizer that cannot tell WHO is asking can only decide on the tool
    # name, which makes a stdio caller and an unauthenticated network client
    # the same principal. Both seams are handed the same server-derived facts.
    test "both seams are told the connection and the transport" do
      test = self()

      spy = fn _op, _args, ctx ->
        send(test, {:ctx, ctx})
        :allow
      end

      srv = start_server(spy, nil, transport: :sse, read_authorizer: spy)

      {:reply, resp} =
        Server.handle_message(
          srv,
          %{
            id: 1,
            method: "tools/call",
            params: %{"name" => "add", "arguments" => %{"a" => 2, "b" => 3}}
          },
          "conn-a"
        )

      assert resp.result.content == [%{type: "text", text: "5"}]
      assert_received {:ctx, %{conn_id: "conn-a", transport: :sse}}

      # The read seam is a separate call site into the authorizer, and it must
      # not hand policy a poorer context than the tool seam does.
      {:reply, _} =
        Server.handle_message(srv, %{id: 2, method: "resources/list"}, "conn-b")

      assert_received {:ctx, %{conn_id: "conn-b", transport: :sse}}
    end

    # Authorizing on a value the client asserts is a bypass: the client picks
    # the value. Only facts the server derives belong in the context.
    test "the context carries nothing the client asserted" do
      test = self()

      spy = fn _op, _args, ctx ->
        send(test, {:ctx, ctx})
        :allow
      end

      srv = start_server(spy, nil, transport: :sse)

      {:reply, _} =
        Server.handle_message(
          srv,
          %{
            id: 1,
            method: "initialize",
            params: %{
              "clientInfo" => %{"name" => "trusted-agent", "version" => "9.9"},
              "capabilities" => %{}
            }
          },
          "conn-a"
        )

      {:reply, _} =
        Server.handle_message(
          srv,
          %{id: 2, method: "tools/call", params: %{"name" => "add", "arguments" => %{}}},
          "conn-a"
        )

      assert_received {:ctx, ctx}

      # A tripwire, deliberately exact. Another SERVER-derived fact is welcome
      # here -- add it to this list. Anything the CLIENT asserted (the
      # clientInfo above, a header it chose) is a bypass wearing a policy's
      # clothes, and this assertion is what makes adding one a decision.
      assert Enum.sort(Map.keys(ctx)) == [:conn_id, :transport]
    end
  end

  describe "tools/list filtering" do
    # The method-level gate is about enumerating at all. Passing it used to
    # return the whole live surface, annotations included, so an accepted
    # client learned every tool it was about to be denied.
    test "a tool the authorizer denies is not advertised" do
      srv = start_server(Authorizer.allowlist(["add"]), [add_tool(), secret_tool()])

      assert list_tool_names(srv) == ["add"]
    end

    # An entry the caller cannot invoke without an approval it has not got is
    # not callable, so it must not advertise itself as callable.
    test "a tool the authorizer only ASKs about is hidden as well" do
      gated = fn
        "add", _args, _ctx -> :allow
        _tool, _args, _ctx -> {:ask, "Approve?"}
      end

      srv = start_server(gated, [add_tool(), secret_tool()])

      assert list_tool_names(srv) == ["add"]
    end

    test "a nil authorizer still lists everything" do
      srv = start_server(nil, [add_tool(), secret_tool()])

      assert list_tool_names(srv) == ["add", "secret"]
    end

    # Filtering runs operator code once per tool on a client-driven path, so a
    # policy that raises must cost the tool its listing, not the server its
    # life -- the client picks how often to ask.
    test "a raising authorizer hides the tool instead of crashing the server" do
      boom = fn
        "add", _args, _ctx -> :allow
        _tool, _args, _ctx -> raise "policy blew up"
      end

      srv = start_server(boom, [add_tool(), secret_tool()])

      {names, _log} = ExUnit.CaptureLog.with_log(fn -> list_tool_names(srv) end)

      assert names == ["add"]
      assert Process.alive?(Process.whereis(srv))
    end
  end

  describe "authorization_configured?/1" do
    # NOT `authorizer != nil`. A framework may supply a restrictive fallback,
    # and the value alone cannot be told apart from a policy an operator wrote,
    # so treating the fallback as configured would satisfy the SSE boot gate
    # with a default -- removing the forcing function the gate exists to be.
    test "requires an authorizer AND a :configured source" do
      assert Server.authorization_configured?(
               start_server(Authorizer.allow_all(), nil, authorizer_source: :configured)
             )

      refute Server.authorization_configured?(
               start_server(nil, nil, authorizer_source: :configured)
             )
    end

    test "a :default source answers false however strict the authorizer" do
      # deny_all is as strict as an authorizer gets, and it still must not open
      # a network transport: nobody DECIDED that this server should serve.
      refute Server.authorization_configured?(
               start_server(Authorizer.deny_all(), nil, authorizer_source: :default)
             )
    end

    test "the source defaults to :default, so a forgetful embedder fails closed" do
      refute Server.authorization_configured?(start_server(Authorizer.allow_all()))
    end

    test "returns false for an unreachable server" do
      refute Server.authorization_configured?(:no_such_server)
    end
  end

  describe "Deployment.production?/0 outside a mix session" do
    test "an unstarted Mix reads as production instead of raising" do
      # `Code.ensure_loaded?(Mix)` is true in any node with Elixir's stdlib on
      # the code path, but `Mix.env/0` reads `:ets.lookup(Mix.State, :env)` and
      # needs the `:mix` APPLICATION running. `elixir -e` loads Mix and does not
      # start it, which is the same shape as an escript or a release shipping
      # `:mix` unstarted -- and this predicate is on
      # `Raxol.Application.start/2`'s `:mcp` path, so it raised at boot.
      #
      # Run in a real separate node because this suite runs UNDER mix, where
      # the broken environment cannot be reproduced in-process.
      ebin = Application.app_dir(:raxol_mcp, "ebin")

      {out, status} =
        System.cmd(
          "elixir",
          ["-pa", ebin, "-e", "IO.write(inspect(Raxol.MCP.Deployment.production?()))"],
          stderr_to_stdout: true
        )

      assert status == 0,
             "production?/0 crashed in a node with Mix loaded but not started:\n#{out}"

      # Fail-closed: an environment the predicate cannot identify is production.
      assert out =~ "true"
    end
  end

  describe "Deployment gate" do
    setup do
      on_exit(fn -> Application.delete_env(:raxol_mcp, :require_authorization) end)
    end

    test "require_authorization? defaults to false in test and honors the override" do
      refute Deployment.require_authorization?()
      Application.put_env(:raxol_mcp, :require_authorization, true)
      assert Deployment.require_authorization?()
    end

    test "enforce_authorization! is a no-op when configured or not required" do
      assert :ok = Deployment.enforce_authorization!(true, "x")
      assert :ok = Deployment.enforce_authorization!(false, "x")
    end

    test "enforce_authorization! fails closed when required and no authorizer is configured" do
      Application.put_env(:raxol_mcp, :require_authorization, true)

      assert_raise ArgumentError, ~r/refuses to boot/, fn ->
        Deployment.enforce_authorization!(false, "MCP SSE transport")
      end

      # ...but a configured authorizer boots even when required.
      assert :ok = Deployment.enforce_authorization!(true, "MCP SSE transport")
    end
  end
end
