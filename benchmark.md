# Benchmark Summary

| Scenario | Seq Read BW | Seq Write BW | Rand Read BW / IOPS | Rand Write BW / IOPS |
| --- | --- | --- | --- | --- |
| Initial (no O_DIRECT) | 2008 MiB/s | 2236 MiB/s | 309 MiB/s · 79k IOPS | 346 MiB/s · 89k IOPS |
| Release (no O_DIRECT) | 509 MiB/s | 2306 MiB/s | 203 MiB/s · 52k IOPS | 276 MiB/s · 71k IOPS |
| O_DIRECT (debug build) | 928 MiB/s | 2926 MiB/s | 418 MiB/s · 107k IOPS | 413 MiB/s · 106k IOPS |
| O_DIRECT (release build) | 659 MiB/s | 3180 MiB/s | 453 MiB/s · 116k IOPS | 395 MiB/s · 101k IOPS |
| Cloud Hypervisor (1 vCPU / 1 blk queue) | 2560 MiB/s | 2169 MiB/s | 871 MiB/s · 223k IOPS | 1174 MiB/s · 301k IOPS |

## Raw logs

## Initial brenchmark no O_DIRECT

=== Running seq-read (read, bs=1M) ===
seq-read: (g=0): rw=read, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=32
fio-3.41
[    1.128314] clocksource: tsc: mask: 0xffffffffffffffff max_cycles: 0x731a4fe6be0, max_idle_ns: 881591041362 ns
[    1.128622] clocksource: Switched to clocksource tsc
Starting 1 process

seq-read: (groupid=0, jobs=1): err= 0: pid=591: Sun Aug 22 20:20:21 2021
  read: IOPS=2007, BW=2008MiB/s (2105MB/s)(512MiB/255msec)
    slat (usec): min=32, max=1817, avg=68.16, stdev=131.35
    clat (usec): min=759, max=251572, avg=15260.95, stdev=55889.14
     lat (usec): min=795, max=253390, avg=15329.11, stdev=55972.25
    clat percentiles (usec):
     |  1.00th=[   775],  5.00th=[   832], 10.00th=[   865], 20.00th=[   979],
     | 30.00th=[  1139], 40.00th=[  1254], 50.00th=[  1385], 60.00th=[  1565],
     | 70.00th=[  1680], 80.00th=[  1795], 90.00th=[  2180], 95.00th=[238027],
     | 99.00th=[248513], 99.50th=[250610], 99.90th=[250610], 99.95th=[250610],
     | 99.99th=[250610]
  lat (usec)   : 1000=22.27%
  lat (msec)   : 2=65.23%, 4=4.49%, 10=1.37%, 20=0.98%, 250=5.08%
  lat (msec)   : 500=0.59%
  cpu          : usr=0.79%, sys=10.63%, ctx=1019, majf=0, minf=8201
  IO depths    : 1=0.2%, 2=0.4%, 4=0.8%, 8=1.6%, 16=3.1%, 32=93.9%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.8%, 8=0.0%, 16=0.0%, 32=0.2%, 64=0.0%, >=64=0.0%
     issued rwts: total=512,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=2008MiB/s (2105MB/s), 2008MiB/s-2008MiB/s (2105MB/s-2105MB/s), io=512MiB (537MB), run=255-255msec

Disk stats (read/write):
  vda: ios=546/0, sectors=559104/0, merge=0/0, ticks=570/0, in_queue=570, util=56.90%
=== Running seq-write (write, bs=1M) ===
seq-write: (g=0): rw=write, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process

seq-write: (groupid=0, jobs=1): err= 0: pid=595: Sun Aug 22 20:20:22 2021
  write: IOPS=2235, BW=2236MiB/s (2344MB/s)(512MiB/229msec); 0 zone resets
    slat (usec): min=18, max=486, avg=58.75, stdev=29.36
    clat (usec): min=1964, max=27179, avg=14152.64, stdev=2837.70
     lat (usec): min=2042, max=27227, avg=14211.40, stdev=2837.42
    clat percentiles (usec):
     |  1.00th=[ 3294],  5.00th=[11076], 10.00th=[13435], 20.00th=[13566],
     | 30.00th=[13698], 40.00th=[13698], 50.00th=[13829], 60.00th=[13829],
     | 70.00th=[14091], 80.00th=[14615], 90.00th=[16581], 95.00th=[16909],
     | 99.00th=[25035], 99.50th=[26346], 99.90th=[27132], 99.95th=[27132],
     | 99.99th=[27132]
  lat (msec)   : 2=0.20%, 4=1.17%, 10=2.93%, 20=92.19%, 50=3.52%
  cpu          : usr=14.47%, sys=5.26%, ctx=482, majf=0, minf=8
  IO depths    : 1=0.2%, 2=0.4%, 4=0.8%, 8=1.6%, 16=3.1%, 32=93.9%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.8%, 8=0.0%, 16=0.0%, 32=0.2%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,512,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
  WRITE: bw=2236MiB/s (2344MB/s), 2236MiB/s-2236MiB/s (2344MB/s-2344MB/s), io=512MiB (537MB), run=229-229msec

