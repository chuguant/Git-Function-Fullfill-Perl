#!/bin/sh
# creating new branch, checkout and submit change

legit.pl init
touch a b c
echo "hello world" > a
legit.pl add a b c

legit.pl commit -m "initial"
legit.pl branch a1
legit.pl checkout a1
legit.pl branch
echo "halo dunia" > b
legit.pl commit -a -m "second"
legit.pl checkout master
legit.pl show :b