#!/usr/bin/env python

# pyright: basic

import sys, os, re
import numpy as np
from itertools import combinations


def parse(file):
    res = ( l.split() for l in file )
    res = [ (conf, [ int(c) for c in counts.split(',') ]) for conf, counts in res]
    return res

def solve_one(conf, counts) -> int:

    def rec(i, counts) -> int:
        if i == len(conf):
            return (len(counts) == 0 or counts == [0])
        match conf[i]:
            case '.':
                if counts and counts[0] == 0:
                    counts = counts[1:]
                return rec(i+1, counts)
            case '#':
                if not counts or counts[0] < 1:
                    return 0
                counts = counts[:]
                counts[0] -= 1
                return rec(i+1, counts)
            case '?':
                if counts and counts[0] == 0:
                    counts = counts[1:]
                res = rec(i+1, counts)
                if counts and counts[0] >= 1:
                    counts = counts[:]
                    counts[0] -= 1
                    res += rec(i+1, counts)
                return res
        raise Exception('bad input')

    return rec(0, counts)


def solve(data):
    unfolded = ( ("?".join([conf] * 5), counts * 5) for conf, counts in data )
    return sum( print(i) or solve_one(*entry) for i, entry in enumerate(unfolded) )


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
