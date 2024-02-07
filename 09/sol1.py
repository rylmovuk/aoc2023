#!/usr/bin/env python

import sys, re
from itertools import pairwise

def parse_file(f):
    return [ list(map(int, l.split())) for l in f ]

def solve_one(seq):
    # do aitken neville??
    seq = seq[:]
    n = len(seq) - 1
    xhat = n + 1
    for m in range(1, n):
        for j in range(n - m + 1):
            seq[j] = ( (xhat - j) * seq[j+1] - (xhat - j - m) * seq[j] ) / m
    return int(seq[0])

def solve_naive(seq):
    rows = [seq]
    while True:
        input(f'{rows}')
        last = rows[-1]
        new = [ b - a for a, b in pairwise(last) ]
        print(new)
        if all(d == 0 for d in new):
            break
        rows.append(new)
    res = sum(row[-1] for row in rows)
    return res

def solve(readings):
    return sum(solve_one(seq) for seq in readings)

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    alma = parse_file(file)
    sol = solve(alma)
    print(f'Solution: {sol}')
    file.close()


if __name__ == "__main__":
    main()
