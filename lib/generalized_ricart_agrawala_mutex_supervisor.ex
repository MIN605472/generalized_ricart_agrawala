defmodule GeneralizedRicartAgrawalaMutex.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl true
  def init(members: members, exclude_matrix: exclude_matrix) do
    children = [
      {SharedVars, [members: members, exclude_matrix: exclude_matrix]},
      {Events, nil},
      {ReceiveReplyMsgs, nil},
      {ReceiveRequestMsgs, nil},
      {GeneralizedRicartAgrawalaMutex, members}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