Disk stats (read/write):
  vda: ios=0/273, sectors=0/559104, merge=0/0, ticks=0/3638, in_queue=3639, util=50.21%
=== Running rand-read (randread, bs=4k) ===
rand-read: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process
Jobs: 1 (f=1)
rand-read: (groupid=0, jobs=1): err= 0: pid=599: Sun Aug 22 20:20:24 2021
  read: IOPS=79.1k, BW=309MiB/s (324MB/s)(512MiB/1658msec)
    slat (usec): min=3, max=842, avg= 9.19, stdev=14.54
    clat (usec): min=2, max=2757, avg=394.56, stdev=110.53
     lat (usec): min=43, max=2761, avg=403.75, stdev=112.21
    clat percentiles (usec):
     |  1.00th=[  169],  5.00th=[  200], 10.00th=[  262], 20.00th=[  383],
     | 30.00th=[  388], 40.00th=[  396], 50.00th=[  404], 60.00th=[  420],
     | 70.00th=[  433], 80.00th=[  441], 90.00th=[  457], 95.00th=[  478],
     | 99.00th=[  545], 99.50th=[  652], 99.90th=[ 2057], 99.95th=[ 2376],
     | 99.99th=[ 2671]
   bw (  KiB/s): min=314600, max=322048, per=100.00%, avg=317237.67, stdev=4172.35, samples=3
   iops        : min=78650, max=80512, avg=79309.33, stdev=1043.15, samples=3
  lat (usec)   : 4=0.01%, 50=0.01%, 100=0.01%, 250=8.94%, 500=88.72%
  lat (usec)   : 750=1.93%, 1000=0.14%
  lat (msec)   : 2=0.15%, 4=0.11%
  cpu          : usr=21.97%, sys=75.80%, ctx=849, majf=0, minf=39
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=100.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.1%, 64=0.0%, >=64=0.0%
     issued rwts: total=131072,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=309MiB/s (324MB/s), 309MiB/s-309MiB/s (324MB/s-324MB/s), io=512MiB (537MB), run=1658-1658msec

Disk stats (read/write):
  vda: ios=129672/0, sectors=1037376/0, merge=0/0, ticks=5726/0, in_queue=5726, util=37.05%
=== Running rand-write (randwrite, bs=4k) ===
rand-write: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process
Jobs: 1 (f=1)
rand-write: (groupid=0, jobs=1): err= 0: pid=603: Sun Aug 22 20:20:26 2021
  write: IOPS=88.5k, BW=346MiB/s (363MB/s)(512MiB/1481msec); 0 zone resets
    slat (usec): min=3, max=738, avg= 9.30, stdev=14.78
    clat (usec): min=131, max=3619, avg=351.58, stdev=105.56
     lat (usec): min=136, max=3674, avg=360.89, stdev=107.67
    clat percentiles (usec):
     |  1.00th=[  172],  5.00th=[  196], 10.00th=[  219], 20.00th=[  281],
     | 30.00th=[  330], 40.00th=[  355], 50.00th=[  363], 60.00th=[  375],
     | 70.00th=[  392], 80.00th=[  404], 90.00th=[  424], 95.00th=[  445],
     | 99.00th=[  515], 99.50th=[  701], 99.90th=[ 1385], 99.95th=[ 2008],
     | 99.99th=[ 3294]
   bw (  KiB/s): min=340712, max=361397, per=98.67%, avg=349284.33, stdev=10787.39, samples=3
   iops        : min=85178, max=90349, avg=87321.00, stdev=2696.71, samples=3
  lat (usec)   : 250=14.19%, 500=84.62%, 750=0.74%, 1000=0.18%
  lat (msec)   : 2=0.23%, 4=0.05%
  cpu          : usr=18.24%, sys=79.32%, ctx=1009, majf=0, minf=8
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=100.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.1%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,131072,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
  WRITE: bw=346MiB/s (363MB/s), 346MiB/s-346MiB/s (363MB/s-363MB/s), io=512MiB (537MB), run=1481-1481msec

