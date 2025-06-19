# If this is not set, the build will fail
ERL_EI_INCLUDE_DIR ?= $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/usr/include"])])' -s init stop -noshell)
ERL_EI_LIBDIR ?= $(shell erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/usr/lib"])])' -s init stop -noshell)

# If this is not set, the build will fail
ERLANG_PATH ?= $(shell erl -eval 'io:format("~s", [code:root_dir()])' -s init stop -noshell)

# Look for the EI library and header files
# For crosscompiled builds, ERL_EI_INCLUDE_DIR and ERL_EI_LIBDIR must be
# passed into the Makefile.
ifeq ($(ERL_EI_INCLUDE_DIR),)
$(error ERL_EI_INCLUDE_DIR not set. Invoke via mix)
endif

ifeq ($(ERL_EI_LIBDIR),)
$(error ERL_EI_LIBDIR not set. Invoke via mix)
endif

# Set Erlang-specific compile and linker flags
ERL_CFLAGS ?= -I$(ERL_EI_INCLUDE_DIR)
ERL_LDFLAGS ?= -L$(ERL_EI_LIBDIR) -lei

# Set C-specific compile and linker flags
CFLAGS ?= -O2 -Wall -Wextra -Wno-unused-parameter -std=c99 -Itermbox2
LDFLAGS ?= -shared

# Set platform-specific compile and linker flags
ifeq ($(shell uname),Darwin)
	CFLAGS += -undefined dynamic_lookup
	LDFLAGS += -undefined dynamic_lookup
endif

# Set source and object files
SRC = termbox2_nif.c termbox2/termbox_impl.c
OBJ = termbox2_nif.o termbox2/termbox_impl.o

# Set target library name
TARGET = termbox2_nif.so

# Default target
all: $(TARGET)

# Compile termbox2_nif.c
termbox2_nif.o: termbox2_nif.c
	$(CC) $(CFLAGS) $(ERL_CFLAGS) -I. -c $< -o $@

# Compile termbox2/termbox_impl.c
termbox2/termbox_impl.o: termbox2/termbox_impl.c
	$(CC) $(CFLAGS) -c $< -o $@

# Link object files into shared library
$(TARGET): $(OBJ)
	$(CC) $(LDFLAGS) $(ERL_LDFLAGS) $^ -o $@
	mkdir -p ../priv
	cp $(TARGET) ../priv/

# Clean build artifacts
clean:
	rm -f $(OBJ) $(TARGET)

.PHONY: all clean
