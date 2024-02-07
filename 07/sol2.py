#!/usr/bin/env python

import sys, re
from math import floor, ceil
from itertools import count
from collections import Counter

def parse_file(f):
    t = ( l.split() for l in f )
    return ([ (hand, int(bid)) for hand, bid in t ], )

def hand_type(hand):
    c = Counter(hand)
    mc = c.most_common(3)
    jokers = c['J']
    fst = next( (count for card, count in mc if card != 'J'), 0)
    if fst + jokers == 5:
        return 5
    elif fst + jokers == 4:
        return 4
    snd = mc[1][1] if mc[0][0] != 'J' else mc[2][1]
    if fst + jokers == 3:
        if snd == 2:
            return 3.5
        else:
            return 3
    elif fst + jokers == 2:
        if snd == 2:
            return 2.5
        else:
            return 2
    else:
        return 1

def hand_val(hand):
    tr = str.maketrans('J23456789TQKA', '0123456789ABC')
    # what is a card, but a digit in base 13?
    return int(hand.translate(tr), 13)

def sort_key(t):
    hand, bid = t
    return (hand_type(hand), hand_val(hand))

def solve(data):
    data.sort(key=sort_key)
    bids = ( bid for _, bid in data )
    return sum(bid * rank for bid, rank in zip(bids, count(1)))
    

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