Disk stats (read/write):
  vda: ios=0/122848, sectors=0/982784, merge=0/0, ticks=0/7125, in_queue=7125, util=51.95%
fio benchmarks complete, rebooting

## Release mode no O_DIRECT

=== Running seq-read (read, bs=1M) ===
seq-read: (g=0): rw=read, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=32
fio-3.41
[    1.128382] clocksource: tsc: mask: 0xffffffffffffffff max_cycles: 0x7318c54f115, max_idle_ns: 881591126272 ns
[    1.128625] clocksource: Switched to clocksource tsc
Starting 1 process
Jobs: 1 (f=1)
seq-read: (groupid=0, jobs=1): err= 0: pid=594: Sun Aug 22 20:20:22 2021
  read: IOPS=508, BW=509MiB/s (534MB/s)(512MiB/1006msec)
    slat (usec): min=35, max=678, avg=96.52, stdev=90.73
    clat (msec): min=2, max=1004, avg=62.30, stdev=234.15
     lat (msec): min=3, max=1005, avg=62.39, stdev=234.22
    clat percentiles (msec):
     |  1.00th=[    4],  5.00th=[    4], 10.00th=[    4], 20.00th=[    4],
     | 30.00th=[    4], 40.00th=[    4], 50.00th=[    4], 60.00th=[    4],
     | 70.00th=[    5], 80.00th=[    5], 90.00th=[    5], 95.00th=[  995],
     | 99.00th=[ 1003], 99.50th=[ 1003], 99.90th=[ 1003], 99.95th=[ 1003],
     | 99.99th=[ 1003]
   bw (  KiB/s): min=447616, max=536576, per=94.42%, avg=492096.00, stdev=62904.22, samples=2
   iops        : min=  437, max=  524, avg=480.50, stdev=61.52, samples=2
  lat (msec)   : 4=67.19%, 10=26.56%, 20=0.20%, 100=0.20%, 1000=2.93%
  lat (msec)   : 2000=2.93%
  cpu          : usr=0.50%, sys=3.68%, ctx=1002, majf=0, minf=8200
  IO depths    : 1=0.2%, 2=0.4%, 4=0.8%, 8=1.6%, 16=3.1%, 32=93.9%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.8%, 8=0.0%, 16=0.0%, 32=0.2%, 64=0.0%, >=64=0.0%
     issued rwts: total=512,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=509MiB/s (534MB/s), 509MiB/s-509MiB/s (534MB/s-534MB/s), io=512MiB (537MB), run=1006-1006msec

Disk stats (read/write):
  vda: ios=909/0, sectors=930816/0, merge=0/0, ticks=3050/0, in_queue=3050, util=89.47%
=== Running seq-write (write, bs=1M) ===
seq-write: (g=0): rw=write, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process

seq-write: (groupid=0, jobs=1): err= 0: pid=598: Sun Aug 22 20:20:22 2021
  write: IOPS=2306, BW=2306MiB/s (2418MB/s)(512MiB/222msec); 0 zone resets
    slat (usec): min=30, max=393, avg=65.43, stdev=27.86
    clat (usec): min=2134, max=25324, avg=13703.62, stdev=2811.04
     lat (usec): min=2217, max=25388, avg=13769.05, stdev=2811.44
    clat percentiles (usec):
     |  1.00th=[ 3621],  5.00th=[ 9765], 10.00th=[12649], 20.00th=[12911],
     | 30.00th=[13173], 40.00th=[13304], 50.00th=[13435], 60.00th=[13566],
     | 70.00th=[13829], 80.00th=[13960], 90.00th=[16909], 95.00th=[19268],
     | 99.00th=[23200], 99.50th=[24511], 99.90th=[25297], 99.95th=[25297],
     | 99.99th=[25297]
  lat (msec)   : 4=1.37%, 10=3.71%, 20=92.19%, 50=2.73%
  cpu          : usr=5.88%, sys=15.38%, ctx=485, majf=0, minf=8
  IO depths    : 1=0.2%, 2=0.4%, 4=0.8%, 8=1.6%, 16=3.1%, 32=93.9%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.8%, 8=0.0%, 16=0.0%, 32=0.2%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,512,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
  WRITE: bw=2306MiB/s (2418MB/s), 2306MiB/s-2306MiB/s (2418MB/s-2418MB/s), io=512MiB (537MB), run=222-222msec

Disk stats (read/write):
  vda: ios=0/264, sectors=0/540672, merge=0/0, ticks=0/3483, in_queue=3483, util=50.85%
