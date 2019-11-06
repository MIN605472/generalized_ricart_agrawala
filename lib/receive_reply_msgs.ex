defmodule ReceiveReplyMsgs do
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def receive_reply_msg(node, k, j) do
    GenServer.cast({__MODULE__, node}, {:receive_reply_msg, k, j})
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_cast({:receive_reply_msg, k, _j}, state) do
    Logger.metadata(node: Node.self())
    Logger.info("Received REPLY: #{inspect(SharedVars.get_all())}")
    SharedVars.rx_reply_msg(k)
    {:noreply, state}
  end
end
