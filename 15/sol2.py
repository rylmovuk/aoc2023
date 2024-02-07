#!/usr/bin/env python

import sys, os, re
from functools import reduce
from itertools import count



def parse(file):
    return file.read().strip().split(',')

def hash_x(s):
    s = bytes(s, 'ascii')
    return reduce(lambda acc, b: ((acc + b) * 17) & 0xff, s, 0)

def solve(data):
    boxes = [ dict() for _ in range(256) ]
    for instr in data:
        m = re.match('(\w+)([-=])(\d?)', instr)
        label, op, digit = m.group(1, 2, 3)
        box_id = hash_x(label)
        box = boxes[box_id]
        if op == '-':
            box.pop(label, None)
        elif op == '=':
            box[label] = int(digit)

    

    return sum(
            box_nr * slot_nr * val
            for box_nr, box in zip(count(1), boxes)
            for slot_nr, val in zip(count(1), box.values())
    )


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
