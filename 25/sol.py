#!/usr/bin/env python3
from collections.abc import Iterable
import sys

type Data = dict[str, set[str]]

def parse(file: Iterable[str]) -> Data:
    data = { frm: set(to.split()) for frm, to in (line.split(': ') for line in file) }
    return data

def solve(data: Data) -> int:
    edges = ((fr, to) for fr, nbs in data.items() for to in nbs)

    to_remove = [ (u, v) for u, v in (l.split() for l in open('found-these-by-hand')) ]

    mod_edges = ( (fr, to) for fr, to in edges if (fr, to) not in to_remove and (to, fr) not in to_remove )

    nodes: dict[str, set[str]] = {}
    for fr, to in mod_edges:
        nodes.setdefault(fr, set()).add(to)
        nodes.setdefault(to, set()).add(fr)

    some_node = next(iter(nodes.keys()))
    seen: set[str] = set()
    stk = [some_node]
    while stk:
        n = stk.pop()
        seen.add(n)
        stk += [ u for u in nodes[n] if u not in seen ]
    
    cluster1 = len(seen)
    total = len(nodes)
    cluster2 = total - cluster1
    print(f'{total=} {cluster1=} {cluster2=}')
    return cluster1 * cluster2


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
