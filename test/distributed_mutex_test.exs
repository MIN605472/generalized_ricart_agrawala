defmodule GeneralizedRicartAgrawalaTest do
  use ExUnit.Case
  doctest Repositorio
  doctest GeneralizedRicartAgrawalaMutex

  @tag timeout: :infinity
  # @tag disabled: true
  test "check mutual exclusion with readers and writers" do
    repository_nodes = Application.get_env(Mix.Project.get().project[:app], :members)

    Enum.map(
      repository_nodes,
      &Node.spawn_link(&1, Repositorio, :change_all_group_leaders, [self()])
    )

    Enum.map(
      repository_nodes,
      &Task.Supervisor.async(
        {Repositorio.TaskSupervisor, &1},
        Repositorio,
        :randomly_do_operations,
        [repository_nodes, 1]
      )
    )
    |> Enum.each(&Task.yield/1)

    Process.sleep(4000)

    ordered_events =
      Enum.flat_map(repository_nodes, fn node ->
        Agent.get({:events, node}, &Repositorio.identity/1)
      end)
      |> Enum.sort(fn {_op1, clock1, pid1}, {_op2, clock2, pid2} ->
        clock1 < clock2 || (clock1 == clock2 && pid1 < pid2)
      end)

    IO.inspect(ordered_events, limit: :infinity)
    Process.sleep(5000)
  end
end
