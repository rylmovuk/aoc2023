#!/usr/bin/env python

import sys, os
from itertools import takewhile


words = [ "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" ]

def extract_number(line):
    first_dig_i = next(filter(lambda i: line[i].isdigit(), range(len(line))), len(line))
    last_dig_i  = next(filter(lambda i: line[i].isdigit(), range(len(line)-1, -1, -1)), -1)
    left_words  = (
        (i, wordval)
        for wordval, word in enumerate(words)
        if (i := line.find(word, 0, first_dig_i)) != -1
    )
    right_words  = (
        (i, wordval)
        for wordval, word in enumerate(words)
        if (i := line.rfind(word, last_dig_i+1)) != -1
    )
    left_words, right_words = map(list, (left_words, right_words))
    try:
        _, first = min(left_words, key=lambda p: p[0])
    except ValueError:
        first = line[first_dig_i]
    try:
        _, last  = max(right_words, key=lambda p: p[0])
    except ValueError:
        last = line[last_dig_i]
    return int(str(first) + str(last))

# def extract_number(line):
#     import re
#     regex = re.compile(f'(?=({"|".join(words)}|[0-9]))')
#     matches = regex.findall(line)
#     wordvals = { word: str(val) for val, word in enumerate(words) }
#     first = wordvals.get(matches[0], matches[0])
#     last  = wordvals.get(matches[-1], matches[-1])
#     ans = int(first + last)
#     return ans


def solve(file):
    numbers = [ extract_number(l.strip()) for l in file.readlines() ]
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
