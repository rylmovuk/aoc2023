#!/usr/bin/env python

import sys, os, re
import numpy as np
from itertools import combinations


def parse(file):
    return np.array( [[1 if c == '#' else 0 for c in line] for line in file.read().splitlines()])

def solve(grid):
    coords = ( (x,y) for x in range(grid.shape[1]) for y in range(grid.shape[0]) )
    galaxies = ( (x, y) for x, y in coords if grid[y, x] == 1 )

    def adjust(x, y):
        for i in range(y):
            if np.all(grid[i] == 0):
                y += 999_999
        for j in range(x):
            if np.all(grid[:, j] == 0):
                x += 999_999
        return x, y
    galaxies = [ adjust(*g) for g in galaxies ]

    def dist(a, b):
        xa, ya, xb, yb = *a, *b
        return abs(yb - ya) + abs(xb - xa)
    # naive method
    print(galaxies)
    res = sum( dist(a, b) for a, b in combinations(galaxies, 2) )
    return res


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
