#!venv/bin/python

import sys, os, re
import numpy as np
from collections import namedtuple
from itertools import islice, cycle
from functools import reduce, partial
from drawille import Canvas

class Dir:
    U, L, R, D = map(partial(np.array, dtype='i8'), ((0,-1), (-1, 0), (1, 0), (0, 1)))

def parse(file):
    rx = re.compile(r'([URDL]) (\d+) \(#(\w{6})\)')
    data = ( rx.match(line).group(3) for line in file )
    dirs = [ Dir.R, Dir.D, Dir.L, Dir.U ]
    data = [ (dirs[int(s[5])], int(s[:5], 16)) for s in data ]
    return data

def solve(data):
    origin = np.zeros(2, dtype='i8')
    vertices = [origin]
    for d, amt in data:
        vertices.append(vertices[-1] + d*amt)
    assert (vertices[0] == vertices[-1]).all()
    del vertices[-1]
    peri = sum(amt for _, amt in data)

    area = 0
    for cur, nxt in zip(vertices, islice(cycle(vertices), 1, None)):
        area += cur[0] * nxt[1] - cur[1] * nxt[0]
    area = abs(area) // 2
    return area + peri // 2 + 1


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
