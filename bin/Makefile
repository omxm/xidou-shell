# bin/ — small standalone helper tools for Xidou Shell, alongside the
# shell scripts (xidou) that don't need compiling.
CC = cc
CFLAGS = -std=c99 -pedantic -Wall -Os
LDFLAGS = -lX11

PREFIX = /usr/local

all: xidou-focus-window

xidou-focus-window: xidou-focus-window.c
	${CC} ${CFLAGS} -o $@ $< ${LDFLAGS}

install: all
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f xidou xidou-brightness xidou-focus-window ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/xidou
	chmod 755 ${DESTDIR}${PREFIX}/bin/xidou-brightness
	chmod 755 ${DESTDIR}${PREFIX}/bin/xidou-focus-window

clean:
	rm -f xidou-focus-window

.PHONY: all install clean