=== Running rand-read (randread, bs=4k) ===
rand-read: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process
Jobs: 1 (f=1)
rand-read: (groupid=0, jobs=1): err= 0: pid=602: Sun Aug 22 20:20:25 2021
  read: IOPS=52.1k, BW=203MiB/s (213MB/s)(512MiB/2518msec)
    slat (usec): min=3, max=578, avg=15.68, stdev=19.36
    clat (usec): min=49, max=3177, avg=597.28, stdev=231.57
     lat (usec): min=53, max=3183, avg=612.96, stdev=236.93
    clat percentiles (usec):
     |  1.00th=[  178],  5.00th=[  255], 10.00th=[  293], 20.00th=[  347],
     | 30.00th=[  474], 40.00th=[  586], 50.00th=[  635], 60.00th=[  668],
     | 70.00th=[  709], 80.00th=[  742], 90.00th=[  799], 95.00th=[ 1037],
     | 99.00th=[ 1172], 99.50th=[ 1205], 99.90th=[ 2040], 99.95th=[ 2507],
     | 99.99th=[ 3064]
   bw (  KiB/s): min=152960, max=231136, per=99.94%, avg=208083.40, stdev=31360.25, samples=5
   iops        : min=38240, max=57784, avg=52020.60, stdev=7839.94, samples=5
  lat (usec)   : 50=0.01%, 100=0.01%, 250=4.50%, 500=27.13%, 750=51.85%
  lat (usec)   : 1000=10.55%
  lat (msec)   : 2=5.87%, 4=0.10%
  cpu          : usr=20.50%, sys=78.39%, ctx=963, majf=0, minf=42
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=100.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.1%, 64=0.0%, >=64=0.0%
     issued rwts: total=131072,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=203MiB/s (213MB/s), 203MiB/s-203MiB/s (213MB/s-213MB/s), io=512MiB (537MB), run=2518-2518msec

Disk stats (read/write):
  vda: ios=122839/0, sectors=982712/0, merge=0/0, ticks=4707/0, in_queue=4707, util=34.00%
=== Running rand-write (randwrite, bs=4k) ===
rand-write: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process
Jobs: 1 (f=1)
rand-write: (groupid=0, jobs=1): err= 0: pid=606: Sun Aug 22 20:20:28 2021
  write: IOPS=70.6k, BW=276MiB/s (289MB/s)(512MiB/1856msec); 0 zone resets
    slat (usec): min=3, max=667, avg=12.30, stdev=15.75
    clat (usec): min=48, max=3010, avg=439.89, stdev=97.14
     lat (usec): min=51, max=3020, avg=452.20, stdev=98.88
    clat percentiles (usec):
     |  1.00th=[  196],  5.00th=[  269], 10.00th=[  314], 20.00th=[  383],
     | 30.00th=[  429], 40.00th=[  445], 50.00th=[  461], 60.00th=[  474],
     | 70.00th=[  482], 80.00th=[  494], 90.00th=[  515], 95.00th=[  545],
     | 99.00th=[  619], 99.50th=[  652], 99.90th=[  824], 99.95th=[ 2114],
     | 99.99th=[ 2900]
   bw (  KiB/s): min=278920, max=285760, per=100.00%, avg=282818.67, stdev=3519.06, samples=3
   iops        : min=69730, max=71440, avg=70704.67, stdev=879.76, samples=3
  lat (usec)   : 50=0.01%, 100=0.01%, 250=3.58%, 500=81.11%, 750=15.17%
  lat (usec)   : 1000=0.05%
  lat (msec)   : 2=0.04%, 4=0.05%
  cpu          : usr=18.17%, sys=80.86%, ctx=698, majf=0, minf=8
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=100.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.1%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,131072,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
  WRITE: bw=276MiB/s (289MB/s), 276MiB/s-276MiB/s (289MB/s-289MB/s), io=512MiB (537MB), run=1856-1856msec

Disk stats (read/write):
  vda: ios=0/115820, sectors=0/926560, merge=0/0, ticks=0/4389, in_queue=4388, util=43.40%
fio benchmarks complete, rebooting
/init: line 52: reboot: command not found

## O_DIRECT

=== Running seq-read (read, bs=1M) ===
seq-read: (g=0): rw=read, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=32
fio-3.41
[    1.128335] clocksource: tsc: mask: 0xffffffffffffffff max_cycles: 0x7319ae2d98f, max_idle_ns: 881590998875 ns
[    1.128814] clocksource: Switched to clocksource tsc
Starting 1 process

