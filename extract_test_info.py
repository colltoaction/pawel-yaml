#!/usr/bin/env python3
"""Extract metadata from a test case."""
import sys
import yaml

def extract_test_info(test_id, suite_dir, field, default=None):
    """Extract a specific field from a test file.

    Returns:
        0 if field was found and printed
        1 if field was not found (default printed if provided)
    """
    test_file = f"{suite_dir}/src/{test_id}.yaml"

    try:
        with open(test_file, 'r') as f:
            content = yaml.safe_load(f)

        # Content is a list with a single test case dict
        if isinstance(content, list) and len(content) > 0:
            test_case = content[0]
            if isinstance(test_case, dict):
                if field in test_case:
                    value = test_case[field]
                    # Convert to string representation
                    if isinstance(value, bool):
                        print(str(value).lower())
                    else:
                        print(str(value))
                    return 0
                elif default is not None:
                    # Print default value if field not found
                    if isinstance(default, bool):
                        print(str(default).lower())
                    else:
                        print(str(default))
                    return 0

        # Field not found and no default
        if default is not None:
            if isinstance(default, bool):
                print(str(default).lower())
            else:
                print(str(default))
            return 0
        return 1
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

if __name__ == '__main__':
    if len(sys.argv) != 4:
        print("Usage: extract_test_info.py TEST_ID SUITE_DIR FIELD", file=sys.stderr)
        sys.exit(1)

    test_id = sys.argv[1]
    suite_dir = sys.argv[2]
    field = sys.argv[3]
    sys.exit(extract_test_info(test_id, suite_dir, field))
