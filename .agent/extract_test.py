#!/usr/bin/env python3
"""
Extract YAML test content from yaml-test-suite test case
Usage: extract_test.py <test_file> <output_yaml> <output_meta>
"""
import yaml
import sys

if len(sys.argv) != 4:
    sys.exit(1)

VISUAL_MARKERS = {
    "␣": " ",   # visible space marker
    "—": " ",   # leading/trailing space marker used in suite fixtures
    "»": "\t",  # tab marker
    "↵": "\n",  # explicit line-break marker
    "∎": "",    # end-of-input marker
    "↓": "",    # annotation marker
}

def normalize_yaml_text(text):
    if not text:
        return text
    for src, dst in VISUAL_MARKERS.items():
        text = text.replace(src, dst)
    return text

try:
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f)
        if isinstance(data, list):
            data = data[0]
    
    # Write YAML content
    with open(sys.argv[2], 'w') as out:
        out.write(normalize_yaml_text(data.get('yaml', '')))
    
    # Write metadata (should fail)
    with open(sys.argv[3], 'w') as meta:
        meta.write(str(data.get('fail', False)))
    
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
