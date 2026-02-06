# YAML Compilation Pipeline
SHELL = /bin/sh

# Installation
BUILD = ./build
BINDIR = $(BUILD)/bin
BUILDSRCDIR = $(BUILD)/src
BUILDINCDIR = $(BUILD)/inc
BUILD_OBJDIR = $(BUILD)/obj
VPATH = src:$(BUILDSRCDIR):$(BUILDINCDIR)

# Build
CC = gcc
LEX = flex
YACC = bison
CFLAGS = -Wall -pedantic -g -I$(BUILDINCDIR) -Isrc
YFLAGS = -d
LFLAGS = -w

# Generated files
# TODO $(wildcard BUILD_OBJDIR/*.o)
OBJECTS = $(BUILD_OBJDIR)/main.o $(BUILD_OBJDIR)/scanning.lex.o $(BUILD_OBJDIR)/parsing.tab.o $(BUILD_OBJDIR)/composition.lex.o $(BUILD_OBJDIR)/composition.tab.o
BINTARGET = $(BUILD)/bin/pawel-yaml

# Rules
all: $(BINTARGET)

directories:
	@mkdir -p $(BUILD) $(BUILD)/bin $(BUILDSRCDIR) $(BUILDINCDIR) $(BUILD_OBJDIR)

# Grammar gen tabs
$(BUILDSRCDIR)/%.tab.c $(BUILDINCDIR)/%.tab.h: src/%.y directories
	$(YACC) $(YFLAGS) -o $(BUILDSRCDIR)/$*.tab.c $<

# Grammar gen lex
LEXTARGETS = $(patsubst src/%.l, $(BUILDSRCDIR)/%.lex.c, $(wildcard src/*.l))
lex: $(LEXTARGETS)

$(BUILDSRCDIR)/%.lex.c: src/%.l directories
	$(LEX) $(LFLAGS) -o $@ $<

$(BUILDSRCDIR)/scanning.lex.c: $(BUILDINCDIR)/parsing.tab.h
$(BUILDSRCDIR)/composition.lex.c: $(BUILDINCDIR)/composition.tab.h

# Rule for compiling .c to .o in build
$(BUILD_OBJDIR)/main.o: src/main.c directories
	$(CC) $(CFLAGS) -Werror -c $< -o $@

# Rule for compiling .c to .o in build
$(BUILD_OBJDIR)/%.o: $(BUILDSRCDIR)/%.c directories
	$(CC) $(CFLAGS) -Wno-unused-function -Wno-unused-variable -Wno-error=cpp -c $< -o $@

$(BINTARGET): $(OBJECTS) directories
	$(CC) $(OBJECTS) -o $@

# Testing
check: $(BINTARGET)
	./$< < test.yaml > /dev/null
	@echo "✓ Basic sanity check passed"

# Cleanup
clean:
	rm -rf $(BUILD)

.PHONY: all directories check clean lex
