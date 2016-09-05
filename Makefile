.PHONY: test lint

# Run the script over the test data.
test:
	@cat test/password | ./audit.sh

lint:
	@shellcheck -s bash audit.sh

release:
	@cp audit.sh $(NUMBER)
	@chmod +x $(NUMBER)
	@zip $(NUMBER).zip $(NUMBER)
	@rm $(NUMBER)
