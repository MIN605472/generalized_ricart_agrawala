defmodule Rep do
  use Application

  @impl true
  def start(_type, _args) do
    Repositorio.Supervisor.start_link(
      Application.get_env(Mix.Project.get().project[:app], :members, [])
    )
  end
end
