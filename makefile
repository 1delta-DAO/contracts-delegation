.PHONY: test-all test test-cancun

match-path ?= test*

test-all: test test-cancun

test:
	@echo "Running tests with Shanghai EVM..."
	@forge test --no-match-test cancun --evm-version shanghai --match-path="$(match-path)"

test-cancun:
	@echo "Running tests with Cancun EVM..."
	@forge test --match-test cancun --evm-version cancun --match-path="$(match-path)"