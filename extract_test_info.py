import sys
import os
import yaml

def extract_info(test_id, suite_dir, key):
    yaml_file = os.path.join(suite_dir, "src", f"{test_id}.yaml")
    if not os.path.exists(yaml_file):
        sys.exit(1)
    
    with open(yaml_file, 'r') as f:
        try:
            data = yaml.safe_load(f)
            if isinstance(data, list):
                data = data[0]
            val = data.get(key, '')
            if isinstance(val, bool):
                print(str(val).lower())
            else:
                print(val)
        except Exception:
            # Fallback
            f.seek(0)
            content = f.read()
            if key == 'fail':
                if 'fail: true' in content:
                    print('true')
                else:
                    print('false')
            else:
                # Basic search
                for line in content.split('\n'):
                    if line.strip().startswith(f"{key}:"):
                        print(line.split(':', 1)[1].strip())
                        break

if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(1)
    extract_info(sys.argv[1], sys.argv[2], sys.argv[3])
