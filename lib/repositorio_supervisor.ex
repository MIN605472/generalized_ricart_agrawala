defmodule Repositorio.Supervisor do
  use Supervisor

  def start_link(members) do
    exclude_matrix = [
      update_resumen: [
        update_resumen: true,
        update_principal: false,
        update_entrega: false,
        read_resumen: true,
        read_principal: false,
        read_entrega: false
      ],
      update_principal: [
        update_resumen: false,
        update_principal: true,
        update_entrega: false,
        read_resumen: false,
        read_principal: true,
        read_entrega: false
      ],
      update_entrega: [
        update_resumen: false,
        update_principal: false,
        update_entrega: true,
        read_resumen: false,
        read_principal: false,
        read_entrega: true
      ],
      read_resumen: [
        update_resumen: true,
        update_principal: false,
        update_entrega: false,
        read_resumen: false,
        read_principal: false,
        read_entrega: false
      ],
      read_principal: [
        update_resumen: false,
        update_principal: true,
        update_entrega: false,
        read_resumen: false,
        read_principal: false,
        read_entrega: false
      ],
      read_entrega: [
        update_resumen: false,
        update_principal: false,
        update_entrega: true,
        read_resumen: false,
        read_principal: false,
        read_entrega: false
      ]
    ]

    Supervisor.start_link(__MODULE__, [members: members, exclude_matrix: exclude_matrix],
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
