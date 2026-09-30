# meeting-tui — build helpers.
#
#   make          build release and drop the binary in bin/ (what SUPER+SHIFT+M runs)
#   make build    debug build in target/debug
#   make run      run the debug build against the live voxtype state
#   make check    type-check only, no binary
#   make fmt      rustfmt
#   make clean    remove target/ and bin/meeting-tui
#
# The toolchain is whatever `cargo` is on PATH (rustup stable, or the 'rust' package).

CARGO ?= cargo
NAME  := meeting-tui
BIN   := bin/$(NAME)

.PHONY: all release build run check fmt clean

all: release

release:
	$(CARGO) build --release
	@mkdir -p bin
	cp target/release/$(NAME) $(BIN)
	@echo "-> $(BIN) ready"

build:
	$(CARGO) build

run:
	$(CARGO) run

check:
	$(CARGO) check

fmt:
	$(CARGO) fmt

clean:
	$(CARGO) clean
	rm -f $(BIN)
