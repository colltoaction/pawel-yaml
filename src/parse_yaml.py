import yaml
import sys
import os

# parse_yaml.py
# Converts MRL YAML to a simple header file or a data file for C.
# For now, let's generate a C file that initializes the Grammar and StringDiagram.

def generate_c_code(data):
    lines = []
    lines.append('#include "mrl.h"')
    lines.append('')
    lines.append('Grammar* setup_mrl(Alphabet** out_alphabet, StringDiagram** out_sd) {')
    lines.append('    Alphabet* a = create_alphabet();')
    
    # Alphabet
    gen_map = {}
    for gen in data.get('alphabet', []):
        name = str(gen['name'])
        arity = gen['arity']
        coarity = gen['coarity']
        # Clean name for C variable
        c_name = name.replace(' ', '_').replace('(', 'L').replace(')', 'R').replace('+', 'plus')
        lines.append(f'    Generator* g_{c_name} = create_generator("{name}", {arity}, {coarity});')
        lines.append(f'    alphabet_add(a, g_{c_name});')
        gen_map[name] = f'g_{c_name}'
    
    lines.append('    Grammar* g = create_grammar(a);')
    
    # Grammar Transitions
    for trans in data.get('grammar', []):
        if 'shift' in trans:
            # Shorthand for shift: state1 --(token)--> state2
            # Models as 1->1 generator
            name = trans['token']
            s1 = trans['shift'][0]
            s2 = trans['shift'][1]
            lines.append('    {')
            lines.append(f'        StateList* dom = create_statelist(); statelist_add(dom, "{s1}");')
            lines.append(f'        StateList* cod = create_statelist(); statelist_add(cod, "{s2}");')
            lines.append(f'        grammar_add_transition(g, {gen_map[name]}, dom, cod);')
            lines.append('    }')
        elif 'reduce' in trans:
            # Shorthand for reduce: [s1, s2, ...] --(nonterm)--> s_new
            # Models as n->1 generator
            name = trans['nonterm']
            states = trans['reduce']
            target = trans['target']
            lines.append('    {')
            lines.append(f'        StateList* dom = create_statelist();')
            for s in states:
                lines.append(f'        statelist_add(dom, "{s}");')
            lines.append(f'        StateList* cod = create_statelist(); statelist_add(cod, "{target}");')
            lines.append(f'        grammar_add_transition(g, {gen_map.get(name, "NULL")}, dom, cod);')
            lines.append('    }')
        gen_name = str(trans['generator'])
        # ... (rest of standard transition)
        dom = trans['dom']
        cod = trans['cod']
        lines.append('    {')
        lines.append('        StateList* dom = create_statelist();')
        for s in dom:
            lines.append(f'        statelist_add(dom, "{s}");')
        lines.append('        StateList* cod = create_statelist();')
        for s in cod:
            lines.append(f'        statelist_add(cod, "{s}");')
        lines.append(f'        grammar_add_transition(g, {gen_map[gen_name]}, dom, cod);')
        lines.append('    }')
    
    # Diagram
    def parse_diagram(diag):
        if isinstance(diag, (str, int)):
            s_diag = str(diag)
            if s_diag.startswith('id(') and s_diag.endswith(')'):
                n = int(s_diag[3:-1])
                return f'create_sd_id({n})'
            return f'create_sd_gen(alphabet_find(a, "{s_diag}"))'
        elif 'compose' in diag:
            left = parse_diagram(diag['compose'][0])
            right = parse_diagram(diag['compose'][1])
            return f'create_sd_comp({left}, {right})'
        elif 'product' in diag:
            left = parse_diagram(diag['product'][0])
            right = parse_diagram(diag['product'][1])
            return f'create_sd_prod({left}, {right})'
        return 'NULL'

    if 'diagram' in data:
        lines.append(f'    *out_sd = {parse_diagram(data["diagram"])};')
    else:
        lines.append('    *out_sd = NULL;')
        
    lines.append('    *out_alphabet = a;')
    lines.append('    return g;')
    lines.append('}')
    return '\n'.join(lines)

if __name__ == '__main__':
    with open(sys.argv[1], 'r') as f:
        data = yaml.safe_load(f)
    print(generate_c_code(data))
