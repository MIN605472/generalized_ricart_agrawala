defmodule GeneralizedRicartAgrawalaMutex.Supervisor do
  use Supervisor

  def start_link(members) do
    Supervisor.start_link(__MODULE__, members, name: __MODULE__)
  end

  @impl true
  def init(members) do
    children = [
      %{
        id: :shared_vars,
        start:
          {Agent, :start_link,
           [
             fn ->
               %{
                 our_sequence_number: 0,
                 highest_sequence_number: 0,
                 outstanding_reply_count: 0,
                 requesting_critical_section: false,
                 reply_deferred: Map.new(members, &{&1, false}),
                 defer_it: false
               }
             end,
             [name: :shared_vars]
           ]}
      },
      %{id: :events, start: {Agent, :start_link, [fn -> [] end, [name: :events]]}},
      %{
        id: :receive_reply_messages,
        start: {GeneralizedRicartAgrawalaMutex, :start_receive_reply_messages, []}
      },
      %{
        id: :receive_request_messages,
        start: {GeneralizedRicartAgrawalaMutex, :start_receive_request_messages, []}
      },
      %{
        id: :invoke_me,
        start: {GeneralizedRicartAgrawalaMutex, :start_invoke_me, []}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