seq-read: (groupid=0, jobs=1): err= 0: pid=594: Sun Aug 22 20:20:21 2021
  read: IOPS=927, BW=928MiB/s (973MB/s)(512MiB/552msec)
    slat (usec): min=51, max=729, avg=86.53, stdev=96.41
    clat (usec): min=1773, max=550203, avg=33888.61, stdev=127387.07
     lat (usec): min=1837, max=550552, avg=33975.15, stdev=127473.06
    clat percentiles (usec):
     |  1.00th=[  1811],  5.00th=[  1844], 10.00th=[  1860], 20.00th=[  1893],
     | 30.00th=[  1958], 40.00th=[  1991], 50.00th=[  2024], 60.00th=[  2073],
     | 70.00th=[  2147], 80.00th=[  2245], 90.00th=[  2507], 95.00th=[541066],
     | 99.00th=[549454], 99.50th=[549454], 99.90th=[549454], 99.95th=[549454],
     | 99.99th=[549454]
   bw (  KiB/s): min=929792, max=929792, per=97.89%, avg=929792.00, stdev= 0.00, samples=1
   iops        : min=  908, max=  908, avg=908.00, stdev= 0.00, samples=1
  lat (msec)   : 2=40.43%, 4=53.12%, 10=0.20%, 20=0.20%, 50=0.20%
  lat (msec)   : 750=5.86%
  cpu          : usr=0.36%, sys=6.53%, ctx=1011, majf=0, minf=8201
  IO depths    : 1=0.2%, 2=0.4%, 4=0.8%, 8=1.6%, 16=3.1%, 32=93.9%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.8%, 8=0.0%, 16=0.0%, 32=0.2%, 64=0.0%, >=64=0.0%
     issued rwts: total=512,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=928MiB/s (973MB/s), 928MiB/s-928MiB/s (973MB/s-973MB/s), io=512MiB (537MB), run=552-552msec

Disk stats (read/write):
  vda: ios=708/0, sectors=724992/0, merge=0/0, ticks=1238/0, in_queue=1238, util=79.00%
=== Running seq-write (write, bs=1M) ===
seq-write: (g=0): rw=write, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process

seq-write: (groupid=0, jobs=1): err= 0: pid=598: Sun Aug 22 20:20:22 2021
  write: IOPS=2925, BW=2926MiB/s (3068MB/s)(512MiB/175msec); 0 zone resets
    slat (usec): min=29, max=571, avg=107.53, stdev=56.56
    clat (usec): min=3799, max=20122, avg=10716.65, stdev=1772.39
     lat (usec): min=3890, max=20182, avg=10824.18, stdev=1766.23
    clat percentiles (usec):
     |  1.00th=[ 5800],  5.00th=[ 9110], 10.00th=[ 9372], 20.00th=[ 9503],
     | 30.00th=[10028], 40.00th=[10290], 50.00th=[10683], 60.00th=[10945],
     | 70.00th=[11076], 80.00th=[11207], 90.00th=[12256], 95.00th=[13042],
     | 99.00th=[18482], 99.50th=[19268], 99.90th=[20055], 99.95th=[20055],
     | 99.99th=[20055]
  lat (msec)   : 4=0.39%, 10=28.32%, 20=71.09%, 50=0.20%
  cpu          : usr=29.89%, sys=12.64%, ctx=438, majf=0, minf=8
  IO depths    : 1=0.2%, 2=0.4%, 4=0.8%, 8=1.6%, 16=3.1%, 32=93.9%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.8%, 8=0.0%, 16=0.0%, 32=0.2%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,512,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
  WRITE: bw=2926MiB/s (3068MB/s), 2926MiB/s-2926MiB/s (3068MB/s-3068MB/s), io=512MiB (537MB), run=175-175msec

Disk stats (read/write):
  vda: ios=0/332, sectors=0/679936, merge=0/0, ticks=0/3492, in_queue=3493, util=49.36%
=== Running rand-read (randread, bs=4k) ===
rand-read: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process
Jobs: 1 (f=1)
rand-read: (groupid=0, jobs=1): err= 0: pid=602: Sun Aug 22 20:20:24 2021
  read: IOPS=107k, BW=418MiB/s (439MB/s)(512MiB/1224msec)
    slat (usec): min=3, max=640, avg= 5.72, stdev=10.01
    clat (usec): min=97, max=12320, avg=292.55, stdev=216.75
     lat (usec): min=106, max=12328, avg=298.27, stdev=217.75
    clat percentiles (usec):
     |  1.00th=[  143],  5.00th=[  167], 10.00th=[  182], 20.00th=[  202],
     | 30.00th=[  221], 40.00th=[  239], 50.00th=[  262], 60.00th=[  289],
     | 70.00th=[  318], 80.00th=[  359], 90.00th=[  437], 95.00th=[  506],
     | 99.00th=[  652], 99.50th=[  717], 99.90th=[ 1139], 99.95th=[ 2180],
     | 99.99th=[12125]
   bw (  KiB/s): min=321232, max=500688, per=95.94%, avg=410960.00, stdev=126894.55, samples=2
   iops        : min=80308, max=125172, avg=102740.00, stdev=31723.64, samples=2
  lat (usec)   : 100=0.01%, 250=45.69%, 500=49.00%, 750=4.96%, 1000=0.22%
  lat (msec)   : 2=0.07%, 4=0.04%, 20=0.02%
  cpu          : usr=13.00%, sys=66.39%, ctx=5546, majf=0, minf=39
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=100.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.1%, 64=0.0%, >=64=0.0%
     issued rwts: total=131072,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=418MiB/s (439MB/s), 418MiB/s-418MiB/s (439MB/s-439MB/s), io=512MiB (537MB), run=1224-1224msec

