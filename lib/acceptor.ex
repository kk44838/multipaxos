# Kazuya Kai-Olowu (kyk3218)
defmodule Acceptor do

    def start config do
      next config, {-1, nil}, MapSet.new
    end # start

    defp next config, ballot_num, accepted_set do

      receive do
      # Receive PREPARE (P1a) Message from Scout
      { :PREPARE, scout, b } -> 
        Debug.acceptor_receive(config, self(), :PREPARE, scout, b)

        # Keep the highest ballot number
        new_ballot_num = max ballot_num, b
        
        # Send PROMISE (P1b) Message back to Scout
        Debug.send(config, self(), scout, :PROMISE, [inspect(self()), new_ballot_num, accepted_set])
        send scout, { :PROMISE, self(), new_ballot_num, accepted_set }
        next config, new_ballot_num, accepted_set
      
      # Receive ACCEPT (P2a) Message from Commander
      { :ACCEPT, commander, { b, _, _ } = accept_msg } -> 
        Debug.acceptor_receive(config, self(), :PREPARE, commander, b)
        
        # Only updated accepted set if the ballot number received in the ACCEPT message 
        # is equal to current ballot number
        accepted_set = if b == ballot_num do
          new_accepted_set = MapSet.put(accepted_set, accept_msg)
          Debug.acceptor_accepted_set(config, self(), accept_msg)
          new_accepted_set
        else
          accepted_set
        end

        # Send ACCEPTED (P2b) message back to Commander
        Debug.send(config, self(), commander, :ACCEPTED, [inspect(self()), ballot_num])
        send commander, { :ACCEPTED, self(), ballot_num }
        next config, ballot_num, accepted_set

      unexpected ->
        Util.halt "Acceptor: unexpected message #{inspect unexpected}"

      end # receive

    end # next

    end # Acceptor
