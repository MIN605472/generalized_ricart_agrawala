defmodule GeneralizedRicartAgrawalaMutex do
  require Logger

  def start_receive_reply_messages() do
    pid = spawn_link(&receive_reply_messages/0)
    Process.register(pid, :receive_reply_messages)
    {:ok, pid}
  end

  def start_receive_request_messages() do
    pid = spawn_link(&receive_request_messages/0)
    Process.register(pid, :receive_request_messages)
    {:ok, pid}
  end

  def start_invoke_me() do
    pid = spawn_link(&invoke_me/0)
    Process.register(pid, :invoke_me)
    {:ok, pid}
  end

  # Use to block the current process till a message is sent with the
  # specified key-value pair.
  #
  ## Parameters:
  # - key: the key that the message should have
  # - value: the value that the message should have
  defp wait_for(key, value) do
    receive do
      {:wait_for, ^key, ^value} ->
        nil

      {:wait_for, _, _} ->
        wait_for(key, value)
    end
  end

  # Use to create a process that processes messages which contain a
  # specification of a function that should be executed in mutual
  # exclusion.
  defp invoke_me() do
    receive do
      {:invoke_me, module, function, arguments} ->
        invoke_mutual_exclusion(module, function, arguments)
    end

    invoke_me()
  end

  # Invoke the specified function in mutual exclusion.
  ## Parameters:
  #  - module: the atom of the modulo which contains the function
  #  - function: the atom of the function to be executed
  #  - arguments: the list of arguments to the function
  defp invoke_mutual_exclusion(module, function, arguments) do
    Logger.metadata(node: Node.self())
    # Request entry to our Critical Section
    # P(Shared_vars)
    # Choose a sequence number

    Agent.update(:shared_vars, fn state ->
      %{
        state
        | requesting_critical_section: true,
          our_sequence_number: state.highest_sequence_number + 1,
          highest_sequence_number: state.highest_sequence_number + 1,
          outstanding_reply_count: map_size(state.reply_deferred) - 1
      }
    end)

    # V(Shared_vars)
    members =
      Agent.get(:shared_vars, & &1.reply_deferred)
      |> Map.keys()
      |> Enum.reject(&(&1 == Node.self()))

    our_sequence_number = Agent.get(:shared_vars, & &1.our_sequence_number)
    Agent.update(:events, &[{:sent_enter, our_sequence_number, Node.self()} | &1])

    Enum.each(
      members,
      &send({:receive_request_messages, &1}, {our_sequence_number, Node.self()})
    )

    # Sent a REQUEST message containing our sequence number and our node number to all other nodes
    # Now wait for a REPLY from each of the other nodes
    Logger.info("Before wait_for(): #{inspect(Agent.get(:shared_vars, fn s -> s end))}")

    wait_for(:outstanding_reply_count, 0)
    # Critical Section Processing can be performed at this point
    Logger.info("In CS: #{inspect(Agent.get(:shared_vars, fn s -> s end))}")

    clock =
      Agent.get_and_update(
        :shared_vars,
        &{&1.highest_sequence_number + 1,
         %{&1 | highest_sequence_number: &1.highest_sequence_number + 1}}
      )

    Agent.update(:events, &[{function, clock, Node.self()} | &1])
    apply(module, function, arguments)
    # Release the Critical Section
    Logger.info("Before releasing CS: #{inspect(Agent.get(:shared_vars, fn s -> s end))}")

    Agent.update(:shared_vars, fn state ->
      state = %{
        state
        | requesting_critical_section: false
      }

      state.reply_deferred
      |> Map.values()
      |> Enum.any?(& &1)
      |> if(
        do:
          Agent.update(:events, &[{:sent_allow, state.highest_sequence_number, Node.self()} | &1])
      )

      state.reply_deferred
      |> Enum.filter(fn {_node, deferred?} -> deferred? end)
      |> Enum.each(fn {node, _deferred?} ->
        send({:receive_reply_messages, node}, {state.highest_sequence_number, Node.self()})
      end)

      %{
        state
        | reply_deferred:
            state.reply_deferred
            |> Map.keys()
            |> Map.new(&{&1, false})
      }
    end)

    Logger.info("After releasing CS: #{inspect(Agent.get(:shared_vars, fn s -> s end))}")
  end

  # Use to create a process that processes incoming messages that
  # request entrance to the critical section.
  defp receive_request_messages do
    Logger.metadata(node: Node.self())
    # k is the sequence number being requested
    # j is the node number making the request
    # P(shared_vars)
    receive do
      {k, j} ->
        Logger.info(
          "Received REQUEST k=#{inspect(k)}, j=#{inspect(j)}, #{
            inspect(Agent.get(:shared_vars, fn s -> s end))
          }"
        )

        Agent.update(:shared_vars, fn state ->
          state = %{state | highest_sequence_number: max(state.highest_sequence_number, k) + 1}

          Agent.update(
            :events,
            &[{:received_enter, state.highest_sequence_number, Node.self()} | &1]
          )

          state = %{
            state
            | defer_it:
                state.requesting_critical_section &&
                  (k > state.our_sequence_number ||
                     (k == state.our_sequence_number && j > Node.self()))
          }

          if state.defer_it do
            %{state | reply_deferred: Map.update!(state.reply_deferred, j, fn _ -> true end)}
          else
            state = %{state | highest_sequence_number: state.highest_sequence_number + 1}

            Agent.update(
              :events,
              &[{:sent_allow, state.highest_sequence_number, Node.self()} | &1]
            )

            send({:receive_reply_messages, j}, {state.highest_sequence_number, Node.self()})
            state
          end
        end)

        Logger.info("A: #{inspect(Agent.get(:shared_vars, fn s -> s end))}")
    end

    receive_request_messages()
  end

  # Use to create a process that processes messages coming from other
  # nodes that allow entrance to the critical section.
  defp receive_reply_messages() do
    receive do
      {k, _j} ->
        Logger.info("Received REPLY: #{inspect(Agent.get(:shared_vars, fn s -> s end))}")

        Agent.update(:shared_vars, fn state ->
          state = %{
            state
            | highest_sequence_number: max(state.highest_sequence_number, k) + 1,
              outstanding_reply_count: state.outstanding_reply_count - 1
          }

          Agent.update(
            :events,
            &[{:received_allow, state.highest_sequence_number, Node.self()} | &1]
          )

          send(:invoke_me, {:wait_for, :outstanding_reply_count, state.outstanding_reply_count})
          state
        end)
    end

    receive_reply_messages()
  end
end
