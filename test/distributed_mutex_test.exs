defmodule GeneralizedRicartAgrawalaTest do
  use ExUnit.Case
  doctest Repositorio
  doctest GeneralizedRicartAgrawalaMutex

  @tag timeout: :infinity
  test "check mutual exclusion with readers and writers" do
    member_nodes = Application.get_env(Mix.Project.get().project[:app], :members)
    Enum.each(member_nodes, &Node.connect(&1))

    Enum.each(
      member_nodes,
      &Node.spawn(&1, GeneralizedRicartAgrawalaMutex, :init, [member_nodes])
    )

    repository_pids = Enum.map(member_nodes, &Node.spawn_link(&1, Repositorio, :init, []))

    Enum.each(
      member_nodes,
      &Node.spawn_link(&1, Repositorio, :randomly_do_operations, [repository_pids, 1])
    )

    Process.sleep(20_000)

    ordered_events =
      Enum.flat_map(member_nodes, fn node ->
        Agent.get({:events, node}, &Repositorio.identity/1)
      end)
      |> Enum.sort(fn {_op1, clock1, pid1}, {_op2, clock2, pid2} ->
        clock1 < clock2 || (clock1 == clock2 && pid1 < pid2)
      end)

    IO.inspect(ordered_events, limit: :infinity)
  end
end
