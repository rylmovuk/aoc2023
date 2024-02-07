#!/usr/bin/env python

import sys, re
from itertools import cycle, count
from sympy.ntheory.modular import crt

def parse_file(f):
    instructions = f.readline().strip()
    f.readline()
    rg = re.compile(r'(\w+) = \((\w+), (\w+)\)')
    data = (rg.match(line) for line in f)
    data = ((m[1], m[2], m[3]) for m in data)
    nodes = { node: (left, right) for node, left, right in data }
    return instructions, nodes

def find_cycle(insts, nodes, start_node, start_i=0):
    seen = { (start_node, start_i % len(insts)) }
    for u, n in follow(insts, nodes, start_node, start_i):
        i = n % len(insts)
        if (u, i) in seen:
            return (u, i, n)
        seen.add((u, i))

def follow(insts, nodes, cur, start_i=0):
    for n in count(start_i):
        i = n % len(insts)
        cur = nodes[cur][insts[i] == 'R']
        yield cur, n
        

def solve(instructions, nodes):
    cur = [ n for n in nodes.keys() if n[-1] == 'A' ]
    zs  = [ 
            next((v, n) for v, n in follow(instructions, nodes, u) if v[-1] == 'Z')
            for u in cur
    ]
    print(zs)
    cycles = [ find_cycle(instructions, nodes, v, n) for v, n in zs ]
    print(cycles)
    m = [ e - s for s, e in zip((s for _, s in zs), (e for _,_,e in cycles)) ]
    print(m)
    v = [ s % m for (_, s), m in zip(zs, m) ]
    return crt(m, v)

    for n, instr in zip(count(1), cycle(instructions)):
        cur = [ nodes[n][instr == 'R'] for n in cur ]
        if any(n[-1] == 'Z' for n in cur):
            print(f'{n=} {cur=}')
            input()
        if all(n[-1] == 'Z' for n in cur):
            return n
    
def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    data = parse_file(file)
    sol = solve(*data)
    print(f'Solution: {sol}')
    file.close()


if __name__ == "__main__":
    main()
