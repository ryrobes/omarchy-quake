PREFIX ?= $(HOME)/.local
DESTDIR ?=

.PHONY: engine plugin-validate test install

engine:
	bash scripts/build-engine.sh

plugin-validate:
	omarchy plugin validate plugin

test:
	bash tests/test-classify.sh
	bash tests/test-install-layout.sh
	python3 lib/beacon.py ping 127.0.0.1 >/dev/null || true

install: engine
	PREFIX="$(PREFIX)" DESTDIR="$(DESTDIR)" SKIP_BUILD=1 bash scripts/install.sh
