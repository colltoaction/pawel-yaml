import sys
import os
import yaml

def convert_special_chars(text):
    """Convert yaml-test-suite visual characters to actual characters.
    
    The test suite uses special Unicode characters to represent whitespace:
    - ␣ (U+2423 OPEN BOX) → space
    - ———» / ——» / —» / » (em-dash + right arrow) → tab (hard tab)
    - ↵ (U+21B5 DOWNWARDS ARROW WITH CORNER LEFTWARDS) → newline
    - ← (U+2190) → carriage return
    """
    if not text:
        return text
    # Tab representations (longest first to avoid partial matches)
    text = text.replace('\u2014\u2014\u2014\u00BB', '\t')  # ———»
    text = text.replace('\u2014\u2014\u00BB', '\t')          # ——»
    text = text.replace('\u2014\u00BB', '\t')                # —»
    text = text.replace('\u00BB', '\t')                      # »
    # Space representation
    text = text.replace('\u2423', ' ')                       # ␣ → space
    # Newline representation  
    text = text.replace('\u21B5', '\n')                      # ↵ → newline
    return text

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
            raw = data.get('yaml', '')
            print(convert_special_chars(raw))
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
            print(convert_special_chars(yaml_content))

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(1)
    extract_yaml(sys.argv[1], sys.argv[2])
