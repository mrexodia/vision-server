.PHONY: build start stop test clean

all: build

HOST ?= 127.0.0.1
PORT ?= 8080

build:
	@swift build -c release >&2

start: build stop
	@./.build/release/vision-server --host $(HOST) --port $(PORT) > server.log 2> server.err.log & echo $$! > .server.pid
	@if [ "$(HOST)" = "0.0.0.0" ]; then \
		echo "http://127.0.0.1:$(PORT)" > .server.url; \
	else \
		echo "http://$(HOST):$(PORT)" > .server.url; \
	fi
	@echo "Server started (PID: $$(cat .server.pid)) at $$(cat .server.url)" >&2

stop:
	@if [ -f .server.pid ]; then \
		kill $$(cat .server.pid) 2>/dev/null || true; \
		rm -f .server.pid .server.url; \
		echo "Server stopped" >&2; \
	fi

test: start
	@if [ -z "$(IMAGE)" ]; then \
		echo "Usage: make test IMAGE=path/to/image.jpg [HOST=127.0.0.1] [PORT=8080]" >&2; \
		exit 1; \
	fi
	@sleep 2
	@echo "Testing with $(IMAGE)..." >&2
	@curl -s -X POST -H "Content-Type: application/octet-stream" --data-binary @$(IMAGE) $$(cat .server.url)/analyze
	@$(MAKE) -s stop

clean:
	swift package clean
	rm -rf .build .server.pid .server.url *.log
