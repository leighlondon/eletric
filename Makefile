.PHONY: test lint

# Run the script over the test data.
test:
	@cat test/password | ./audit.sh

lint:
	@shellcheck -s bash audit.sh
