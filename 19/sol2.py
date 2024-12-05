#!/usr/bin/env python

# pyright: basic 
from math import prod
import sys, os, re
import numpy as np
from collections import namedtuple
from itertools import takewhile

Instr = namedtuple('Instr', 'action axis dir val', defaults=[None, None, None])

Interval = namedtuple('Interval', 'x m a s', defaults=([(1, 4001)] * 4))

def interval_bad(intv: Interval) -> bool:
    return any(l >= r for l, r in intv)

def interval_size(intv: Interval) -> int:
    return prod(r - l for l, r in intv)

def interval_split(intv: Interval, axis: str, at_val: int) -> tuple[Interval, Interval]:
    l, r = getattr(intv, axis)
    return intv._replace(**{axis: (l, at_val)}), intv._replace(**{axis: (at_val, r)})


def count_accepted(rules):
    def rec(rule_name, intv, instr_i):
        if interval_bad(intv) or rule_name == 'R':
            return 0
        if rule_name == 'A':
            return interval_size(intv)

        try:
            instr = rules[rule_name][instr_i]
        except IndexError:
            return 0

        next_rule, axis, dir, val = instr
        if not axis:
            return rec(next_rule, intv, 0)
        if dir == '>':
            val += 1
        below, above = interval_split(intv, axis, val)
        if dir == '>':
            return rec(next_rule, above, 0) + rec(rule_name, below, instr_i + 1)
        else:
            return rec(next_rule, below, 0) + rec(rule_name, above, instr_i + 1)

    return rec('in', Interval(), 0)




def parse_instr(a1, a2=None):
    if a2 is None:
        return Instr(a1)
    axis, dir, val = re.match(r'([xmas])([<>])([0-9]+)', a1).groups()
    val = int(val)
    return Instr(a2, axis, dir, val)


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

def solve(data):
    rules, _parts = data
    return count_accepted(rules)


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
