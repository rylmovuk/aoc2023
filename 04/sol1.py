#!/usr/bin/env python

import sys, re

def extract_card(line):
    id, winning, own = re.match(r'Card\s+(\d+): ([\d\s]+) \| ([\d\s]+)', line).groups()
    winning, own = winning.split(), own.split()
    return (id, winning, own)

def worth(card):
    _, winning, own = card
    count = sum( (n in winning) for n in own )
    val = (1 << (count-1)) if count > 0 else 0
    return val


def solve(file):
    cards = ( extract_card(line) for line in file.readlines() )
    return sum(worth(card) for card in cards)

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    sol = solve(file)
    print(f'Solution: {sol}')


if __name__ == "__main__":
    main()
