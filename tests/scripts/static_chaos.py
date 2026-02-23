#!/usr/bin/env python3
import re
import os
import glob

def get_returned_tokens(lex_file):
    tokens = set()
    with open(lex_file, 'r') as f:
        content = f.read()
        # Find lines like "return TOKEN;"
        # We need to handle C comments and spacing
        # Simple regex: return\s+([A-Z_]+)\s*;
        matches = re.findall(r'return\s+([A-Z_][A-Z0-9_]*)\s*;', content)
        for m in matches:
            if m not in ['YY_NULL', 'YY_START', '0', '1', 'NULL']: # Ignore non-token returns
                tokens.add(m)
    return tokens

def get_used_tokens(yacc_file):
    used = set()
    with open(yacc_file, 'r') as f:
        content = f.read()
        # Remove comments? simple parse
        # Find usage in rules.
        # A simple approximation: any word that matches a known token pattern.
        # But better: check %token definitions and then usages.

        # Extract %token definitions
        defined = set()
        token_lines = re.findall(r'%token\s+(?:<[^>]+>)?\s*(.*)', content)
        for line in token_lines:
            # split by space
            parts = line.split()
            for p in parts:
                if re.match(r'^[A-Z_][A-Z0-9_]*$', p):
                    defined.add(p)

        # Now find occurrences in the grammar section (after %%)
        # This is harder to parse robustly with regex, but we can search for the defined tokens in the file
        # and if they appear in the rules section, they are used.

        parts = content.split('%%')
        if len(parts) >= 2:
            grammar_section = parts[1]
            for token in defined:
                # Check if token appears in grammar section
                # Avoid matching suffixes (e.g. TOKEN_2)
                if re.search(r'\b' + re.escape(token) + r'\b', grammar_section):
                    used.add(token)

    return defined, used

def main():
    lex_files = glob.glob('src/*.l')
    yacc_files = glob.glob('src/*.y')

    print("Static Chaos Analysis: Unused Lexer Rules")
    print("=========================================")

    lexer_tokens = set()
    for lf in lex_files:
        if 'scanning.l.orig' in lf: continue
        t = get_returned_tokens(lf)
        print(f"Tokens returned by {lf}: {len(t)}")
        lexer_tokens.update(t)

    parser_defined = set()
    parser_used = set()
    for yf in yacc_files:
        d, u = get_used_tokens(yf)
        print(f"Tokens defined in {yf}: {len(d)}")
        print(f"Tokens used in {yf}: {len(u)}")
        parser_defined.update(d)
        parser_used.update(u)

    print("\nAnalysis:")
    print(f"Total unique tokens returned by lexer: {len(lexer_tokens)}")
    print(f"Total unique tokens defined in parser: {len(parser_defined)}")
    print(f"Total unique tokens used in parser: {len(parser_used)}")

    unused_by_grammar = lexer_tokens - parser_used

    if unused_by_grammar:
        print("\nTokens returned by lexer but NOT used in grammar (potentially unused rules):")
        for t in sorted(unused_by_grammar):
            print(f" - {t}")
    else:
        print("\nAll tokens returned by lexer are used in grammar.")

    # Also check if there are tokens defined in parser but never returned by lexer (dead tokens)
    never_produced = parser_used - lexer_tokens
    # Filter out bison built-ins or special cases
    never_produced = {t for t in never_produced if t not in ['YYEOF', 'YYACCEPT', 'YYEMPTY', 'error']}

    if never_produced:
        print("\nTokens used in grammar but NEVER returned by lexer (dead grammar branches):")
        for t in sorted(never_produced):
            print(f" - {t}")

if __name__ == "__main__":
    main()
