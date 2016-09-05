.PHONY: test lint rel clean

NUMBER=s3356850

# Run the script over the test data.
test:
	@cat test/password | ./audit.sh

lint:
	@shellcheck -s bash audit.sh

rel:
	@cp audit.sh $(NUMBER)
	@chmod +x $(NUMBER)
	@zip $(NUMBER).zip $(NUMBER)
	@rm $(NUMBER)

clean:
	@rm -f $(NUMBER).zip
