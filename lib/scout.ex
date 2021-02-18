# Kazuya Kai-Olowu (kyk3218)
defmodule Scout do

    def start config, leader, acceptors, ballot_num do
      # Send PREPARE (P1a) message to all acceptors
      for acceptor <- acceptors do
        Debug.send(config, self(), acceptor, :PREPARE, [inspect(self()), ballot_num])
        send acceptor, { :PREPARE, self(), ballot_num }
      end

      next config, leader, acceptors, ballot_num, MapSet.new(acceptors), MapSet.new
      Debug.starting_process(config, :SCOUT, self(), :LEADER, leader)
    end # start

    defp next config, leader, acceptors, ballot_num, wait_for, pvalues do

        receive do
        # Receive PROMISE (P1a) nessage from an acceptor
        { :PROMISE, acceptor, b, accepted } ->
          Debug.scout_receive(config, self(), :PROMISE, acceptor, b)

          # If ballot number received is equal to current ballot number,
          # all the combined the accepted set from the acceptor with the pvalues set.
          # Then remove the acceptor the message was received from from the wait_for set,
          # and see if majority is achieved.
          if b == ballot_num do
            pvalues = MapSet.union(pvalues, accepted)

            wait_for = MapSet.delete(wait_for, acceptor)

            # If majority achieved, send ADOPTED to leader
            if MapSet.size(wait_for) < (length(acceptors) / 2) do
                Debug.send(config, self(), leader, :ADOPTED, [b, pvalues])
                send leader, { :ADOPTED, b, pvalues }

                # Notify monitor that this scout is terminating then terminate
                send config.monitor, { :SCOUT_FINISHED, config.node_num }
                Process.exit self(), :scout_normal
            else
              # If majority not achieved, wait ro recieve new message
              next config, leader, acceptors, ballot_num, wait_for, pvalues
            end
          else
            # If ballot number recieved differs from current ballot number,
            # send PREEMPTED message to leader with ballot number recieved
            Debug.send(config, self(), leader, :PREEMPTED, [b])
            send leader, { :PREEMPTED, b }

            # Notify monitor that this scout is terminating then terminate
            send config.monitor, { :SCOUT_FINISHED, config.node_num }
            Process.exit self(), :scout_normal
          end

        unexpected ->
          Util.halt "Scout: unexpected message #{inspect unexpected}"

      end # receive

    end # next

end # Scout
