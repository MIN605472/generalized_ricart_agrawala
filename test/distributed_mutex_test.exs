defmodule GeneralizedRicartAgrawalaTest do
  use ExUnit.Case
  doctest Repositorio
  doctest GeneralizedRicartAgrawalaMutex

  @tag timeout: :infinity
  # @tag disabled: true
  test "check mutual exclusion with readers and writers" do
    repository_nodes = Application.get_env(Mix.Project.get().project[:app], :members)
    Enum.each(repository_nodes, &Node.connect/1)
    num_ops = 1

    Enum.map(
      repository_nodes,
      &Task.Supervisor.async(
        {Repositorio.TaskSupervisor, &1},
        Repositorio,
        :change_all_group_leaders,
        [self()]
      )
    )
    |> Enum.each(&Task.yield/1)

    Enum.map(
      repository_nodes,
      &Task.Supervisor.async(
        {Repositorio.TaskSupervisor, &1},
        Repositorio,
        :randomly_do_operations,
        [repository_nodes, num_ops]
      )
    )
    |> Enum.each(&Task.yield/1)

    ordered_events =
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
      |> Enum.sort(fn {_op1, clock1, pid1}, {_op2, clock2, pid2} ->
        clock1 < clock2 || (clock1 == clock2 && pid1 < pid2)
      end)

    IO.inspect(ordered_events, limit: :infinity)
  end
end
