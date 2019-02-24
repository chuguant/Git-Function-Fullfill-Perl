#!/bin/sh
# adding multiple files to index and commit

legit.pl init
touch a b c d e
legit.pl add *
legit.pl commit -m "initial commit"
