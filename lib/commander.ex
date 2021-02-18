# Kazuya Kai-Olowu (kyk3218)
defmodule Commander do

    def start config, leader, acceptors, replicas, pvalue do

      # Send ACCEPT (P2a) message to all acceptors
      for acceptor <- acceptors do
        Debug.send(config, self(), acceptor, :ACCEPT, [inspect(self()), pvalue])
        send acceptor, { :ACCEPT, self(), pvalue }
      end

      next config, leader, acceptors, replicas, pvalue, MapSet.new(acceptors)
      Debug.starting_process(config, :COMMANDER, self(), :LEADER, leader)
    end # start

    defp next config, leader, acceptors, replicas, pvalue, wait_for do
        { ballot_num, s, c } = pvalue

        # Receive ACCEPTED (P2b) nessage from an acceptor
        receive do
        { :ACCEPTED, acceptor, b } ->
          Debug.commander_receive(config, self(), :PROMISE, acceptor, b)

          # If the ballot number received in the ACCEPTED message is equal to 
          # current ballot number, remove the acceptor from the wait_for list
          # and check if majority achieved. 
        
          if b == ballot_num do
            wait_for = MapSet.delete(wait_for, acceptor)

            if MapSet.size(wait_for) < (length(acceptors) / 2) do

              # If majority achieved, send DECISION to all replicas.
                for replica <- replicas do
                  Debug.send(config, self(), replica, :DECISION, [s, c])
                  send replica, { :DECISION, s, c }
                end
                
                # Notify monitor that this commander is terminating then terminate
                send config.monitor, { :COMMANDER_FINISHED, config.node_num}
                Process.exit self(), :commander_normal
            end

            # If majority not achieved, wait ro recieve new message
            next config, leader, acceptors, replicas, pvalue, wait_for

          else
            # If ballot number recieved differs from current ballot number,
            # send PREEMPTED message to leader with ballot number recieved
            Debug.send(config, self(), leader, :PREEMPTED, [b])
            send leader, { :PREEMPTED, b }
            
            # Notify monitor that this commander is terminating then terminate
            send config.monitor, { :COMMANDER_FINISHED, config.node_num}
            Process.exit self(), :commander_normal
          end

        unexpected ->
          Util.halt "Commander: unexpected message #{inspect unexpected}"

      end # receive

    end # next

end # Commander
