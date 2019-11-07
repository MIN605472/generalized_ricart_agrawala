defmodule DistributedMutexTest do
  use ExUnit.Case
  doctest Repositorio
  doctest DistributedMutex

  defp all_nodes_have_acquired_resource?(repository_nodes, ordered_events, num_ops_per_node) do
    repository_nodes
    |> Enum.map(fn node ->
      ordered_events
      |> Enum.map(fn {op, _, n, _} ->
        if op == :acquired_resource and n == node, do: 1, else: 0
      end)
      |> Enum.sum()
    end)
    |> Enum.all?(&(&1 == num_ops_per_node))
  end

  defp get_and_order_all_events(repository_nodes) do
    Enum.map(
      repository_nodes,
      &Task.Supervisor.async(
        {Repositorio.TaskSupervisor, &1},
        Events,
        :get_all,
        []
      )
    )
    |> Enum.map(&Task.yield/1)
    |> Enum.flat_map(fn {:ok, events} -> events end)
    |> Enum.sort(fn {_op1, clock1, node1, _opts1}, {_op2, clock2, node2, _opts2} ->
      clock1 < clock2 || (clock1 == clock2 && node1 < node2)
    end)
  end

  defp change_group_leaders(repository_nodes) do
    Enum.map(
      repository_nodes,
      &Task.Supervisor.async(
        {Repositorio.TaskSupervisor, &1},
        Repositorio,
        :change_all_group_leaders,
        [self()]
      )
    )
    |> Enum.each(&Task.await(&1, :infinity))
  end

  defp check_between(_repository_nodes, _events, -1, _j) do
    true
  end

  defp check_between(repository_nodes, events, i, j) do
    {:acquired_resource, _ts_i, node_i, [function: f_i]} = Enum.at(events, i)
    {:acquired_resource, _ts_j, node_j, [function: f_j]} = Enum.at(events, j)

    cond do
      not Repositorio.exclude_matrix()[f_i][f_j] ->
        true

      node_i == node_j ->
        Enum.slice(events, (i + 1)..(j - 1))
        |> Enum.count(fn {event_type, _ts, node, _opts} ->
          event_type == :rx_reply and node == node_j
        end)
        |> Kernel.==(Enum.count(repository_nodes) - 1)

      true ->
        slice = Enum.slice(events, (i + 1)..(j - 1))

        exited_event =
          Enum.find(slice, fn {event_type, _ts, node, _opts} ->
            event_type == :released_resource and node == node_i
          end)

        if exited_event != nil do
          Enum.find(slice, fn {event_type, ts, node, _opts} ->
            event_type == :tx_reply and node == node_i and ts > elem(exited_event, 1)
          end) != nil
        else
          false
        end
    end
  end

  defp mutual_exclusion?(events, repository_nodes) do
    events
    |> Enum.with_index()
    |> Enum.filter(fn {{event_type, _ts, _node, _opts}, _index} ->
      event_type == :acquired_resource
    end)
    |> Enum.map(fn {_event, index} -> index end)
    |> (&[-1 | &1]).()
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [i, j] -> check_between(repository_nodes, events, i, j) end)
    |> Enum.all?()
  end

  @tag timeout: :infinity
  test "check mutual exclusion with readers and writers" do
    repository_nodes = Application.get_env(Mix.Project.get().project[:app], :members)
    Enum.each(repository_nodes, fn n -> true = Node.connect(n) end)
    num_ops = 200
    # change_group_leaders(repository_nodes)
    Enum.map(
      repository_nodes,
      &Task.Supervisor.async(
        {Repositorio.TaskSupervisor, &1},
        Repositorio,
        :randomly_do_operations,
        [repository_nodes, num_ops]
      )
    )
    |> Enum.each(&Task.await(&1, :infinity))

    ordered_events = get_and_order_all_events(repository_nodes)
    IO.inspect(ordered_events, limit: :infinity)
    assert all_nodes_have_acquired_resource?(repository_nodes, ordered_events, num_ops)
    assert mutual_exclusion?(ordered_events, repository_nodes)
  end
end
