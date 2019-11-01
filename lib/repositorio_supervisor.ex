defmodule Repositorio.Supervisor do
  use Supervisor

  def start_link(members) do
    Supervisor.start_link(
      __MODULE__,
      [members: members, exclude_matrix: Repositorio.exclude_matrix()],
      name: __MODULE__
    )
  end

  @impl true
  def init(args) do
    children = [
      %{id: :repository, start: {Repositorio, :start_repo_server, []}},
      {GeneralizedRicartAgrawalaMutex.Supervisor, args},
      {Task.Supervisor, name: Repositorio.TaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
