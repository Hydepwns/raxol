defmodule RaxolPlaygroundWeb.Playground.DemoLifecycle do
  @moduledoc "Shared demo lifecycle management for playground and demo LiveViews."

  require Logger

  alias Raxol.Core.Runtime.Lifecycle
  import Phoenix.Component, only: [assign: 2]

  @doc "Starts a demo lifecycle for the given component."
  def start_demo(socket, component, opts \\ []) do
    timeout_ms = Keyword.get(opts, :timeout_ms)
    topic_prefix = Keyword.get(opts, :topic_prefix, "demo")

    if component && Phoenix.LiveView.connected?(socket) do
      topic =
        "#{topic_prefix}:#{inspect(self())}:#{System.unique_integer([:positive])}"

      try do
        Phoenix.PubSub.subscribe(Raxol.PubSub, topic)

        case Lifecycle.start_link(component.module,
               environment: :liveview,
               liveview_topic: topic,
               width: 80,
               height: 24
             ) do
          {:ok, pid} ->
            Process.monitor(pid)

            timer =
              if timeout_ms,
                do: Process.send_after(self(), :demo_timeout, timeout_ms)

            assign(socket,
              lifecycle_pid: pid,
              topic: topic,
              demo_timer: timer
            )

          {:error, reason} ->
            Logger.warning("Demo #{component.name} failed: #{inspect(reason)}")
            assign(socket, demo_error: "Failed to start demo")
        end
      rescue
        e ->
          Logger.warning("Demo #{component.name} failed: #{Exception.message(e)}")

          assign(socket, demo_error: "Failed to start demo")
      catch
        :exit, reason ->
          Logger.warning("Demo #{component.name} exit: #{inspect(reason)}")
          assign(socket, demo_error: "Failed to start demo")
      end
    else
      socket
    end
  end

  @doc "Stops the running demo lifecycle and cleans up."
  def stop_demo(socket) do
    if socket.assigns[:demo_timer] do
      Process.cancel_timer(socket.assigns.demo_timer)
    end

    if socket.assigns[:lifecycle_pid] do
      try do
        Lifecycle.stop(socket.assigns.lifecycle_pid)
      catch
        :exit, _ -> :ok
      end
    end

    if socket.assigns[:topic] do
      Phoenix.PubSub.unsubscribe(Raxol.PubSub, socket.assigns.topic)
    end

    assign(socket, lifecycle_pid: nil, topic: nil, demo_timer: nil)
  end

  @doc "Dispatches a translated key event to the running demo's Dispatcher."
  def dispatch_to_lifecycle(pid, event) do
    case GenServer.call(pid, :get_full_state, 5_000) do
      %{dispatcher_pid: dpid} when is_pid(dpid) ->
        GenServer.cast(dpid, {:dispatch, event})

      other ->
        Logger.debug("No dispatcher found in lifecycle state: #{inspect(other)}")

        :ok
    end
  rescue
    e ->
      Logger.debug("dispatch_to_lifecycle failed: #{Exception.message(e)}")
      :ok
  catch
    :exit, reason ->
      Logger.debug("dispatch_to_lifecycle exit: #{inspect(reason)}")
      :ok
  end
end
