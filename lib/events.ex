defmodule Events do
  use GenServer

  def start_link(_) do
    GenServer.start_link(Events, nil, name: __MODULE__)
  end

  def add(event) do
    GenServer.cast(__MODULE__, {:add, event})
  end

  def get_all() do
    GenServer.call(__MODULE__, :get_all)
  end

  def init(_) do
    {:ok, []}
  end

  def handle_cast({:add, event}, events) do
    {:noreply, [event | events]}
  end

  def handle_call(:get_all, _, events) do
    {:reply, events, events}
  end
end
