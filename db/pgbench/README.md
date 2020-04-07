# PiWS `pgbench` README

During real-world operation readings are taken every 5 seconds.
Using `-R .2` simulates this rate of data ingestion.

## Initialize

Seed with number of rows collected in 4 weeks (`-v scale=4`) of normal operation.
The following command takes about 5 minutes to run on a Raspberry Pi 3B.

> Note:  Dates start with 1/1/2018 and increment every 10 seconds.

```bash
psql -d piws -f ./init.sql -v scale=4
```

Run with a rate of 0.15 TPS.  Arduino sends readings at most every 5 seconds.  Real world collection shows every 6-8s is more likely.

```bash
pgbench -c 1 -j 1 -T 3600 -P 60  \
    -R .15  \
    -f ./insert_observation_test.sql \
    piws
```

Results:

```bash
number of clients: 1
number of threads: 1
duration: 120 s
number of transactions actually processed: 19
latency average = 58.399 ms
latency stddev = 108.854 ms
rate limit schedule lag: avg 14.168 (max 94.540) ms
tps = 0.158329 (including connections establishing)
tps = 0.158407 (excluding connections establishing)
```

uptime from 10 minutes into the run:

     21:45:08 up  1:50,  4 users,  load average: 1.20, 0.85, 0.61

and  `free -mh`

	              total        used        free      shared  buff/cache   available
	Mem:          926Mi       313Mi        35Mi       164Mi       577Mi       390Mi
	Swap:          99Mi        51Mi        48Mi



