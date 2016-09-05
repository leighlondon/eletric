.PHONY: test lint

NUMBER=s3356850

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
