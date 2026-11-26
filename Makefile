# One entry point at the repo root. JS tasks run in the yarn workspace root, the repo root.
# Native tasks run here.

YARN_ROOT := .
YARN := cd $(YARN_ROOT) && yarn

CORE_TESTS := packages/shadowlist-utils-core-tests

.PHONY: install lint lint-fix typecheck typecheck-web test test-wasm build build-wasm format format-check docs-check check test-core test-core-tsan pods-macos

# JS pass-through targets

install:
	$(YARN) install

lint:
	$(YARN) lint

lint-fix:
	$(YARN) lint:fix

typecheck:
	$(YARN) typecheck

typecheck-web:
	$(YARN) typecheck:web

test:
	$(YARN) test

test-wasm:
	$(YARN) test:wasm

build:
	$(YARN) build

build-wasm:
	$(YARN) build:wasm

format:
	$(YARN) format

format-check:
	$(YARN) format:check

docs-check:
	$(YARN) docs:check

check: lint format-check typecheck docs-check test

# Native targets

test-core:
	cmake -S $(CORE_TESTS) -B $(CORE_TESTS)/build
	cmake --build $(CORE_TESTS)/build
	ctest --test-dir $(CORE_TESTS)/build --output-on-failure

test-core-tsan:
	cmake -S $(CORE_TESTS) -B $(CORE_TESTS)/build-tsan -DCMAKE_CXX_FLAGS=-fsanitize=thread -DCMAKE_EXE_LINKER_FLAGS=-fsanitize=thread
	cmake --build $(CORE_TESTS)/build-tsan
	$(CORE_TESTS)/build-tsan/shadowlist_utils_core_tests

pods-macos:
	cd examples/shadowlist-macos-example/macos && pod install
