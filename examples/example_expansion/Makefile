
ifeq ($(OS),Windows_NT)
		TARGET = example_expansion.dll
else
		UNAME_S := $(shell uname -s)
		ifeq ($(UNAME_S),Linux)
			TARGET = example_expansion.so
		endif
    ifeq ($(UNAME_S),Darwin)
			TARGET = example_expansion.dylib
    endif
endif

$(TARGET): example_expansion.c
	$(CC) $(CFLAGS) -shared -fPIC -o $@ $^


