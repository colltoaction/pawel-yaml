SHELL = /bin/sh

# Build locations passed from the repository root Makefile.
BUILD_ROOT ?= ../build
BINDIR ?= $(BUILD_ROOT)/bin
BUILDSRCDIR ?= $(BUILD_ROOT)/src
BUILDINCDIR ?= $(BUILD_ROOT)/inc
BUILD_OBJDIR ?= $(BUILD_ROOT)/obj
BINTARGET ?= $(BINDIR)/pawel-yaml
SRC_DIR ?= .

# Toolchain
CC ?= gcc
LEX ?= flex
YACC ?= bison
CFLAGS ?= -Wall -pedantic -g
YFLAGS ?= -d
LFLAGS ?= -w

VPATH = $(SRC_DIR):$(BUILDSRCDIR):$(BUILDINCDIR)
COMPILE_CFLAGS = $(CFLAGS) -I$(BUILDINCDIR) -I$(SRC_DIR)
COMPILE_GEN_CFLAGS = $(COMPILE_CFLAGS) -Wno-unused-function -Wno-unused-variable -Wno-error=cpp

# Auto-discovered source inventory.
C_SOURCES = $(sort $(wildcard $(SRC_DIR)/*.c))
Y_SOURCES = $(sort $(wildcard $(SRC_DIR)/*.y))
L_SOURCES = $(sort $(wildcard $(SRC_DIR)/*.l))
H_SOURCES = $(sort $(wildcard $(SRC_DIR)/*.h))

TAB_C_GENERATED = $(patsubst $(SRC_DIR)/%.y,$(BUILDSRCDIR)/%.tab.c,$(Y_SOURCES))
TAB_H_GENERATED = $(patsubst $(SRC_DIR)/%.y,$(BUILDINCDIR)/%.tab.h,$(Y_SOURCES))
LEX_C_GENERATED = $(patsubst $(SRC_DIR)/%.l,$(BUILDSRCDIR)/%.lex.c,$(L_SOURCES))

STATIC_OBJECTS = $(patsubst $(SRC_DIR)/%.c,$(BUILD_OBJDIR)/%.o,$(C_SOURCES))
TAB_OBJECTS = $(patsubst $(BUILDSRCDIR)/%.tab.c,$(BUILD_OBJDIR)/%.tab.o,$(TAB_C_GENERATED))
LEX_OBJECTS = $(patsubst $(BUILDSRCDIR)/%.lex.c,$(BUILD_OBJDIR)/%.lex.o,$(LEX_C_GENERATED))

OBJECTS = $(STATIC_OBJECTS) $(TAB_OBJECTS) $(LEX_OBJECTS)

all: $(BINTARGET)

directories:
	@mkdir -p $(BUILD_ROOT) $(BINDIR) $(BUILDSRCDIR) $(BUILDINCDIR) $(BUILD_OBJDIR)

# Grammar gen tabs
$(BUILDSRCDIR)/%.tab.c $(BUILDINCDIR)/%.tab.h: $(SRC_DIR)/%.y | directories
	$(YACC) $(YFLAGS) -o $(BUILDSRCDIR)/$*.tab.c $<
	@if [ -f $(BUILDSRCDIR)/$*.tab.h ]; then mv $(BUILDSRCDIR)/$*.tab.h $(BUILDINCDIR)/$*.tab.h; fi

# Grammar gen lex
lex: $(LEX_C_GENERATED)

$(BUILDSRCDIR)/%.lex.c: $(SRC_DIR)/%.l | directories
	$(LEX) $(LFLAGS) -o $@ $<

$(LEX_C_GENERATED): $(TAB_H_GENERATED)

$(LEX_OBJECTS): $(TAB_H_GENERATED)

# Rule for compiling src/*.c to .o
$(BUILD_OBJDIR)/%.o: $(SRC_DIR)/%.c | directories
	$(CC) $(COMPILE_CFLAGS) -c $< -o $@

# Rule for compiling generated *.c to .o
$(BUILD_OBJDIR)/%.o: $(BUILDSRCDIR)/%.c | directories
	$(CC) $(COMPILE_GEN_CFLAGS) -c $< -o $@

$(STATIC_OBJECTS): $(TAB_H_GENERATED)

$(BINTARGET): $(OBJECTS) | directories
	$(CC) $(OBJECTS) -o $@

clean:
	rm -rf $(BINDIR) $(BUILDSRCDIR) $(BUILDINCDIR) $(BUILD_OBJDIR)

.PHONY: all directories lex clean
