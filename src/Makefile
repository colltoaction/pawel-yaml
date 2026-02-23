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
YACC := bison
CFLAGS ?= -Wall -pedantic -g
YFLAGS ?= -d
LFLAGS ?= -w

# Feature flags (default 0 for missing tools env)
ENABLE_PARSER ?= 0
ENABLE_LEXER ?= 0

VPATH = $(SRC_DIR):$(BUILDSRCDIR):$(BUILDINCDIR)
COMPILE_CFLAGS = $(CFLAGS) -I$(BUILDINCDIR) -I$(SRC_DIR)
COMPILE_GEN_CFLAGS = $(COMPILE_CFLAGS) -Wno-unused-function -Wno-unused-variable -Wno-error=cpp

# Auto-discovered source inventory.
C_SOURCES = $(sort $(wildcard $(SRC_DIR)/*.c))
H_SOURCES = $(sort $(wildcard $(SRC_DIR)/*.h))

STATIC_OBJECTS = $(patsubst $(SRC_DIR)/%.c,$(BUILD_OBJDIR)/%.o,$(C_SOURCES))

# Parser configuration
ifeq ($(ENABLE_PARSER),1)
Y_SOURCES = $(sort $(wildcard $(SRC_DIR)/*.y))
TAB_C_GENERATED = $(patsubst $(SRC_DIR)/%.y,$(BUILDSRCDIR)/%.tab.c,$(Y_SOURCES))
TAB_H_GENERATED = $(patsubst $(SRC_DIR)/%.y,$(BUILDINCDIR)/%.tab.h,$(Y_SOURCES))
TAB_OBJECTS = $(patsubst $(BUILDSRCDIR)/%.tab.c,$(BUILD_OBJDIR)/%.tab.o,$(TAB_C_GENERATED))
else
COMPILE_CFLAGS += -I$(SRC_DIR)/stubs/inc
STUB_PARSER_OBJ = $(BUILD_OBJDIR)/stubs_parser.o
TAB_H_GENERATED =
TAB_OBJECTS = $(STUB_PARSER_OBJ)
endif

# Lexer configuration
ifeq ($(ENABLE_LEXER),1)
L_SOURCES = $(sort $(wildcard $(SRC_DIR)/*.l))
LEX_C_GENERATED = $(patsubst $(SRC_DIR)/%.l,$(BUILDSRCDIR)/%.lex.c,$(L_SOURCES))
LEX_OBJECTS = $(patsubst $(BUILDSRCDIR)/%.lex.c,$(BUILD_OBJDIR)/%.lex.o,$(LEX_C_GENERATED))
else
STUB_LEXER_OBJ = $(BUILD_OBJDIR)/stubs_lexer.o
LEX_C_GENERATED =
LEX_OBJECTS = $(STUB_LEXER_OBJ)
endif

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

# Stub objects
$(BUILD_OBJDIR)/stubs_parser.o: $(SRC_DIR)/stubs/parser_stubs.c | directories
	$(CC) $(COMPILE_CFLAGS) -c $< -o $@

$(BUILD_OBJDIR)/stubs_lexer.o: $(SRC_DIR)/stubs/lexer_stubs.c | directories
	$(CC) $(COMPILE_CFLAGS) -c $< -o $@

$(STATIC_OBJECTS): $(TAB_H_GENERATED)

$(BINTARGET): $(OBJECTS) | directories
	$(CC) $(OBJECTS) -o $@

clean:
	rm -rf $(BINDIR) $(BUILDSRCDIR) $(BUILDINCDIR) $(BUILD_OBJDIR)

.PHONY: all directories lex clean
