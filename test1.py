#!/usr/bin/python
#logical operator : single line if, while : subset2 

a = 0
b = 1

if a and b: print "Line 1 - a and b are true";

if a or b: print "Line 2 - Either a is true or b is true or both are true"

if not a: print "Line 3 - Either a is not true or b is not true"

if not a and b: print "Line 4 - Either a is not true or b is not true"

while a == 0 and b > 0: a+=1; print "Line 5 - a and b are true";