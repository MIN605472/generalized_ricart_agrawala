defmodule ReceiveRequestMsgs do
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def receive_request_msg(node, k, j, op) do
    GenServer.cast({__MODULE__, node}, {:receive_request_msg, k, j, op})
  end

  def init(_) do
    {:ok, nil}
  end

  def handle_cast({:receive_request_msg, k, j, op}, state) do
    # k is the sequence number being requested
    # j is the node number making the request
    Logger.metadata(node: Node.self())

    Logger.info(
      "Before REQUEST k=#{inspect(k)}, j=#{inspect(j)}, #{inspect(SharedVars.get_all())}"
    )

    SharedVars.rx_request_msg(k, j, op)

    Logger.info(
      "After REQUEST k=#{inspect(k)}, j=#{inspect(j)}, #{inspect(SharedVars.get_all())}"
    )

    {:noreply, state}
  end
end
