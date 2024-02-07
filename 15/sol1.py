#!/usr/bin/env python

import sys, os, re
from functools import reduce



def parse(file):
    return file.read().strip().split(',')

def hash(s):
    s = bytes(s, 'ascii')
    return reduce(lambda acc, b: ((acc + b) * 17) & 0xff, s, 0)

def solve(data):
    return sum( hash(s) for s in data )


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
