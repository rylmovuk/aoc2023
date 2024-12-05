#!/usr/bin/env python

# pyright: basic 
import sys, os, re
import numpy as np
from collections import namedtuple
from itertools import takewhile

Instr = namedtuple('Instr', 'cond action')

def parse_instr(a1, a2=None):
    if a2 is None:
        return Instr('True', a1)
    return Instr(a1, a2)


def parse(file):
    rex = re.compile(r'([a-z]+)\{(.+)\}')
    rules = ( rex.match(line).groups() for line in takewhile(lambda s: not s.isspace(), file) )
    rules = ( 
             (name, [ parse_instr(*instr.split(':')) for instr in instrs.split(',')])
             for name, instrs in rules
    )
    rules = dict(rules)
    parts = [ s.removeprefix('{').removesuffix('}\n').replace(',', ';') for s in file ]
    
    return (rules, parts)

vars_dict = dict()

def accepted(rules, part):
    exec(part, vars_dict)
    rule_name = 'in'
    while rule_name not in ('A', 'R'):
        rule = rules[rule_name]
        for cond, action in rule:
            if eval(cond, vars_dict):
                rule_name = action
                break
    return rule_name == 'A'

def vals(part):
    exec(part, vars_dict)
    return eval('(x, m, a, s)', vars_dict)

def solve(data):
    rules, parts = data
    good = ( part for part in parts if accepted(rules, part) )
    totals = ( sum(vals(part)) for part in good )
    return sum(totals)


def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    data = parse(file)
    sol = solve(data)
    print(f'Solution: {sol}')


if __name__ == "__main__":
    main()
