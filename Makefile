.PHONY: test lint

# Run the script over the test data.
test:
	@cat test/password | ./audit

lint:
	@shellcheck audit
