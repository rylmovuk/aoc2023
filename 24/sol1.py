#!/usr/bin/env python

import sys, os, re
import numpy as np
import itertools as itt

def parse(file):
    data = [ re.match(r'(-?\d+), (-?\d+), (-?\d+) @ (-?\d+), (-?\d+), (-?\d+)', line).groups() for line in file ]
    data = [ list(map(int, row)) for row in data ]
    return data

lim = (200_000_000_000_000, 400_000_000_000_000 + 1)


def solve(data):
    count = 0
    i = 0
    tot = len(data) * (len(data) - 1) // 2
    for A, B in itt.combinations(data, 2):
        print(f'\r{i} / {tot} ....', end='', flush=True)
        xA, yA, _, vxA, vyA, _ = A
        xB, yB, _, vxB, vyB, _ = B
        try:
            tA, tB = np.linalg.solve([[vxA, -vxB], [vyA, -vyB]], [xB - xA, yB - yA])
        except np.linalg.LinAlgError:
            continue
        xi = xA + tA * vxA
        yi = yA + tA * vyA
        if tA >= 0 and tB >= 0 and lim[0] <= xi <= lim[1] and lim[0] <= yi <= lim[1]:
            count += 1
        i += 1
    print()
    return count



def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    data = parse(file)
    sol = solve(data)
    print(f'Solution: {sol}')

if __name__ == '__main__':
    main()
