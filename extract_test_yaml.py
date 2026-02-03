import sys
import os
import yaml

def extract_yaml(test_id, suite_dir):
    yaml_file = os.path.join(suite_dir, "src", f"{test_id}.yaml")
    if not os.path.exists(yaml_file):
        sys.exit(1)
    
    with open(yaml_file, 'r') as f:
        # The files in src/*.yaml are actually YAML themselves or similar format
        # Looking at 5TRB.yaml, it starts with --- and is a list or single doc
        try:
            data = yaml.safe_load(f)
            if isinstance(data, list):
                data = data[0]
            print(data.get('yaml', ''))
        except Exception:
            # Fallback to manual extraction like test_yaml_suite.py
            f.seek(0)
            content = f.read()
            in_yaml = False
            yaml_content = ""
            for line in content.split('\n'):
                if line.strip().startswith('yaml:'):
                    in_yaml = True
                    continue
                if in_yaml:
                    if line.startswith('  '):
                        yaml_content += line[2:] + '\n'
                    elif line and not line.startswith(' '):
                        break
            print(yaml_content)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(1)
    extract_yaml(sys.argv[1], sys.argv[2])
