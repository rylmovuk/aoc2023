#!/usr/bin/env python

import sys, re
from dataclasses import dataclass, astuple
from itertools import takewhile

class RangeMap:
    def __init__(self, dst_s, src_s, length):
        self.src = range(src_s, src_s+length)
        self.dst = range(dst_s, dst_s+length)
    def __len__(self): return len(self.src)
    def __getitem__(self, n):
        return self.dst[self.src.index(n)]
    def __contains__(self, n):
        return n in self.src
        

class Map:
    def __init__(self, ranges):
        self.ranges = list(ranges)
    def __getitem__(self, i):
        for r in self.ranges:
            if i in r:
                return r[i]
        return i

@dataclass(eq=False)
class Almanac:
    seeds: list[int]
    seed_soil:   Map
    soil_fert:   Map
    fert_water:  Map
    water_light: Map
    light_temp:  Map
    temp_humid:  Map
    humid_loc:   Map

def parse_map(lines) -> Map:
    return Map(ranges=(
        RangeMap(*map(int, line.split()))
        for line in lines
    ))

def parse_file(f) -> Almanac:
    seeds = re.match(r'seeds: ([\d ]+)', f.readline())
    seeds = [int(n) for n in seeds[1].split()]
    mapnames = [ 'seed-to-soil', 'soil-to-fertilizer', 'fertilizer-to-water', 'water-to-light', 'light-to-temperature', 'temperature-to-humidity', 'humidity-to-location' ]
    # skip empty
    assert f.readline().isspace()
    maps = []
    for mapname in mapnames:
        assert re.match(f'{mapname} map:', f.readline())
        maps.append(parse_map(takewhile(lambda line: not line.isspace(), f)))

    return Almanac(seeds, *maps)

def solve(alma):
    seeds, m1, m2, m3, m4, m5, m6, m7 = astuple(alma)
    locs = (
        m7[m6[m5[m4[m3[m2[m1[seed]]]]]]]
        for seed in seeds
    )
    return min(locs)    

def main():
    try:
        file = open(sys.argv[1])
    except IndexError:
        file = sys.stdin

    alma = parse_file(file)
    sol = solve(alma)
    print(f'Solution: {sol}')
    file.close()


if __name__ == "__main__":
    main()
