#!/usr/bin/env python

import sys, os, re
from collections import namedtuple
from itertools import chain, starmap

def parse(file):
    return Grid(file.read().splitlines())

def solve(grid):
    start = grid.index('S')
    positions = [ (delta, start+delta) for delta in (Dir.U, Dir.L, Dir.R, Dir.D) ]
    positions = [ (d, p) for d, p in positions if -d in Dir.dirmap[grid[*p]] ]
    # assert there's exactly two of them
    mask = Grid([ [0]*grid.w for _ in range(grid.h) ])
    a, b = positions
    da, pa = a
    db, pb = b
    mask[*start] = mask[*pa] = mask[*pb] = 1
    while pa != pb:
        da = follow_pipe(grid[*pa], da)
        pa += da
        db = follow_pipe(grid[*pb], db)
        pb += db
        mask[*pa] = mask[*pb] = 1
    n = 0
    for y in range(grid.h):
        inside_top, inside_bot = False, False
        for x in range(grid.w):
            if mask[x, y] == 1:
                if grid[x, y] in ('L', '|', 'J'):
                    inside_top = not inside_top
                if grid[x, y] in ('F', '|', '7'):
                    inside_bot = not inside_bot
            if mask[x, y] == 0 and inside_top and inside_bot:
                n += 1
                mask[x, y] = 2
    # pretty_print_grid(grid, mask, compact=False)
    return n

def pretty_print_grid(grid, mask, compact=False):
    escseq = {0: '\x1b[0m', 1: '\x1b[31m', 2: '\x1b[32m'}
    charset = '·─│┌┐└┘S' if compact else ['··', '──',  ' │', ' ┌', '─┐', ' └', '─┘', ' S']
    trtbl  = dict(zip('.-|F7LJS', charset))
    curcol = 0
    for y in range(grid.h):
        for x in range(grid.w):
            if mask[x, y] != curcol:
                curcol = mask[x, y]
                print(escseq[curcol], end='')
            print(trtbl[grid[x, y]], end='')
        print()
    print(escseq[0], end='')



class Coords(namedtuple('Coords', 'x y')):
    def __add__(self, other):
        return Coords(self.x + other.x, self.y + other.y)
    def __neg__(self):
        return Coords(-self.x, -self.y)
    def __sub__(self, other):
        return self + -other

class Dir:
    U, L, R, D = starmap(Coords, ((0,-1), (-1, 0), (1, 0), (0, 1)))
    dirmap = {
        '|': (U, D),
        '-': (L, R),
        'L': (U, R),
        'J': (U, L),
        '7': (D, L),
        'F': (D, R),
    }

def follow_pipe(pipe, arrival_dir):
    blocked = -arrival_dir
    a, b = Dir.dirmap[pipe]
    return a if b == blocked else b if a == blocked else None


class Grid:
    def __init__(self, data):
        self.rows = data
        self.w = len(data[0])
        self.h = len(data)
    def __getitem__(self, index: Coords):
        x, y = index
        return self.rows[y][x]
    def __setitem__(self, index: Coords, it):
        x, y = index
        self.rows[y][x] = it
    def in_bounds(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h
    def neighbors(self, x, y, w, h):
        return ( self[x, y] for x, y in surroundings(x, y, w, h) if self.in_bounds(x, y) )
    def index(self, cell) -> Coords:
        coord_iter = ( (x,y) for y in range(self.h) for x in range(self.w) )
        return next(Coords(x,y) for x, y in coord_iter if self[x, y] == cell)



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
