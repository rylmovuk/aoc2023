#!/usr/bin/env python

import sys, os
import re

def admissible(amounts, totals):
    return all(a <= t for a, t in zip(amounts, totals))

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
    good  = filter(lambda g: all(admissible(subs, totals) for subs in g[1]), games)
    return sum(int(g[0]) for g in good)

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    sol = solve(file)
    print(f'Solution: {sol}')


if __name__ == "__main__":
    main()
