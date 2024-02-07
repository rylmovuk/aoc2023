#!/usr/bin/env python

import sys, os, re
import numpy as np

class Tile:
    EMPTY = 0
    WALL = 1
    ROCK = 2
    def from_char(c):
        return '.#O'.index(c)
    def to_char(t):
        return '.#O'[t]

def parse(file):
    data = file.read().splitlines()
    grid = np.empty( (len(data), len(data[0])), dtype='u1' )
    for y, row in enumerate(data):
        for x, c in enumerate(row):
            grid[y, x] = Tile.from_char(c)
    return grid

def print_grid(grid):
    print( *(''.join(Tile.to_char(c) for c in row) for row in grid), sep='\n' )

def slide_west(grid):
    h, w = grid.shape
    for row in grid:
        for y in range(w):
            if row[y] == Tile.ROCK:
                row[y] = Tile.EMPTY
                i = y
                while i > 0 and row[i-1] == Tile.EMPTY:
                    i -= 1
                row[i] = Tile.ROCK

def slide_north(grid): slide_west(grid.T)
def slide_east(grid):  slide_west(grid[:, ::-1])
def slide_south(grid): slide_west(grid[::-1].T)

def cycle(grid):
    slide_north(grid)
    slide_west(grid)
    slide_south(grid)
    slide_east(grid)

def repl(grid):
    while True:
        print_grid(grid)
        d = input('where?: ')
        match d:
            case 'u':
                slide_north(grid)
            case 'd':
                slide_south(grid)
            case 'l':
                slide_west(grid)
            case 'r':
                slide_east(grid)


def solve(grid):
    h, w = grid.shape

    for i in range(1_000_000_000):
        if i > 8 and (i & (i-1)) == 0:
            print(f'processing {i} ({i/10_000_000:3f}%)...')
        # old = np.copy(grid)
        cycle(grid)
        #if np.all(old == grid):
        #    print(f'all the same at {i}')
        #    break
    
    print_grid(grid)

    mask = grid.T == Tile.ROCK
    return np.sum( mask * np.arange(h, 0, -1) )
    

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    grid = parse(file)
    print(grid.shape)
    repl(grid)


if __name__ == "__main__":
    main()
