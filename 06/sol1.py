#!/usr/bin/env python

import sys, re
from math import floor, ceil
from operator import mul
from functools import reduce

def parse_file(f):
    times = re.match(r'Time:\s+(.+)', f.readline())
    distances = re.match(r'Distance:\s+(.+)', f.readline())
    times = map(int, times[1].split())
    distances = map(int, distances[1].split())
    return list(times), list(distances)

def solve(times, distances):
    # T: available time
    # t: time pressing the button
    # dist = t * (T - t)
    # -> basically we are asked to intersect a horiz.line w/ a parabola
    # - t**2 + T*t - dist = 0
    # delta = T**2 - 4*dist
    # L = -b/2 - sqrt(delta)/2      R = -b/2 + sqrt(delta)/2
    # the length of the line is R-L --> sqrt(delta)
    ranges = ( get_range(T, d) for T, d in zip(times, distances) )
    return reduce(mul, ranges)

def get_range(T, d):
    delta = T**2 - 4*d
    # x of vertex
    vx = T/2
    # distance to roots
    rad = delta**0.5/2
    # roots
    l, r = vx - rad, vx + rad
    # we want the integers strictly between l and r
    l = floor(l + 1)
    r = ceil(r - 1)
    return r - l + 1

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    data = parse_file(file)
    sol = solve(*data)
    print(f'Solution: {sol}')
    file.close()


if __name__ == "__main__":
    main()
