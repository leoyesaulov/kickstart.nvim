# Tests for this config. See README's "Testing" section.
#   make test     lint + smoke + keymaps
#   make deps     install plugins at lazy-lock.json's commits into the .tests/ sandbox
#   make clean    remove the sandbox
NVIM ?= nvim
SANDBOX = tests/env.sh
# Set STRICT=1 (CI does) to fail instead of skipping when a linter/shell is missing.
STRICT ?=

.PHONY: test lint smoke keymaps deps clean

test: lint smoke keymaps

deps: .tests/data/nvim/lazy/.restored

.tests/data/nvim/lazy/.restored: lazy-lock.json
	$(SANDBOX) $(NVIM) --headless "+Lazy! restore" +qa
	$(SANDBOX) $(NVIM) --headless --cmd 'luafile tests/deps.lua'
	touch $@

smoke: deps
	$(SANDBOX) $(NVIM) --headless --cmd 'luafile tests/smoke.lua'

keymaps: deps
	$(SANDBOX) $(NVIM) --headless -V1 --cmd 'luafile tests/keymaps.lua'

lint:
	@STRICT=$(STRICT) tests/lint.sh

clean:
	rm -rf .tests
