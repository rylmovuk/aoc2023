#!/usr/bin/env python

import sys, re
from dataclasses import dataclass, astuple
from itertools import takewhile, islice

class RangeMap:
    def __init__(self, dst_s=None, src_s=None, length=None, *, delta=None, srcrange=None):
        if not (
                (delta is None and srcrange is None)
                ^ (dst_s is None and src_s is None and length is None)):
            raise TypeError('only calling with either (dst, src, len) or (delta, range) supported')
        if delta is None:
            self.src = range(src_s, src_s+length)
            self.delta = dst_s - src_s
        else:
            self.src = srcrange
            self.delta = delta

    def __len__(self):          return len(self.src)
    def __getitem__(self, n):   return self.delta + n
    def __contains__(self, n):  return n in self.src
    def restrict(self, r: range):
        start = max(self.src.start, r.start)
        stop  = min(self.src.stop,  r.stop)
        return RangeMap(delta=self.delta, srcrange=range(start, stop))
    def image(self) -> range:
        return range(self.src.start + self.delta, self.src.stop + self.delta)



class Map:
    def __init__(self, ranges):
        self.ranges = list(ranges)
    def __getitem__(self, i):
        if isinstance(i, int):
            for r in self.ranges:
                if i in r:
                    return r[i]
            return i
        elif isinstance(i, range):
            restriction = ( ran.restrict(i) for ran in self.ranges )
            return [ran.image() for ran in restriction if len(ran) > 0]

@dataclass(eq=False)
class Almanac:
    seeds: list[range]
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
    seeds = ( int(n) for n in seeds[1].split() )
    seeds = [range(n, n+l) for n, l in zip(*[iter(seeds)]*2)]
    mapnames = [ 'seed-to-soil', 'soil-to-fertilizer', 'fertilizer-to-water', 'water-to-light', 'light-to-temperature', 'temperature-to-humidity', 'humidity-to-location' ]
    # skip empty
    assert f.readline().isspace()
    maps = []
    for mapname in mapnames:
        assert re.match(f'{mapname} map:', f.readline())
        maps.append(parse_map(takewhile(lambda line: not line.isspace(), f)))

    return Almanac(seeds, *maps)

def solve(alma):
    seeds, *maps = astuple(alma)
    cur_ranges = set(seeds)
    for m in maps:
        new_ranges = set()
        for ran in cur_ranges:
            new_ranges.update(m[ran])
        cur_ranges = new_ranges

    return min(ran.start for ran in cur_ranges)    

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
