PREFIX ?= $(HOME)/.local

.PHONY: engine plugin-validate test install

engine:
	bash scripts/build-engine.sh

plugin-validate:
	omarchy plugin validate plugin

test:
	bash tests/test-classify.sh
	python3 lib/beacon.py ping 127.0.0.1 >/dev/null || true

install: engine
	bash scripts/install.sh
