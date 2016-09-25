CONFIG ?= debug

build:
	swift build -v -c $(CONFIG)

clean:
	rm -rf .build

.PHONY: build clean
