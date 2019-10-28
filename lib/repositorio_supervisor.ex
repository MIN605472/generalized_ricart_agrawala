defmodule Repositorio.Supervisor do
  use Supervisor

  def start_link(members) do
    Supervisor.start_link(__MODULE__, members, name: __MODULE__)
  end

  @impl true
  def init(members) do
    children = [
      %{id: :repository, start: {Repositorio, :start_repo_server, []}},
      {GeneralizedRicartAgrawalaMutex.Supervisor, members},
      {Task.Supervisor, name: Repositorio.TaskSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
