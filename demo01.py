#!/usr/bin/python

import sys
lines = [1,2,3,4,5]
lines.pop()
print lines[0]

lines.pop(2)
print lines[2]

index = lines.index(4);
print index