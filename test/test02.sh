#!/bin/sh
# adding the file to index wihout init

echo line 1 >a
legit.pl add a
legit.pl commit -m 'first commit'