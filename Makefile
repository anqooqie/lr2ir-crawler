SHELL := /bin/bash

vendor/bundle: Gemfile.lock
	bundle install --path $@

Gemfile.lock: Gemfile
	bundle lock

.PHONY: clean
clean:
	rm -rf $(shell LANG=C git clean -X -d -n | sed 's/^Would remove //g')

.PHONY: force
force:
	$(MAKE) clean
	$(MAKE)
