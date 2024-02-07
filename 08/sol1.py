#!/usr/bin/env python

import sys, re
from math import floor, ceil
from itertools import cycle, count
from collections import Counter

def parse_file(f):
    instructions = f.readline().strip()
    f.readline()
    rg = re.compile(r'(\w+) = \((\w+), (\w+)\)')
    data = (rg.match(line) for line in f)
    data = ((m[1], m[2], m[3]) for m in data)
    nodes = { node: (left, right) for node, left, right in data }
    return instructions, nodes

def solve(instructions, nodes):
    cur = 'AAA'
    for n, instr in zip(count(1), cycle(instructions)):
        cur = nodes[cur][instr == 'R']
        if cur == 'ZZZ':
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
