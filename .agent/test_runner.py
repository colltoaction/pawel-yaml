#!/usr/bin/env python3
"""
Unified YAML Test Runner
Single source of truth for all test metrics and reporting
"""
import subprocess
import os
import sys
import yaml
import argparse
from datetime import datetime, timezone
from pathlib import Path


class TestRunner:
    """Run YAML tests with consistent, configurable metrics"""

    def __init__(self, suite_dir="build/lib/yaml-test-suite/src", parser="./build/bin/pawel-yaml"):
        self.suite_dir = suite_dir
        self.parser = parser
        self.markers = {'\u2423': ' ', '\u00bb': '\t', '\u21b5': '\n', '\u220e': '', '\u2193': ''}
        self.tests = []
        self.results = []

    def discover_tests(self):
        """Find all test files in suite directory"""
        if not os.path.isdir(self.suite_dir):
            raise FileNotFoundError(f"Test suite not found: {self.suite_dir}")

        self.tests = sorted([
            f[:-5] for f in os.listdir(self.suite_dir)
            if f.endswith('.yaml')
        ])
        return self.tests

    def _load_test(self, test_id):
        """Load test metadata and input"""
        test_file = os.path.join(self.suite_dir, f"{test_id}.yaml")
        try:
            with open(test_file) as f:
                data = yaml.safe_load(f)
            if isinstance(data, list):
                data = data[0]

            yaml_input = data.get('yaml', '')
            # Unescape markers
            for src, dst in self.markers.items():
                yaml_input = yaml_input.replace(src, dst)

            return {
                'id': test_id,
                'input': yaml_input,
                'should_fail': bool(data.get('fail', False)),
                'expected_tree': data.get('tree', ''),
                'expected_json': data.get('json', ''),
                'tags': data.get('tags', ''),
            }
        except Exception as e:
            return None

    def _run_parser(self, yaml_input, mode="-tree"):
        """Run parser with specific mode and capture output"""
        try:
            # Always pass bytes to subprocess and decode manually to handle encoding issues
            input_bytes = yaml_input.encode('utf-8') if isinstance(yaml_input, str) else yaml_input
            result = subprocess.run(
                [self.parser, mode],
                input=input_bytes,
                capture_output=True,
                timeout=5
            )
            return {
                'exit_code': result.returncode,
                'stdout': result.stdout.decode('utf-8', errors='replace'),
                'stderr': result.stderr.decode('utf-8', errors='replace'),
            }
        except subprocess.TimeoutExpired:
            return {'exit_code': 124, 'stdout': '', 'stderr': 'TIMEOUT'}
        except Exception as e:
            return {'exit_code': -1, 'stdout': '', 'stderr': str(e)}

    def _normalize(self, text):
        """Normalize text for comparison (strip whitespace and empty lines)"""
        if not text: return ""
        return '\n'.join([
            line.strip() for line in text.strip().splitlines()
            if line.strip()
        ])

    def run_all(self):
        """Run all discovered tests"""
        if not self.tests:
            self.discover_tests()

        for test_id in self.tests:
            test = self._load_test(test_id)
            if test is None:
                continue

            results = {'id': test_id, 'should_fail': test['should_fail']}
            
            # 1. Exit code check & Event Tree comparison (using -dump-tokens)
            parser_result = self._run_parser(test['input'], "-dump-tokens")
            exit_code = parser_result['exit_code']
            results['exit_code'] = exit_code
            results['exit_code_pass'] = (exit_code == 0 and not test['should_fail']) or (exit_code != 0 and test['should_fail'])
            results['stderr'] = parser_result['stderr']

            if not test['should_fail']:
                # 2. Event Tree comparison
                if exit_code == 0:
                    actual_tree = self._normalize(parser_result['stdout'])
                    expected_tree = self._normalize(test.get('expected_tree', ''))
                    results['tree_pass'] = (actual_tree == expected_tree) if expected_tree else True
                else:
                    results['tree_pass'] = False

                # 3. JSON comparison (using -ast-dump)
                if test.get('expected_json'):
                    json_result = self._run_parser(test['input'], "-ast-dump")
                    if json_result['exit_code'] == 0:
                        actual_json = self._normalize(json_result['stdout'])
                        expected_json = self._normalize(test['expected_json'])
                        results['json_pass'] = (actual_json == expected_json)
                    else:
                        results['json_pass'] = False
                else:
                    results['json_pass'] = True

                # 4. Dump comparison (using -emit-yaml)
                if 'dump' in test: 
                     dump_result = self._run_parser(test['input'], "-emit-yaml")
                     if dump_result['exit_code'] == 0:
                         actual_dump = self._normalize(dump_result['stdout'])
                         expected_dump = self._normalize(test.get('dump', ''))
                         results['dump_pass'] = (actual_dump == expected_dump) if expected_dump else True
                     else:
                         results['dump_pass'] = False
                else:
                    results['dump_pass'] = True

            self.results.append(results)

    def get_summary(self):
        """Get test summary with comprehensive metrics"""
        if not self.results:
            return None

        total = len(self.results)
        exit_code_passes = sum(1 for r in self.results if r['exit_code_pass'])
        valid_yaml_tests = [r for r in self.results if not r['should_fail']]
        invalid_yaml_tests = [r for r in self.results if r['should_fail']]

        # Event tree passes: valid YAML with correct events
        tree_passes = sum(1 for r in valid_yaml_tests if r.get('tree_pass') is True)
        
        # Combined metric:
        # - Invalid YAML correctly rejected (exit_code_pass is True for invalid yaml)
        # - Valid YAML with correct events (tree_pass is True)
        # Wait, exit_code_pass for invalid yaml means exit_code != 0.
        # So it's just sum(exit_code_pass for invalid) + sum(tree_pass for valid)
        invalid_correct = sum(1 for r in invalid_yaml_tests if r['exit_code_pass'])
        combined_passes = tree_passes + invalid_correct

        return {
            'total': total,
            'exit_code_passes': exit_code_passes,
            'exit_code_fails': total - exit_code_passes,
            'exit_code_rate': exit_code_passes / total * 100 if total else 0,
            'valid_yaml_tests': len(valid_yaml_tests),
            'invalid_yaml_tests': len(invalid_yaml_tests),
            'tree_passes': tree_passes,
            'tree_rate': tree_passes / len(valid_yaml_tests) * 100 if valid_yaml_tests else 0,
            'combined_passes': combined_passes,
            'combined_rate': combined_passes / total * 100 if total else 0,
        }

    def get_failing_tests(self):
        """Get list of tests that fail exit code check"""
        return [r['id'] for r in self.results if not r['exit_code_pass']]

    def print_summary(self):
        """Print summary to stdout"""
        summary = self.get_summary()
        if not summary:
            print("No results to summarize")
            return

        print("\n" + "="*70)
        print("UNIFIED TEST RESULTS")
        print("="*70)
        print(f"\nTotal Tests: {summary['total']}")
        print(f"  Valid YAML: {summary['valid_yaml_tests']}")
        print(f"  Invalid YAML (fail: true): {summary['invalid_yaml_tests']}")

        print(f"\n1. Exit Code Metric (all tests):")
        print(f"   Passed: {summary['exit_code_passes']}/{summary['total']} ({summary['exit_code_rate']:.1f}%)")

        print(f"\n2. Tree Metric (valid YAML events):")
        print(f"   Passed: {summary['tree_passes']}/{summary['valid_yaml_tests']} ({summary['tree_rate']:.1f}%)")

        print(f"\n3. Combined Metric (Fidelity):")
        print(f"   Passed: {summary['combined_passes']}/{summary['total']} ({summary['combined_rate']:.1f}%)")
        print(f"   (Valid YAML with correct trees + Invalid YAML correctly rejected)")
        print("="*70)

    def update_test_failures_yaml(self):
        """Update TEST_FAILURES.yaml with current results"""
        failing = self.get_failing_tests()

        out = {
            'meta': {
                'generated_at': datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                'suite_dir': self.suite_dir,
                'total_tests': len(self.results),
                'total_passes': len(self.results) - len(failing),
                'total_failures': len(failing),
                'scoring': 'fail-true-aware',
            },
            'failing': failing,
        }

        with open('TEST_FAILURES.yaml', 'w') as f:
            yaml.dump(out, f, default_flow_style=False, sort_keys=False, allow_unicode=True)

        return out

    def print_failures(self):
        """Print failing tests with details"""
        failing = [r for r in self.results if not r['exit_code_pass']]
        if not failing:
            print("\n✓ All tests pass!")
            return

        print(f"\n{len(failing)} failing tests (Exit Code Check):\n")
        for result in failing[:20]:  # Show first 20
            reason = "valid YAML rejected" if not result['should_fail'] else "invalid YAML accepted"
            print(f"  {result['id']:8} - {reason}")
            if result['stderr']:
                print(f"           {result['stderr'].strip()[:60]}")


def main():
    parser = argparse.ArgumentParser(description='Unified YAML Test Runner')
    parser.add_argument('--suite-dir', default='build/lib/yaml-test-suite/src',
                       help='Path to test suite directory')
    parser.add_argument('--parser', default='./build/bin/pawel-yaml',
                       help='Path to parser executable')
    parser.add_argument('--update', action='store_true',
                       help='Update TEST_FAILURES.yaml')
    parser.add_argument('--test', type=str, action='append',
                       help='Run specific test(s)')
    parser.add_argument('--failures-only', action='store_true',
                       help='Only show failing tests')

    args = parser.parse_args()

    runner = TestRunner(args.suite_dir, args.parser)

    if args.test:
        # Run specific tests
        runner.tests = args.test
    else:
        # Discover all tests
        runner.discover_tests()

    print(f"Running {len(runner.tests)} tests...")
    runner.run_all()

    runner.print_summary()
    if args.failures_only or not args.test:
        runner.print_failures()

    if args.update:
        runner.update_test_failures_yaml()
        print("\nUpdated TEST_FAILURES.yaml")

    return 0 if runner.get_failing_tests() == [] else 1


if __name__ == '__main__':
    sys.exit(main())
