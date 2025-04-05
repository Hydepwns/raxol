defmodule Raxol.Terminal.ANSI.Processor do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(_) do
    {:ok, %{}}
  end

  def process_sequence(sequence) do
    GenServer.call(__MODULE__, {:process_sequence, sequence})
  end

  def handle_call({:process_sequence, sequence}, _from, state) do
    # TODO: Implement ANSI sequence processing
    {:reply, sequence, state}
  end
end 