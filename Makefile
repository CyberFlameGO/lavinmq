BINS := bin/lavinmq bin/lavinmqctl bin/lavinmqperf bin/lavinmq-debug
SOURCES := $(shell find src/lavinmq src/stdlib -name '*.cr' 2> /dev/null)
JS := static/js/lib/chart.js static/js/lib/amqp-websocket-client.mjs static/js/lib/amqp-websocket-client.mjs.map
DOCS := static/docs/index.html
override CRYSTAL_FLAGS += --error-on-warnings --cross-compile $(if $(target),--target $(target))

.PHONY: all
all: $(BINS)

.PHONY: objects
objects: $(BINS:=.o)

bin/%-debug.o bin/%-debug.sh: src/%.cr $(SOURCES) lib $(JS) $(DOCS) | bin
	crystal build $< -o $(basename $@) --debug -Dbake_static $(CRYSTAL_FLAGS) > $(basename $@).sh

bin/%.o bin/%.sh: src/%.cr $(SOURCES) lib $(JS) $(DOCS) | bin
	crystal build $< -o $(basename $@) --release --no-debug $(CRYSTAL_FLAGS) > $(basename $@).sh

bin/%: bin/%.sh bin/%.o
	$(file < $<)

lib: shard.yml shard.lock
	shards install --production

bin static/js/lib:
	mkdir -p $@

static/js/lib/%: | static/js/lib
	curl --retry 5 -sLo $@ https://github.com/cloudamqp/amqp-client.js/releases/download/v2.1.0/$(@F)

static/js/lib/chart.js: | static/js/lib
	curl --retry 5 -sL https://github.com/chartjs/Chart.js/releases/download/v3.9.1/chart.js-3.9.1.tgz | \
		tar -C /tmp -zxf- package/dist/chart.mjs package/dist/chunks/helpers.segment.mjs
	npx rollup --file $@ /tmp/package/dist/chart.mjs
	curl -sL https://cdn.jsdelivr.net/npm/chartjs-adapter-luxon@1.2.0/dist/chartjs-adapter-luxon.esm.js > \
		static/js/lib/chartjs-adapter-luxon.esm.js 
	curl -sL https://moment.github.io/luxon/es6/luxon.js > static/js/lib/luxon.js 

static/docs/index.html: openapi/openapi.yaml $(wildcard openapi/paths/*.yaml) $(wildcard openapi/schemas/*.yaml)
	npx redoc-cli build $< -o $@

.PHONY: docs
docs: $(DOCS)

.PHONY: js
js: $(JS)

.PHONY: deps
deps: js lib docs

.PHONY: lint
lint: lib
	lib/ameba/bin/ameba src/

.PHONY: install
install: $(BINS)
	install -s $^ /usr/local/bin/

.PHONY: clean
clean:
	rm -rf bin
	rm -f static/docs/index.html
	rm -f static/js/lib/*
