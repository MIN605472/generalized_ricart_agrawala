# AUTOR: Rafael Tolosana Calasanz
# FICHERO: repositorio.ex
# FECHA: 17 de octubre de 2019
# TIEMPO: 1 hora
# DESCRIPCI'ON:  	Implementa un repositorio para gestionar el enunciado de un trabajo de asignatura.
# 				El enunciado tiene tres partes: resumen, parte principal y descripci'on de la entrega.
# 				El repositorio consta de un servidor que proporciona acceso individual a cada parte del enunciado,
# 				bien en lectura o bien en escritura				

defmodule Repositorio do
  def init do
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

  def randomly_do_operations(repository_pids, num_ops) do
    Process.sleep(round(:rand.uniform(100) / 100 * 2000))
    # IO.puts("hhii: #{inspect(Process.registered())}")
    send(
      {:invoke_me, Node.self()},
      {:invoke_me, __MODULE__,
       Enum.random([
         :update_resumen,
         :update_principal,
         :update_entrega,
         :read_resumen,
         :read_principal,
         :read_entrega
       ]), [repository_pids]}
    )

    randomly_do_operations(repository_pids, num_ops - 1)
  end

  def update_resumen(repository_pids) do
    update(:update_resumen, repository_pids)
  end

  def update_principal(repository_pids) do
    update(:update_principal, repository_pids)
  end

  def update_entrega(repository_pids) do
    update(:update_entrega, repository_pids)
  end

  def read_resumen(repository_pids) do
    read(:read_resumen, repository_pids)
  end

  def read_principal(repository_pids) do
    read(:read_principal, repository_pids)
  end

  def read_entrega(repository_pids) do
    read(:read_entrega, repository_pids)
  end

  defp update(what, repository_pids) do
    Enum.each(repository_pids, fn pid ->
      send(pid, {what, self(), :rand.uniform(1729)})

      receive do
        {:reply, :ok} -> nil
      end
    end)
  end

  defp read(what, repository_pids) do
    send(Enum.random(repository_pids), {what, self()})

    receive do
      {:reply, _contents} -> nil
    end
  end

  def identity(x) do
    x
  end
end