Disk stats (read/write):
  vda: ios=120043/0, sectors=960344/0, merge=0/0, ticks=24359/0, in_queue=24358, util=88.67%
=== Running rand-write (randwrite, bs=4k) ===
rand-write: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process
Jobs: 1 (f=1)
rand-write: (groupid=0, jobs=1): err= 0: pid=606: Sun Aug 22 20:20:25 2021
  write: IOPS=106k, BW=413MiB/s (433MB/s)(512MiB/1239msec); 0 zone resets
    slat (usec): min=3, max=669, avg= 7.37, stdev=14.95
    clat (usec): min=59, max=12060, avg=294.50, stdev=192.16
     lat (usec): min=63, max=12141, avg=301.87, stdev=192.48
    clat percentiles (usec):
     |  1.00th=[  178],  5.00th=[  204], 10.00th=[  219], 20.00th=[  255],
     | 30.00th=[  269], 40.00th=[  281], 50.00th=[  289], 60.00th=[  297],
     | 70.00th=[  310], 80.00th=[  326], 90.00th=[  359], 95.00th=[  383],
     | 99.00th=[  449], 99.50th=[  494], 99.90th=[  930], 99.95th=[ 2311],
     | 99.99th=[11731]
   bw (  KiB/s): min=416104, max=429640, per=99.93%, avg=422872.00, stdev=9571.40, samples=2
   iops        : min=104026, max=107410, avg=105718.00, stdev=2392.85, samples=2
  lat (usec)   : 100=0.01%, 250=19.00%, 500=80.53%, 750=0.30%, 1000=0.09%
  lat (msec)   : 2=0.03%, 4=0.04%, 20=0.02%
  cpu          : usr=14.38%, sys=79.64%, ctx=989, majf=0, minf=9
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=100.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.1%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,131072,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
  WRITE: bw=413MiB/s (433MB/s), 413MiB/s-413MiB/s (433MB/s-433MB/s), io=512MiB (537MB), run=1239-1239msec


## O_DIRECT release mode build

=== Running seq-read (read, bs=1M) ===
seq-read: (g=0): rw=read, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process
[    1.084274] clocksource: tsc: mask: 0xffffffffffffffff max_cycles: 0x731ace0cde1, max_idle_ns: 881591168796 ns
[    1.084582] clocksource: Switched to clocksource tsc

seq-read: (groupid=0, jobs=1): err= 0: pid=594: Sun Aug 22 20:20:21 2021
  read: IOPS=658, BW=659MiB/s (691MB/s)(512MiB/777msec)
    slat (usec): min=34, max=436, avg=74.94, stdev=82.80
    clat (msec): min=2, max=775, avg=48.03, stdev=180.43
     lat (msec): min=2, max=775, avg=48.11, stdev=180.50
    clat percentiles (msec):
     |  1.00th=[    3],  5.00th=[    3], 10.00th=[    3], 20.00th=[    3],
     | 30.00th=[    3], 40.00th=[    3], 50.00th=[    3], 60.00th=[    3],
     | 70.00th=[    4], 80.00th=[    4], 90.00th=[    4], 95.00th=[  768],
     | 99.00th=[  776], 99.50th=[  776], 99.90th=[  776], 99.95th=[  776],
     | 99.99th=[  776]
   bw (  KiB/s): min=652007, max=652007, per=96.63%, avg=652007.00, stdev= 0.00, samples=1
   iops        : min=  636, max=  636, avg=636.00, stdev= 0.00, samples=1
  lat (msec)   : 4=90.82%, 10=2.93%, 20=0.20%, 50=0.20%, 1000=5.86%
  cpu          : usr=0.00%, sys=4.25%, ctx=1007, majf=0, minf=8200
  IO depths    : 1=0.2%, 2=0.4%, 4=0.8%, 8=1.6%, 16=3.1%, 32=93.9%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.8%, 8=0.0%, 16=0.0%, 32=0.2%, 64=0.0%, >=64=0.0%
     issued rwts: total=512,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=659MiB/s (691MB/s), 659MiB/s-659MiB/s (691MB/s-691MB/s), io=512MiB (537MB), run=777-777msec

