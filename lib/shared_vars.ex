defmodule SharedVars do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  def rx_request_msg(node, k, j, op) do
    GenServer.cast({__MODULE__, node}, {:rx_request_msg, k, j, op})
  end

  def rx_reply_msg(node, k, j) do
    GenServer.cast({__MODULE__, node}, {:rx_reply_msg, k, j})
  end

  def get_all() do
    GenServer.call(__MODULE__, :get_all, :infinity)
  end

  def acquire_resource(function) do
    GenServer.call(__MODULE__, {:acquire_resource, function}, :infinity)
  end

  def release_resource() do
    GenServer.call(__MODULE__, :release_resource, :infinity)
  end

  def members() do
    GenServer.call(__MODULE__, :members, :infinity)
  end

  def get_clock() do
    GenServer.call(__MODULE__, :get_clock, :infinity)
  end

  def increase_and_get_clock() do
    GenServer.call(__MODULE__, :increase_and_get_clock, :infinity)
  end

  def init(members: members, exclude_matrix: exclude_matrix) do
    {:ok,
     %{
       our_sequence_number: 0,
       highest_sequence_number: 0,
       outstanding_reply_count: 0,
       requesting_critical_section: false,
       reply_deferred: Map.new(members, &{&1, false}),
       defer_it: false,
       exclude: exclude_matrix,
       our_op: nil
     }}
  end

  def handle_cast({:rx_reply_msg, k, _j}, shared_vars) do
    Logger.metadata(node: Node.self())
    Logger.info("Before :rx_reply_msg: #{inspect(shared_vars)}")

    shared_vars = %{
      shared_vars
      | highest_sequence_number: max(shared_vars.highest_sequence_number, k) + 1,
        outstanding_reply_count: shared_vars.outstanding_reply_count - 1
    }

    Events.add(:rx_reply, shared_vars.highest_sequence_number, Node.self())

    DistributedMutex.wait_for(
      :outstanding_reply_count,
      shared_vars.outstanding_reply_count
    )

    Logger.info("After :rx_reply_msg: #{inspect(shared_vars)}")
    {:noreply, shared_vars}
  end

  def handle_cast({:rx_request_msg, k, j, op}, shared_vars) do
    Logger.metadata(node: Node.self())

    Logger.info(
      "Before :rx_request_msg: k=#{inspect(k)}, j=#{inspect(j)}, #{inspect(shared_vars)}"
    )

    shared_vars = %{
      shared_vars
      | highest_sequence_number: max(shared_vars.highest_sequence_number, k) + 1
    }

    Events.add(:rx_request, shared_vars.highest_sequence_number, Node.self())

    shared_vars = %{
      shared_vars
      | defer_it: defer_it?(shared_vars, k, j, op)
    }

    shared_vars =
      if shared_vars.defer_it do
        %{
          shared_vars
          | reply_deferred: Map.update!(shared_vars.reply_deferred, j, fn _ -> true end)
        }
      else
        shared_vars = %{
          shared_vars
          | highest_sequence_number: shared_vars.highest_sequence_number + 1
        }

        Events.add(:tx_reply, shared_vars.highest_sequence_number, Node.self())
        SharedVars.rx_reply_msg(j, shared_vars.highest_sequence_number, Node.self())
        shared_vars
      end

    Logger.info(
      "After :rx_request_msg: k=#{inspect(k)}, j=#{inspect(j)}, #{inspect(shared_vars)}"
    )

    {:noreply, shared_vars}
  end

  def handle_call(:get_all, _, shared_vars) do
    {:reply, shared_vars, shared_vars}
  end

  def handle_call({:acquire_resource, function}, _, shared_vars) do
    shared_vars = %{
      shared_vars
      | requesting_critical_section: true,
        our_sequence_number: shared_vars.highest_sequence_number + 1,
        highest_sequence_number: shared_vars.highest_sequence_number + 1,
        outstanding_reply_count: map_size(shared_vars.reply_deferred) - 1,
        our_op: function
    }

    {:reply, :ok, shared_vars}
  end

  def handle_call(:release_resource, _, shared_vars) do
    Logger.metadata(node: Node.self())
    Logger.info("Before :release_resource: #{inspect(shared_vars)}")

    shared_vars = %{
      shared_vars
      | requesting_critical_section: false,
        highest_sequence_number: shared_vars.highest_sequence_number + 1
    }

    Events.add(:released_resource, shared_vars.highest_sequence_number, Node.self())
    shared_vars = add_event_if_reply_deferred(shared_vars)
    send_reply_deferred(shared_vars)
    shared_vars = reset_reply_deferred(shared_vars)
    Logger.info("After :release_resource: #{inspect(shared_vars)}")
    {:reply, :ok, shared_vars}
  end

  def handle_call(:members, _, shared_vars) do
    members =
      shared_vars.reply_deferred
      |> Map.keys()
      |> Enum.reject(&(&1 == Node.self()))

    {:reply, members, shared_vars}
  end

  def handle_call(:get_clock, _, shared_vars) do
    clock = shared_vars.our_sequence_number
    {:reply, clock, shared_vars}
  end

  def handle_call(:increase_and_get_clock, _, shared_vars) do
    shared_vars = %{
      shared_vars
      | highest_sequence_number: shared_vars.highest_sequence_number + 1
    }

    {:reply, shared_vars.highest_sequence_number, shared_vars}
  end

  defp defer_it?(shared_vars, k, j, op) do
    shared_vars.requesting_critical_section &&
      (k > shared_vars.our_sequence_number ||
         (k == shared_vars.our_sequence_number && j > Node.self())) &&
      shared_vars.exclude[shared_vars.our_op][op]
  end

  defp add_event_if_reply_deferred(state) do
    state.reply_deferred
    |> Map.values()
    |> Enum.any?()
    |> if(
      do:
        (
          state = %{state | highest_sequence_number: state.highest_sequence_number + 1}
          Events.add(:tx_reply, state.highest_sequence_number, Node.self())
          state
        ),
      else: state
    )
  end

  defp send_reply_deferred(state) do
    state.reply_deferred
    |> Enum.filter(fn {_node, deferred?} -> deferred? end)
    |> Enum.each(fn {node, _deferred?} ->
      # ReceiveReplyMsgs.receive_reply_msg(node, state.highest_sequence_number, Node.self())
      SharedVars.rx_reply_msg(node, state.highest_sequence_number, Node.self())
    end)
  end

  defp reset_reply_deferred(state) do
    %{
      state
      | reply_deferred:
          state.reply_deferred
          |> Map.keys()
          |> Map.new(&{&1, false})
    }
  end
end
