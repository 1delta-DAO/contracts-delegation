.PHONY: test-all test  test-cancun

test-all: test test-cancun

test:
	@echo "Running tests with Shanghai EVM..."
	@forge test --no-match-test cancun --evm-version shanghai

test-cancun:
	@echo "Running tests with Cancun EVM..."
	@forge test --match-test cancun --evm-version cancun