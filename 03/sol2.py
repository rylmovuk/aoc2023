#!/usr/bin/env python

import sys, os, re
from itertools import chain


def surroundings(x, y, w, h):
    yield from (
        (nx, y-1)
        for nx in range(x-1, x+w+1)
    )
    for ny in range(y, y+h):
        yield (x-1, ny)
        yield (x+w, ny)
    yield from (
        (nx, y+h)
        for nx in range(x-1, x+w+1)
    )

def solve(file):
    data = file.read().splitlines()
    grid = Grid(data)
    regex = re.compile('\d+')
    # iter of (x: int, y: int, w: int) 
    all_numbers_pos = chain.from_iterable(
            ( (m.start(), y, m.end()-m.start()) for m in regex.finditer(row) )
            for y, row in enumerate(grid.rows)
    )
    asterisks = {}
    for x, y, w in all_numbers_pos:
        for ax, ay in surroundings(x, y, w, 1):
            if grid.in_bounds(ax, ay) and grid[ax, ay] == '*':
                asterisks.setdefault((ax, ay), []).append(int(grid[x:x+w, y]))
    gears = (
            vals for vals in asterisks.values() if len(vals) == 2
    )
    ratios = ( a * b for a, b in gears )
    return sum(ratios)


class Grid:
    def __init__(self, data):
        self.rows = data
        self.w = len(data[0])
        self.h = len(data)
    def __getitem__(self, index):
        x, y = index
        return self.rows[y][x]
    def in_bounds(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h
    def neighbors(self, x, y, w, h):
        return ( self[x, y] for x, y in surroundings(x, y, w, h) if self.in_bounds(x, y) )

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    sol = solve(file)
    print(f'Solution: {sol}')


if __name__ == "__main__":
    main()
