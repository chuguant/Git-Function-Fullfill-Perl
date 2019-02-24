#!/bin/sh
# 

legit.pl init
touch a  
echo "hello world" > a

legit.pl add a  

legit.pl commit -m "initial"
legit.pl branch sp
legit.pl branch id
legit.pl checkout sp
echo "ola el mundo" > a
legit.pl add a
legit.pl commit -m "spannish"

legit.pl checkout id
echo "halo dunia" > a
legit.pl add ba
legit.pl commit -m "indonesia"
legit.pl checkout master
cat a
