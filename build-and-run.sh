#!/bin/sh
fpc -g -Mtp -FcUTF8 -FEBIN/ SRC/ZZT.PAS && \
(cd BIN && xterm -bg black -fg grey -geom 80x25 -e ./run.sh)
