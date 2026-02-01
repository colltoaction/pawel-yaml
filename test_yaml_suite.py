#!/usr/bin/env python3
import os
import sys
import yaml
import subprocess

test_dir = "build/lib/yaml-test-suite/src"
failing_tests = []

with open("TEST_FAILURES.yaml") as f:
    for line in f:
        line = line.strip()
        if line and line.startswith("- "):
            test_id = line[2:]
            failing_tests.append(test_id)

# Categorize by tags
results = {
    'pass': [],
    'fail': [],
    'error': [],
    'categories': {}
}

for test_id in failing_tests[:30]:  # Test first 30
    yaml_file = os.path.join(test_dir, f"{test_id}.yaml")
    if not os.path.exists(yaml_file):
        continue
    
    with open(yaml_file) as f:
        content = f.read()
    
    # Extract tags
    tags_line = [l.strip() for l in content.split('\n') if 'tags:' in l]
    tags = tags_line[0].replace('tags:', '').strip() if tags_line else "unknown"
    
    # Extract yaml content and expected result using PyYAML for correctness
    try:
        data = yaml.safe_load(content)
        if isinstance(data, list) and len(data) > 0:
            data = data[0]
        yaml_content = data.get('yaml', '')
        should_fail = data.get('fail', False)
    except Exception as e:
        print(f"ERROR: Could not parse test file {test_id}: {e}")
        continue
    
    # Test with our parser
    try:
        result = subprocess.run(
            ['./build/bin/pawel-yaml'],
            input=yaml_content,
            capture_output=True,
            timeout=1,
            text=True
        )
        parser_failed = result.returncode != 0
    except subprocess.TimeoutExpired:
        parser_failed = True
    except Exception as e:
        parser_failed = True
    
    # Store result
    if tags not in results['categories']:
        results['categories'][tags] = {'pass': 0, 'fail': 0}
    
    if should_fail == parser_failed:
        results['pass'].append(test_id)
        results['categories'][tags]['pass'] += 1
    else:
        results['fail'].append(test_id)
        results['categories'][tags]['fail'] += 1
        print(f"DEBUG: {test_id} failed. returncode={result.returncode if not isinstance(result, Exception) else 'N/A'}, stderr={result.stderr if hasattr(result, 'stderr') else ''}")

print(f"Tests passed: {len(results['pass'])}/{len(results['pass']) + len(results['fail'])}")
print("\nBy category:")
for cat, res in sorted(results['categories'].items()):
    total = res['pass'] + res['fail']
    pct = 100 * res['pass'] / total if total > 0 else 0
    print(f"  {cat}: {res['pass']}/{total} ({pct:.0f}%)")

print("\nFailing test IDs:")
for test_id in results['fail'][:10]:
    print(f"  - {test_id}")
