#!/bin/sh
# creating new branch

legit.pl init
touch a b c
legit.pl add a b c
legit.pl commit -m "initial"
legit.pl branch
legit.pl branch a1
legit.pl branch