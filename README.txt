# Kazuya Kai-Olowu (kyk3218)

# make options for Multipaxos

CLEAN UP
--------
make clean       - remove compiled code
make compile     - compile 

make run         - same as make run SERVERS=5 CLIENTS=5 CONFIG=default DEBUG=0 MAX_TIME=15000
                 - used for default_5_server_5_client.txt


The Live-locking solutions:

make random              - randomised_backoff.txt
make exponential         - exponential_backoff.txt
make exponential_bully   - exponential_bully_backoff.txt

Client Send Strategies:
make random_round_robin  - random_round_robin.txt
make random_quorum.txt   - random_quorum.txt


Experiments:

make default_2_server_5_client                  - default_2_server_5_client.txt
make server_1_crash_default_2_server_5_client   - server_1_crash_default_2_server_5_client.txt
make server_1_crash_random_backoff              - server_1_crash_random_backoff.txt
make three_server_crash_random_backoff              - 3_server_crash_random_backoff.txt