SHELL = bash

# Get number of CPU cores and RAM is different on MacOS

TARGETOS := $(shell uname -s)

ifeq ($(TARGETOS), Darwin)
	cpu_cores   = `sysctl -n hw.ncpu`    #number of cores
	ram_o       = `sysctl -n hw.memsize` #ram size
else
	cpu_cores=`nproc`
	ram_ko=`cat /proc/meminfo | grep "MemTotal:" | grep -o '[0-9]*'`
	ram_o=$(shell expr $(ram_ko) \* 1000)
endif

file_min_go=$(shell expr $(ram_o) / 1000000000 ) #ram size in Go
file_go=$(shell expr $(file_min_go) + 2 )#we add a little more to prevent caching in ram

all:
	@echo "Run make install-macOS, or make install-debian to install, and then, run make benchmarks"

install-macOS:
	# Install only if automake and pkg-config are not installed
	brew list automake &>/dev/null || brew install automake
	brew list pkg-config &>/dev/null || brew install pkg-config
	make install

install-debian:
	apt -y install make automake libtool pkg-config libaio-dev vim-common
	make install

install:
	git clone https://github.com/akopytov/sysbench.git
	cd sysbench && git checkout 1.0.8
	cd sysbench && ./autogen.sh
	cd sysbench && ./configure --without-mysql
	cd sysbench && make
	cp sysbench/src/sysbench bin_sysbench
	wget -O speedtest-cli https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py
	chmod +x speedtest-cli


benchmarks:
	@echo "systemBenchmark - Starting benchmarks"
	@make -s cpu
	@make -s ram
	@make -s fileIO
	@make -s network

cpu:
	@echo -n ' > CPU  (1 core) score: '
	@./bin_sysbench cpu --cpu-max-prime=20000 run | grep "events per second:" | grep -o '[0-9]*\.[0-9]*' | tr -d '\n'
	@echo " events/second"
	@echo -n ' > CPU ('
	@echo -n $(cpu_cores)
	@echo -n ' cores) score: '
	@./bin_sysbench cpu --cpu-max-prime=20000 --threads=$(cpu_cores) run | grep "events per second:" | grep -o '[0-9]*\.[0-9]*' | tr -d '\n'
	@echo " events/second"

ram:
	@echo -n ' > RAM speed: '
	@./bin_sysbench memory --memory-block-size=1M --memory-total-size=10G run | grep -o '[0-9]*\.[0-9]* MiB/sec'

fileIO:
	@./bin_sysbench fileio --file-total-size=$(file_go)G prepare > /dev/null
	@./bin_sysbench fileio --file-total-size=$(file_go)G --file-test-mode=rndrw --time=1 --max-requests=0 run | egrep 'read, MiB/s:| written, MiB/s:' | grep -o '[0-9]*\.[0-9]*' | sed 's/$$/\ MiB\/second/' | sed -e '2s/^/ > HDD Write: /' | sed -e '1s/^/ >  HDD Read: /'
	@./bin_sysbench fileio --file-total-size=$(file_go)G cleanup > /dev/null



network:
	@./speedtest-cli --server 1688 | egrep -o "[0-9]*\.[0-9]* ms|[0-9]*\.[0-9]* Mbit/s" | sed -e '3s/^/ >   Upload: /' | sed -e '2s/^/ > Download: /' | sed -e '1s/^/ >     Ping: /'



