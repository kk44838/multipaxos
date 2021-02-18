# Kazuya Kai-Olowu (kyk3218)
defmodule Configuration do

def node_id(config, node_type, node_num \\ "") do
  Map.merge config,
  %{
    node_type:     node_type,
    node_num:      node_num,
    node_name:     "#{node_type}#{node_num}",
    node_location: Util.node_string(),
  }
end

# -----------------------------------------------------------------------------

def params :default do
  %{
  max_requests: 50_000,		#50_000 max requests each client will make
  client_sleep: 2,		# time (ms) to sleep before sending new request
  client_stop:  60_000,		# time (ms) to stop sending further requests
  client_send:	:broadcast,	# :round_robin, :quorum or :broadcast

  n_accounts:   100,		# number of active bank accounts
  max_amount:   1_000,		# max amount moved between accounts

  print_after:  1_000,		# print transaction log summary every print_after msecs

  crash_server: %{}, # cause a server crash at a set time
  leader_election: :none, #default to no live-locking solution
  }
end

# -----------------------------------------------------------------------------
# Configuration with randomised backoff live-locking solution
def params :randomised_backoff do
  config = params :default
  _config = Map.put config, :leader_election, :randomised_backoff
end

def params :random_round_robin do
  config = params :default
  config = Map.put config, :client_send, :round_robin
  _config = Map.put config, :leader_election, :randomised_backoff

end

def params :random_quorum do
  config = params :default
  config = Map.put config, :client_send, :quorum
  _config = Map.put config, :leader_election, :randomised_backoff
end

# -----------------------------------------------------------------------------
# Configuration with exponential backoff and bully algorithm live-locking solution
def params :exponential_bully_backoff do
  config = params :default
  _config = Map.put config, :leader_election, :exponential_bully_backoff
end

# -----------------------------------------------------------------------------
# Configuration with exponential backoff live-locking solution
def params :exponential_backoff do
  config = params :default
  _config = Map.put config, :leader_election, :exponential_backoff
end

# -----------------------------------------------------------------------------
# Configurations for experiments

def params :server_1_crash_default_2_server_5_client do
  config = params :default
  _config = Map.put config, :crash_server, %{ 1 => 6000 }
end

def params :server_1_crash_random_backoff do
  config = params :default
  config = Map.put config, :leader_election, :randomised_backoff
  _config = Map.put config, :crash_server, %{ 1 => 3000 }
end

def params :three_server_crash_random_backoff do
  config = params :default
  config = Map.put config, :leader_election, :randomised_backoff
  _config = Map.put config, :crash_server, %{ 1 => 3000, 2 => 5000,  5 => 7000 }
end

# -----------------------------------------------------------------------------

def params :debug1 do		# same as :default with debug_level: 1
  config = params :default
 _config = Map.put config, :debug_level, 1
end

def params :debug3 do		# same as :default with debug_level: 3
  config = params :default
 _config = Map.put config, :debug_level, 3
end

# ADD YOUR OWN PARAMETER FUNCTIONS HERE

end # module ----------------------------------------------------------------
