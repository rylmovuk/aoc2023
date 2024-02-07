#!/usr/bin/env python

import sys, os
import re
from functools import reduce
from operator import mul

def min_amounts(subsets):
    def max_each(t1, t2):
        return tuple(map(max, t1, t2))
    return reduce(max_each, subsets)

def power(vals):
    return reduce(mul, vals)

def extract_subset(subset):
    entries = subset.split(',')
    cols = { 'red': 0, 'green': 0, 'blue': 0 }
    for e in entries:
        val, col = e.strip().split()
        cols[col] += int(val)
    return tuple(cols.values())

def extract_game(line):
    m = re.match('Game (\d+): (.+)', line.strip())
    id, line = m[1], m[2]
    subsets = [ extract_subset(subs) for subs in line.split(';') ]
    return (id, subsets)


def solve(file):
    totals = (12, 13, 14)
    games = [ extract_game(line) for line in file.readlines() ]
    powers = ( power(min_amounts(sets)) for _, sets in games )
    ans = sum(powers)
    return ans

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    sol = solve(file)
    print(f'Solution: {sol}')


if __name__ == "__main__":
    main()
