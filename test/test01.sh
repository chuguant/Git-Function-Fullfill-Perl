#!/bin/sh
# commit withou add the changed

legit.pl init
echo line 1 >a
legit.pl add a
legit.pl commit -m 'first commit'
echo line 2 >> a
legit.pl commit -m 'second commit'
lget.pl show :a
