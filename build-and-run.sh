#!/bin/sh
fpc -FEBIN/ SRC/*.PAS && \
(cd BIN && xterm -bg black -fg grey -geom 80x25 -e ./run.sh)
