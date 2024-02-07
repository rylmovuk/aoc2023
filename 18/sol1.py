#!venv/bin/python

import sys, os, re
import numpy as np
from collections import namedtuple
from itertools import chain, takewhile
from functools import reduce, partial
from drawille import Canvas

class Dir:
    U, L, R, D = map(partial(np.array, dtype='u4'), ((0,-1), (-1, 0), (1, 0), (0, 1)))

def parse(file):
    rx = re.compile(r'([URDL]) (\d+) \(#(\w{6})\)')
    data = ( rx.match(line).groups() for line in file )
    data = [ (getattr(Dir, dir), int(amt), col) for dir, amt, col in data ]
    return data

def solve(data):
    # started at about 800x800 with origin in the middle
    # figured out a lower estimate experimentally
    grid = np.zeros((400, 400), dtype='u1')
    cur = np.array([10, 60], dtype='u4')
    maxc = cur.copy()
    minc = cur.copy()
    grid[*cur] = 1
    vmax, vmin = np.vectorize(max), np.vectorize(min)
    # trace outline
    for d, amt, _ in data:
        for _ in range(amt):
            cur += d
            grid[*cur] = 1
        maxc = vmax(maxc, cur)
        minc = vmin(minc, cur)

    print(f'{minc} {maxc}')
    
    # show outline
    xmin, ymin, xmax, ymax = *minc, *maxc
    print(f'{xmin, ymin, xmax, ymax}')
    canv = Canvas()
    for y in range(ymin, ymax+1):
        for x in range(xmin, xmax+1):
            if grid[x, y] == 1:
                canv.set(x, y)
    print(canv.frame())

    def diag_gen(x, y):
        while True:
            yield (x, y)
            x -= 1
            y += 1
    def in_bounds(p):
        x, y = p
        return xmin <= x <= xmax and ymin <= y <= ymax
    all_starts = chain(
            ( (x, ymin) for x in range(xmin, xmax+1) ),
            ( (xmax, y) for y in range(ymin, ymax+1) ),
    )
    all_diags = ( takewhile(in_bounds, diag_gen(*start)) for start in all_starts )

    # fill in
    for diag in all_diags:
        inside = False
        for x, y in diag:
            if grid[x, y] == 0 and inside:
                grid[x, y] = 2
            if grid[x, y] == 1 and not (
                    (grid[x-1, y] == grid[x, y-1] == 1)
                    ^ (grid[x+1, y] == grid[x, y+1] == 1)
                ):
                inside = not inside

    canv = Canvas()
    for y in range(ymin, ymax+1):
        for x in range(xmin, xmax+1):
            if grid[x, y]:
                canv.set(x, y)
    print(canv.frame())

    return np.count_nonzero(grid[xmin:xmax+1, ymin:ymax+1])

            


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
