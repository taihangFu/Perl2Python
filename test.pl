#!/usr/bin/perl -w

# import sys
# print sys.argv[2:4]

$list_str = "1,2,3,4,5";
@list2 = split /,/ , $list_str;

print $list2[0], "\n";
