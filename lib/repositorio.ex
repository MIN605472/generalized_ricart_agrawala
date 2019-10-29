# AUTOR: Rafael Tolosana Calasanz
# FICHERO: repositorio.ex
# FECHA: 17 de octubre de 2019
# TIEMPO: 1 hora
# DESCRIPCI'ON:  	Implementa un repositorio para gestionar el enunciado de un trabajo de asignatura.
# 				El enunciado tiene tres partes: resumen, parte principal y descripci'on de la entrega.
# 				El repositorio consta de un servidor que proporciona acceso individual a cada parte del enunciado,
# 				bien en lectura o bien en escritura

defmodule Repositorio do
  def start_repo_server() do
    pid = spawn_link(&repo_server/0)
    Process.register(pid, :repository)
    {:ok, pid}
  end

  defp repo_server() do
    repo_server({"", "", ""})
  end

  defp repo_server({resumen, principal, entrega}) do
    {n_resumen, n_principal, n_entrega} =
      receive do
        {:update_resumen, c_pid, descripcion} ->
          send(c_pid, {:reply, :ok})
          {descripcion, principal, entrega}

        {:update_principal, c_pid, descripcion} ->
          send(c_pid, {:reply, :ok})
          {resumen, descripcion, entrega}

        {:update_entrega, c_pid, descripcion} ->
          send(c_pid, {:reply, :ok})
          {resumen, principal, descripcion}

        {:read_resumen, c_pid} ->
          send(c_pid, {:reply, resumen})
          {resumen, principal, entrega}

        {:read_principal, c_pid} ->
          send(c_pid, {:reply, principal})
          {resumen, principal, entrega}

        {:read_entrega, c_pid} ->
          send(c_pid, {:reply, entrega})
          {resumen, principal, entrega}
      end

    repo_server({n_resumen, n_principal, n_entrega})
  end

  def randomly_do_operations(_, 0) do
  end

  def randomly_do_operations(repository_nodes, num_ops) do
    Process.sleep(round(:rand.uniform(100) / 100 * 2000))

    fun =
      Enum.random([
        :update_resumen,
        :update_principal,
        :update_entrega,
        :read_resumen,
        :read_principal,
        :read_entrega
      ])

    GeneralizedRicartAgrawalaMutex.invoke_in_mutual_exclusion(__MODULE__, fun, [repository_nodes])

    randomly_do_operations(repository_nodes, num_ops - 1)
  end

  def update_resumen(repository_nodes) do
    update(:update_resumen, repository_nodes)
  end

  def update_principal(repository_nodes) do
    update(:update_principal, repository_nodes)
  end

  def update_entrega(repository_nodes) do
    update(:update_entrega, repository_nodes)
  end

  def read_resumen(repository_nodes) do
    read(:read_resumen, repository_nodes)
  end

  def read_principal(repository_nodes) do
    read(:read_principal, repository_nodes)
  end

  def read_entrega(repository_nodes) do
    read(:read_entrega, repository_nodes)
  end

  defp update(what, repository_nodes) do
    Enum.each(repository_nodes, fn node ->
      send({:repository, node}, {what, self(), :rand.uniform(1729)})
    end)

    Enum.each(repository_nodes, fn _node ->
      receive do
        {:reply, :ok} -> nil
      end
    end)
  end

  defp read(what, repository_nodes) do
    send({:repository, Enum.random(repository_nodes)}, {what, self()})

    receive do
      {:reply, _contents} -> nil
    end
  end

  def identity(x) do
    x
  end

  def change_all_group_leaders(pid) do
    Process.group_leader(Process.whereis(:user), pid)
    Process.group_leader(Process.whereis(Repositorio.Supervisor), pid)
    Process.list() |> Enum.each(&(&1 |> Process.group_leader(pid)))
  end
end
