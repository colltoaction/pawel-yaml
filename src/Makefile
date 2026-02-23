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
YACC = bison
CFLAGS ?= -Wall -pedantic -g
YFLAGS ?= -d
LFLAGS ?= -w

# Active language canvas (grow from stream grammar/lexer first)
STREAM_GRAMMAR ?= $(SRC_DIR)/stream.y
STREAM_LEXER ?= $(SRC_DIR)/stream.l

VPATH = $(SRC_DIR):$(BUILDSRCDIR):$(BUILDINCDIR)
COMPILE_CFLAGS = $(CFLAGS) -I$(BUILDINCDIR) -I$(SRC_DIR) -I$(SRC_DIR)/stubs/inc
COMPILE_GEN_CFLAGS = $(COMPILE_CFLAGS) -Wno-unused-function -Wno-unused-variable -Wno-error=cpp

# Auto-discovered static source inventory.
C_SOURCES = $(sort $(wildcard $(SRC_DIR)/*.c))
STATIC_OBJECTS = $(patsubst $(SRC_DIR)/%.c,$(BUILD_OBJDIR)/%.o,$(C_SOURCES))

# Real parser/lexer artifacts for the stream canvas.
TAB_C_GENERATED = $(BUILDSRCDIR)/stream.tab.c
TAB_H_GENERATED = $(BUILDINCDIR)/stream.tab.h
TAB_OBJECTS = $(BUILD_OBJDIR)/stream.tab.o

LEX_C_GENERATED = $(BUILDSRCDIR)/stream.lex.c
LEX_OBJECTS = $(BUILD_OBJDIR)/stream.lex.o

# Keep compatibility stubs for non-stream parser symbols referenced by legacy modules.
COMPAT_PARSER_OBJ = $(BUILD_OBJDIR)/stubs_parser.o
COMPAT_LEXER_OBJ = $(BUILD_OBJDIR)/stubs_lexer.o

OBJECTS = $(STATIC_OBJECTS) $(TAB_OBJECTS) $(LEX_OBJECTS) $(COMPAT_PARSER_OBJ) $(COMPAT_LEXER_OBJ)

all: $(BINTARGET)

directories:
	@mkdir -p $(BUILD_ROOT) $(BINDIR) $(BUILDSRCDIR) $(BUILDINCDIR) $(BUILD_OBJDIR)

# Grammar generation.
$(TAB_C_GENERATED) $(TAB_H_GENERATED): $(STREAM_GRAMMAR) | directories
	$(YACC) $(YFLAGS) -o $(TAB_C_GENERATED) $(STREAM_GRAMMAR)
	@if [ -f $(BUILDSRCDIR)/stream.tab.h ]; then mv $(BUILDSRCDIR)/stream.tab.h $(TAB_H_GENERATED); fi

# Lexer generation.
lex: $(LEX_C_GENERATED)

$(LEX_C_GENERATED): $(STREAM_LEXER) $(TAB_H_GENERATED) | directories
	$(LEX) $(LFLAGS) -o $(LEX_C_GENERATED) $(STREAM_LEXER)

# Rule for compiling src/*.c to .o
$(BUILD_OBJDIR)/%.o: $(SRC_DIR)/%.c | directories
	$(CC) $(COMPILE_CFLAGS) -c $< -o $@

# Rule for compiling generated *.c to .o
$(BUILD_OBJDIR)/%.o: $(BUILDSRCDIR)/%.c | directories
	$(CC) $(COMPILE_GEN_CFLAGS) -c $< -o $@

# Compatibility parser stubs (non-stream grammars)
$(COMPAT_PARSER_OBJ): $(SRC_DIR)/stubs/parser_stubs.c | directories
	$(CC) $(COMPILE_CFLAGS) -c $< -o $@

# Compatibility lexer stubs (non-stream lexers)
$(COMPAT_LEXER_OBJ): $(SRC_DIR)/stubs/lexer_stubs.c | directories
	$(CC) $(COMPILE_CFLAGS) -c $< -o $@

# Static objects that include stream.tab.h
$(STATIC_OBJECTS): $(TAB_H_GENERATED)

$(BINTARGET): $(OBJECTS) | directories
	$(CC) $(OBJECTS) -o $@

clean:
	rm -rf $(BINDIR) $(BUILDSRCDIR) $(BUILDINCDIR) $(BUILD_OBJDIR)

.PHONY: all directories lex clean
