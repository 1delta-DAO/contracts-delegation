.PHONY: test-all test test-cancun

match-path ?= test*
V ?= 0

ifeq ($(V),1)
	VERBOSITY = -v
else ifeq ($(V),2)
	VERBOSITY = -vv
else ifeq ($(V),3)
	VERBOSITY = -vvv
else ifeq ($(V),4)
	VERBOSITY = -vvvv
else ifeq ($(V),5)
	VERBOSITY = -vvvvv
else
	VERBOSITY =
endif

test-all: test test-cancun

test:
	@echo "Running tests with Shanghai EVM..."
	@forge test --no-match-test cancun --evm-version shanghai --match-path="$(match-path)" $(VERBOSITY)

test-cancun:
	@echo "Running tests with Cancun EVM..."
	@forge test --match-test cancun --evm-version cancun --match-path="$(match-path)" $(VERBOSITY)