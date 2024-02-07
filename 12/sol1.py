#!/usr/bin/env python

import sys, os, re
import numpy as np
from itertools import combinations


def parse(file):
    res = ( l.split() for l in file )
    res = [ (bytearray(conf, 'ascii'), [ int(c) for c in counts.split(',') ]) for conf, counts in res]
    return res

def solve_one(conf, counts):
    stk = [conf]
    res = 0
    while stk:
        conf = stk.pop()
        try:
            i = conf.index(b'?')
            conf[i] = ord('.')
            stk.append(conf[:])
            conf[i] = ord('#')
            stk.append(conf[:])
        except ValueError:
            cur_counts = [ len(s) for s in conf.split(b'.') if len(s) > 0 ]
            if cur_counts == counts:
                res += 1
    return res


def solve(data):
    return sum( solve_one(*entry) for entry in data )


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
