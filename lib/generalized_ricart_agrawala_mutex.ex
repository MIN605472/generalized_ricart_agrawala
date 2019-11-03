defmodule GeneralizedRicartAgrawalaMutex do
  require Logger

  def start_link(_members) do
    pid = spawn_link(&invoke_me/0)
    Process.register(pid, __MODULE__)
    {:ok, pid}
  end

  def child_spec(members) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [members]}
    }
  end

  # Use to create a process that processes messages which contain a
  # specification of a function that should be executed in mutual
  # exclusion.
  defp invoke_me() do
    receive do
      {:invoke_me, pid, module, function, arguments} ->
        invoke_mutual_exclusion(module, function, arguments)
        send(pid, :invoke_me_done)
    end

    invoke_me()
  end

  @doc """
  Invoke the specified function in mutual exclusion.

  ## Parameters
    - module: the atom of the modulo which contains the function
    - function: the atom of the function to be executed
    - arguments: the list of arguments to the function
  """
  def invoke_in_mutual_exclusion(module, function, arguments) do
    send(__MODULE__, {:invoke_me, self(), module, function, arguments})

    receive do
      :invoke_me_done -> nil
    end
  end

  def wait_for(key, value) do
    send(__MODULE__, {:wait_for, key, value})
  end

  # Use to block the current process till a message is sent with the
  # specified key-value pair.
  #
  ## Parameters:
  # - key: the key that the message should have
  # - value: the value that the message should have
  defp wait_for_aux(key, value) do
    receive do
      {:wait_for, ^key, ^value} ->
        nil

      {:wait_for, _, _} ->
        wait_for_aux(key, value)
    end
  end

  # Invoke the specified function in mutual exclusion.
  ## Parameters:
  #  - module: the atom of the modulo which contains the function
  #  - function: the atom of the function to be executed
  #  - arguments: the list of arguments to the function
  defp invoke_mutual_exclusion(module, function, arguments) do
    Logger.metadata(node: Node.self())
    SharedVars.request_entry_to_cs(function)
    our_sequence_number = SharedVars.get_clock()
    Events.add(:sent_enter, our_sequence_number, Node.self())

    Enum.each(
      SharedVars.members(),
      &ReceiveRequestMsgs.receive_request_msg(&1, our_sequence_number, Node.self(), function)
    )

    # Sent a REQUEST message containing our sequence number and our node number to all other nodes
    # Now wait for a REPLY from each of the other nodes
    Logger.info("Before wait_for(): #{inspect(SharedVars.get_all())}")
    wait_for_aux(:outstanding_reply_count, 0)
    # Critical Section Processing can be performed at this point
    Logger.info("In CS: #{inspect(SharedVars.get_all())}")
    clock = SharedVars.increase_and_get_clock()
    Events.add(:enter_cs, clock, Node.self(), function: function)
    apply(module, function, arguments)
    # Release the Critical Section
    Logger.info("Before releasing CS: #{inspect(SharedVars.get_all())}")
    SharedVars.release_cs()
    Logger.info("After releasing CS: #{inspect(SharedVars.get_all())}")
  end
end
