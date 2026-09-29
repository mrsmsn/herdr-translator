# herdr-translator tasks.
# Lint and tests run inside a podman container so nothing is installed on the
# host. The repo is mounted at /work (writes happen in the container's own
# tmpfs sandbox under $TMPDIR).

image := "herdr-translator-ci"
run := "podman run --rm -v " + justfile_directory() + ":/work:Z " + image

default: check

# Build the CI container image.
build:
    podman build -t {{image}} -f Containerfile .

# Run shellcheck + bats inside the container.
check: build
    {{run}} bash ci/run-checks.sh

# Static analysis only.
lint: build
    {{run}} shellcheck translate.sh render.sh helpers.sh view.sh engines/*.sh tests/stubs/herdr tests/stubs/trans tests/stubs/curl tests/stubs/pbpaste tests/stubs/less ci/run-checks.sh

# Tests only.
test: build
    {{run}} bats tests

# Open a shell in the toolchain container for debugging.
shell: build
    podman run --rm -it -v {{justfile_directory()}}:/work:Z {{image}} bash