Disk stats (read/write):
  vda: ios=832/0, sectors=851968/0, merge=0/0, ticks=2139/0, in_queue=2139, util=86.30%
=== Running seq-write (write, bs=1M) ===
seq-write: (g=0): rw=write, bs=(R) 1024KiB-1024KiB, (W) 1024KiB-1024KiB, (T) 1024KiB-1024KiB, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process

seq-write: (groupid=0, jobs=1): err= 0: pid=598: Sun Aug 22 20:20:22 2021
  write: IOPS=3180, BW=3180MiB/s (3335MB/s)(512MiB/161msec); 0 zone resets
    slat (usec): min=19, max=1294, avg=145.18, stdev=105.59
    clat (usec): min=6241, max=17625, avg=9729.81, stdev=1352.10
     lat (usec): min=6312, max=17967, avg=9874.99, stdev=1356.54
    clat percentiles (usec):
     |  1.00th=[ 7373],  5.00th=[ 7963], 10.00th=[ 8717], 20.00th=[ 9110],
     | 30.00th=[ 9241], 40.00th=[ 9372], 50.00th=[ 9372], 60.00th=[ 9503],
     | 70.00th=[ 9765], 80.00th=[10290], 90.00th=[10814], 95.00th=[11207],
     | 99.00th=[15926], 99.50th=[16909], 99.90th=[17695], 99.95th=[17695],
     | 99.99th=[17695]
  lat (msec)   : 10=73.24%, 20=26.76%
  cpu          : usr=44.38%, sys=10.62%, ctx=340, majf=0, minf=7
  IO depths    : 1=0.2%, 2=0.4%, 4=0.8%, 8=1.6%, 16=3.1%, 32=93.9%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=99.8%, 8=0.0%, 16=0.0%, 32=0.2%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,512,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
  WRITE: bw=3180MiB/s (3335MB/s), 3180MiB/s-3180MiB/s (3335MB/s-3335MB/s), io=512MiB (537MB), run=161-161msec

Disk stats (read/write):
  vda: ios=0/397, sectors=0/813056, merge=0/0, ticks=0/3683, in_queue=3683, util=52.10%
=== Running rand-read (randread, bs=4k) ===
rand-read: (g=0): rw=randread, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process
Jobs: 1 (f=1)
rand-read: (groupid=0, jobs=1): err= 0: pid=602: Sun Aug 22 20:20:24 2021
  read: IOPS=116k, BW=453MiB/s (475MB/s)(512MiB/1131msec)
    slat (usec): min=3, max=937, avg= 5.94, stdev=11.19
    clat (usec): min=92, max=2798, avg=269.57, stdev=93.45
     lat (usec): min=96, max=2812, avg=275.50, stdev=94.72
    clat percentiles (usec):
     |  1.00th=[  133],  5.00th=[  161], 10.00th=[  178], 20.00th=[  200],
     | 30.00th=[  219], 40.00th=[  237], 50.00th=[  255], 60.00th=[  273],
     | 70.00th=[  302], 80.00th=[  330], 90.00th=[  392], 95.00th=[  424],
     | 99.00th=[  498], 99.50th=[  529], 99.90th=[  668], 99.95th=[ 1369],
     | 99.99th=[ 2606]
   bw (  KiB/s): min=397029, max=515184, per=98.39%, avg=456106.50, stdev=83548.20, samples=2
   iops        : min=99257, max=128796, avg=114026.50, stdev=20887.23, samples=2
  lat (usec)   : 100=0.01%, 250=47.64%, 500=51.41%, 750=0.84%, 1000=0.02%
  lat (msec)   : 2=0.04%, 4=0.03%
  cpu          : usr=14.34%, sys=74.51%, ctx=3584, majf=0, minf=41
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=100.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.1%, 64=0.0%, >=64=0.0%
     issued rwts: total=131072,0,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
   READ: bw=453MiB/s (475MB/s), 453MiB/s-453MiB/s (475MB/s-475MB/s), io=512MiB (537MB), run=1131-1131msec

Disk stats (read/write):
  vda: ios=99615/0, sectors=796920/0, merge=0/0, ticks=16259/0, in_queue=16259, util=85.51%
