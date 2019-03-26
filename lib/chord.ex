defmodule App do
  use Application
  def start() do
      import Supervisor.Spec, warn: false

      children = [
          worker(Registry, [:unique, :process_registry])
      ]

      opts = [strategy: :one_for_one, name: App.Supervisor]
      Supervisor.start_link(children, opts)
  end
end

defmodule Chord do
    def run(args) do
      if(Enum.count(args)==2) do
        numNodes = String.to_integer(Enum.at(args,0))
        numRequests = String.to_integer(Enum.at(args,1))
        Server.start(self(), numNodes, numRequests)
        response() |> IO.inspect
      else
        IO.puts "Invalid arguments!"
      end
    end

    defp response do
      receive do
        result -> result
      end
    end
end

if(Enum.count(System.argv)>0) do
  Chord.run(System.argv)
end