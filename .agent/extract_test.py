#!/usr/bin/env python3
"""
Extract YAML test content from yaml-test-suite test case
Usage: extract_test.py <test_file> <output_yaml> <output_meta>
"""
import yaml
import sys

if len(sys.argv) != 4:
    sys.exit(1)

try:
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f)
        if isinstance(data, list):
            data = data[0]
    
    # Write YAML content
    with open(sys.argv[2], 'w') as out:
        out.write(data.get('yaml', ''))
    
    # Write metadata (should fail)
    with open(sys.argv[3], 'w') as meta:
        meta.write(str(data.get('fail', False)))
    
    sys.exit(0)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
