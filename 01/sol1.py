#!/usr/bin/env python

import sys, os

def extract_number(line):
    first = next(filter(str.isdigit, line))
    last  = next(filter(str.isdigit, reversed(line)))
    return int(first + last)

def solve(file):
    numbers = [ extract_number(l) for l in file.readlines() ]
    return sum(numbers)

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    sol = solve(file)
    print(f'Solution: {sol}')


if __name__ == "__main__":
    main()
