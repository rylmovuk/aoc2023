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

def move_north(grid):
    h, w = grid.shape
    for col in grid.T:
        for y in range(h):
            if col[y] == Tile.ROCK:
                col[y] = Tile.EMPTY
                i = y
                while i > 0 and col[i-1] == Tile.EMPTY:
                    i -= 1
                col[i] = Tile.ROCK


def solve(grid):
    h, w = grid.shape
    move_north(grid)
    
    print_grid(grid)

    mask = grid.T == Tile.ROCK
    return np.sum( mask * np.arange(h, 0, -1) )
    

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