=== Running rand-write (randwrite, bs=4k) ===
rand-write: (g=0): rw=randwrite, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=32
fio-3.41
Starting 1 process
Jobs: 1 (f=1)
rand-write: (groupid=0, jobs=1): err= 0: pid=606: Sun Aug 22 20:20:25 2021
  write: IOPS=101k, BW=395MiB/s (414MB/s)(512MiB/1297msec); 0 zone resets
    slat (usec): min=3, max=730, avg= 8.05, stdev=14.56
    clat (usec): min=70, max=2711, avg=307.97, stdev=76.76
     lat (usec): min=74, max=2727, avg=316.02, stdev=77.71
    clat percentiles (usec):
     |  1.00th=[  167],  5.00th=[  202], 10.00th=[  225], 20.00th=[  262],
     | 30.00th=[  273], 40.00th=[  289], 50.00th=[  310], 60.00th=[  326],
     | 70.00th=[  338], 80.00th=[  351], 90.00th=[  375], 95.00th=[  408],
     | 99.00th=[  474], 99.50th=[  502], 99.90th=[  816], 99.95th=[ 1450],
     | 99.99th=[ 2638]
   bw (  KiB/s): min=401145, max=408920, per=100.00%, avg=405032.50, stdev=5497.76, samples=2
   iops        : min=100286, max=102230, avg=101258.00, stdev=1374.62, samples=2
  lat (usec)   : 100=0.01%, 250=15.13%, 500=84.33%, 750=0.41%, 1000=0.05%
  lat (msec)   : 2=0.04%, 4=0.03%
  cpu          : usr=16.67%, sys=80.63%, ctx=834, majf=0, minf=8
  IO depths    : 1=0.1%, 2=0.1%, 4=0.1%, 8=0.1%, 16=0.1%, 32=100.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.1%, 64=0.0%, >=64=0.0%
     issued rwts: total=0,131072,0,0 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=32

Run status group 0 (all jobs):
  WRITE: bw=395MiB/s (414MB/s), 395MiB/s-395MiB/s (414MB/s-414MB/s), io=512MiB (537MB), run=1297-1297msec

## Cloud Hypervisor (1 vCPU / 1 virtio-blk queue)

```
<<<cloud-hv-fio.log>>>
cloud-hypervisor: 352.685567ms: <vcpu0> WARN:virtio-devices/src/transport/pci_common_config.rs:342 -- invalid ack_features (page 2, value 0x0)
cloud-hypervisor: 352.739678ms: <vcpu0> WARN:virtio-devices/src/transport/pci_common_config.rs:342 -- invalid ack_features (page 3, value 0x0)
[    0.103773] Non-volatile memory driver v1.3
cloud-hypervisor: 362.319901ms: <vcpu0> WARN:virtio-devices/src/transport/pci_common_config.rs:342 -- invalid ack_features (page 2, value 0x0)
cloud-hypervisor: 362.408878ms: <vcpu0> WARN:virtio-devices/src/transport/pci_common_config.rs:342 -- invalid ack_features (page 3, value 0x0)
[    0.113619] Hangcheck: starting hangcheck timer 0.9.1 (tick is 180 seconds, margin is 60 seconds).
[    0.115943] brd: module loaded
[    0.117722] loop: module loaded
cloud-hypervisor: 376.302602ms: <vcpu0> WARN:virtio-devices/src/transport/pci_common_config.rs:342 -- invalid ack_features (page 2, value 0x0)
cloud-hypervisor: 376.348468ms: <vcpu0> WARN:virtio-devices/src/transport/pci_common_config.rs:342 -- invalid ack_features (page 3, value 0x0)
[    0.118125] virtio_blk virtio1: 1/0/0 default/read/poll queues
[    0.119566] virtio_blk virtio1: [vda] 2097152 512-byte logical blocks (1.07 GB/1.00 GiB)
[    0.121943] zram: Added device: zram0
[    0.122351] null_blk: disk nullb0 created
[    0.122457] null_blk: module loaded
...
rand-write: (groupid=0, jobs=1): err= 0: pid=619: Sat Nov 22 23:30:50 2025
  write: IOPS=301k, BW=1174MiB/s (1231MB/s)(512MiB/436msec); 0 zone resets
    slat (nsec): min=1492, max=121408, avg=2103.09, stdev=1876.05
    clat (usec): min=21, max=546, avg=103.94, stdev=21.86
     lat (usec): min=22, max=548, avg=106.05, stdev=22.08
...
fio benchmarks complete, powering off
/init: line 52: poweroff: command not found
/init: line 52: reboot: command not found
[    3.340532] sysrq: Power Off
```
