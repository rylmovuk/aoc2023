#!/usr/bin/env python

import sys, re

def extract_card(line):
    id, winning, own = re.match(r'Card\s+(\d+): ([\d\s]+) \| ([\d\s]+)', line).groups()
    winning, own = winning.split(), own.split()
    return (id, winning, own)

def matches_count(winning, own):
    count = sum( (n in winning) for n in own )
    return count

def solve(file):
    cards = ( extract_card(line) for line in file.readlines() )
    cards = { int(id): (winning, own, 1) for id, winning, own in cards }
    for id in cards.keys():
        winning, own, copies = cards[id]
        matches = matches_count(winning, own)
        for d in range(1, matches+1):
            w, o, k = cards[id+d]
            cards[id+d] = w, o, k+copies

    return sum(copies for _, _, copies in cards.values())

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    sol = solve(file)
    print(f'Solution: {sol}')


if __name__ == "__main__":
    main()
