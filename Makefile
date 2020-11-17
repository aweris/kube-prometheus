SHELL=/bin/bash -o pipefail

BIN_DIR?=$(shell pwd)/tmp/bin
TEST_DIR?=$(shell pwd)/tmp/manifests

EMBEDMD_BIN=$(BIN_DIR)/embedmd
JB_BIN=$(BIN_DIR)/jb
GOJSONTOYAML_BIN=$(BIN_DIR)/gojsontoyaml
JSONNET_BIN=$(BIN_DIR)/jsonnet
JSONNETFMT_BIN=$(BIN_DIR)/jsonnetfmt
KUBECONFORM_BIN=$(BIN_DIR)/kubeconform
TOOLING=$(EMBEDMD_BIN) $(JB_BIN) $(GOJSONTOYAML_BIN) $(JSONNET_BIN) $(JSONNETFMT_BIN) $(KUBECONFORM_BIN)

JSONNETFMT_ARGS=-n 2 --max-blank-lines 2 --string-style s --comment-style s

all: generate fmt test

.PHONY: clean
clean:
	# Remove all files and directories ignored by git.
	git clean -Xfd .

.PHONY: generate
generate: manifests **.md

**.md: $(EMBEDMD_BIN) $(shell find examples) build.sh example.jsonnet
	$(EMBEDMD_BIN) -w `find . -name "*.md" | grep -v vendor`

manifests: examples/kustomize.jsonnet $(GOJSONTOYAML_BIN) vendor build.sh
	./build.sh $<

.PHONY: validate
validate: manifests $(KUBECONFORM_BIN)
	$(KUBECONFORM_BIN) -schema-location 'https://kubernetesjsonschema.dev' -schema-location 'jsonschemas/{{ .ResourceKind }}_{{ .ResourceAPIVersion }}.json' examples/example-app/*.yaml

vendor: $(JB_BIN) jsonnetfile.json jsonnetfile.lock.json
	rm -rf vendor
	$(JB_BIN) install

.PHONY: fmt
fmt: $(JSONNETFMT_BIN)
	find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETFMT_BIN) $(JSONNETFMT_ARGS) -i

.PHONY: test
test: $(JB_BIN) $(KUBECONFORM_BIN) $(TEST_DIR)
	$(JB_BIN) install
	./test.sh

.PHONY: test-e2e
test-e2e:
	go test -timeout 55m -v ./tests/e2e -count=1

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TEST_DIR):
	mkdir -p $(TEST_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from scripts/tools.go
	@cd scripts && cat tools.go | grep _ | awk -F'"' '{print $$2}' | xargs -tI % go build -modfile=go.mod -o $(BIN_DIR) %
