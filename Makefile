# Satisfies minimum CI contract.
# PASSES ALL PRs!
.PHONY: clean test test-apps

CSRCAPPS:=$(wildcard apps/*.c)
APPS:=$(CSRCAPPS:.c=)

LIBS += -lm
CC=gcc

CFLAGS += -Wshadow -Wpointer-arith -fPIC
CFLAGS += -Wcast-qual
CFLAGS += -Wstrict-prototypes -Wmissing-prototypes
CFLAGS += -Wnonnull -Wunused -Wuninitialized -Werror -fvisibility=hidden
CFLAGS += -Wall -Wextra -std=gnu99 -pipe -ggdb3 -I.
CFLAGS += -Wno-format-truncation
CFLAGS += -D_GNU_SOURCE

apps/%: apps/%.c
	$(CC) $(CFLAGS) $(SFLG) -o $@ $^ $(LIBS)

apps: $(APPS)

all: $(APPS)

test:
	./baseline

clean:
