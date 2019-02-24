#!/bin/sh
# remove the file and show the log


legit.pl init
echo line 1 >a
legit.pl add a
legit.pl commit -m "first commit"
cp a b
legit.pl rm a
legit.pl add b 
legit.pl commit -m "second commit"
legit.pl log
