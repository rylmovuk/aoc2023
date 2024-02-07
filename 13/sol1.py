#!/usr/bin/env python

import sys, os, re
import numpy as np
from itertools import takewhile, count


def parse(file):
    groups = file.read().split('\n\n')
    return [ np.array( [[c for c in line] for line in group.splitlines() ]) for group in groups ]

def refl_indices(start, size):
    return takewhile(
            lambda p: all(0 <= n < size for n in p),
            ( (start - 1 - i, start + i) for i in count() )
    )

def solve_one(grid):
    h, w = grid.shape
    # find vert
    for i in range(1, w):
        for a, b in refl_indices(i, w):
            if not all(grid[:, a] == grid[:, b]):
                break
        else:
            return i
    # find hori
    for i in range(1, h):
        for a, b in refl_indices(i, h):
            if not all(grid[a] == grid[b]):
                break
        else:
            return 100*i
    

def solve(grids):
    return sum(solve_one(grid) for grid in grids)

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    grid = parse(file)
    sol = solve(grid)
    print(f'Solution: {sol}')


if __name__ == "__main__":
    main()
