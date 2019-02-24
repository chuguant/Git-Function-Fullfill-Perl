#!/bin/sh
# check rm not removing current work 

legit.pl init
seq 1 7 >7.txt
legit.pl add 7.txt
legit.pl commit -m commit-1
echo 8 >>7.txt
legit.pl add 7.txt
legit.pl commit -m commit-2
echo 9 >>7.txt
legit.pl rm 7.txt
legit.pl rm --cached 7.txt
legit.pl commit -m commit-3
legit.pl rm --cached 7.txt
legit.pl add 7.txt
legit.pl commit -m commit-4
legit.pl rm --cached 7.txt