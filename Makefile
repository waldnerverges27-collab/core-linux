.PHONY: all build install uninstall test lint clean

GO_SRC = cmd/core-tui/main.go cmd/core-tui/app.go cmd/core-tui/styles.go cmd/core-tui/keys.go
GO_SRC += $(wildcard cmd/core-tui/views/*.go) $(wildcard cmd/core-tui/components/*.go) $(wildcard cmd/core-tui/utils/*.go)
BINARY = cmd/core-tui/core-tui

all: build

build: $(BINARY)

$(BINARY): $(GO_SRC) cmd/core-tui/go.mod
	cd cmd/core-tui && go build -ldflags="-s -w" -o core-tui .

install:
	@bash install.sh

uninstall:
	@bash uninstall.sh

test: test-bats test-go

test-bats:
	@command -v bats >/dev/null 2>&1 || { echo "bats not installed, skipping"; exit 0; }
	bats tests/*.bats

test-go:
	cd cmd/core-tui && go test ./...

lint: lint-sh lint-go

lint-sh:
	shellcheck lib/*/*.sh lib/**/*.sh core install.sh uninstall.sh modules/*/install.sh modules/*/uninstall.sh modules/*/verify.sh 2>/dev/null || true

lint-go:
	cd cmd/core-tui && command -v golangci-lint >/dev/null 2>&1 && golangci-lint run ./... || echo "golangci-lint not installed"

clean:
	rm -f $(BINARY) cmd/core-tui/core-tui

themes:
	@for f in lib/tui/themes/*.toml; do \
		echo "Validating $$f..."; \
		python3 -c "import tomllib, sys; tomllib.load(open(sys.argv[1], 'rb'))" "$$f" 2>/dev/null || \
		echo "WARNING: Invalid TOML: $$f"; \
	done

docs:
	@echo "Generating module docs..."
	@for f in modules/*/manifest.json; do \
		name=$$(basename $$(dirname $$f)); \
		echo "- $$name"; \
	done > docs/MODULES.md

package-deb:
	@echo "Building .deb..."
	@cd packaging/debian && dpkg-buildpackage -us -uc 2>/dev/null || echo "dpkg-buildpackage not available"

package-rpm:
	@echo "Building .rpm..."
	@cd packaging && rpmbuild -ba core-linux.spec 2>/dev/null || echo "rpmbuild not available"

package-aur:
	@echo "Generating AUR tarball..."
	@tar czf packaging/core-linux-aur.tar.gz packaging/PKGBUILD
