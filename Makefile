BIN = imgur

all: $(BIN)

$(BIN): main.m
	clang -v $< -fobjc-arc -mmacosx-version-min=10.6 -framework AppKit -o $@

format: *.m
	clang-format -i $?

clean:
	rm -f $(BIN)

.PHONY: all format clean
