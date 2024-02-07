#!/usr/bin/env python

import sys, os, re
import numpy as np
from collections import namedtuple
from itertools import takewhile
from dataclasses import dataclass, field

Low, High = False, True
class Node:
    pass

@dataclass
class Node:
    name: str
    outputs: list[Node] 
    inputs_queue: list[tuple[Node, bool]] = field(default_factory=list)
    low_sent: int = 0
    high_sent: int = 0

    def process(self):
        to_send = ( self.process_one(*inp) for inp in self.inputs_queue )
        to_send = [ pulse for pulse in to_send if pulse is not None ]
        self.inputs_queue.clear()
        if to_send:
            for pulse in to_send:
                self.send_pulse(pulse)
            for out in self.outputs:
                out.process()
    
    def process_one(self, node, inp) -> bool | None:
        pass

    def send_pulse(self, pulse):
        for out in self.outputs:
            out.inputs_queue.append( (self, pulse) )
            print(f'{self.name} --{("lo","hi")[pulse]}-> {out.name}', file=sys.stderr)
            if pulse is High:
                self.high_sent += 1
            else:
                self.low_sent  += 1

@dataclass
class FlipNode(Node):
    state: bool = Low

    def process_one(self, node, inp):
        if inp is High:
            return
        self.state = not self.state
        return self.state

            
@dataclass
class ConjNode(Node):
    inputs_mem: dict[str, bool] = field(default_factory=dict)

    def process_one(self, node, inp):
        self.inputs_mem[node.name] = inp
        return not all(self.inputs_mem.values())

class BroadcastNode(Node):
    def process_one(self, node, inp):
        return inp


class Network:
    nodes: dict[str, Node]
    btn_node: Node

    def _first_create(name, kind):
        if name == 'broadcaster':
            N = BroadcastNode
        elif kind == '%':
            N = FlipNode
        elif kind == '&':
            N = ConjNode
        else:
            N = Node
        return N(name, outputs=[])

    def __init__(self, node_info):
        node_info = list(node_info)
        self.nodes = { 
            name: Network._first_create(name, kind) for name, kind, _ in node_info
        }
        for name, _, outputs in node_info:
            for outname in outputs:
                self.nodes[name].outputs.append(
                        self.nodes.setdefault(outname, Node(outname, []))
                )

        for node in self.nodes.values():
            for out in node.outputs:
                if isinstance(out, ConjNode):
                    out.inputs_mem[node.name] = Low
        self.btn_node = BroadcastNode('<button>', [self.nodes['broadcaster']])

    @property
    def total_low(self):
        return self.btn_node.low_sent + sum(node.low_sent for node in self.nodes.values())
    @property
    def total_high(self):
        return self.btn_node.high_sent + sum(node.high_sent for node in self.nodes.values())

    def button(self):
        self.btn_node.inputs_queue.append ( (None, Low) )
        self.btn_node.process()

rex = re.compile(r'([%&]?)([A-Za-z]+) -> ([A-Za-z, ]+)')
def parse_one(s):
    kind, name, outputs = rex.match(s).groups()
    outputs = outputs.split(', ')
    return (name, kind, outputs)
    

def parse(file):
    nodes = ( parse_one(line) for line in file )
    net = Network(nodes)
    return net
    
    


def solve(net):
    for _ in range(1000):
        net.button()
    print(net.total_low, net.total_high)
    return net.total_low * net.total_high


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
