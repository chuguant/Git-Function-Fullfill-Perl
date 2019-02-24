#!/bin/sh
# 

legit.pl init
touch a b c d e 
legit.pl add a b 
legit.pl commit -m 'first commit'
echo 'lazy' >a
echo 'dog' >b 
echo 'jumping'>c 
legit.pl add b c d 
rm e
legit.pl status