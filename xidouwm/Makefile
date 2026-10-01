# xidouwm - dynamic window manager (derived from suckless dwm)
# See LICENSE file for copyright and license details.

include config.mk

SRC = drw.c dwm.c util.c
OBJ = ${SRC:.c=.o}

all: options xidouwm xidouwm-msg

options:
	@echo xidouwm build options:
	@echo "CFLAGS   = ${CFLAGS}"
	@echo "LDFLAGS  = ${LDFLAGS}"
	@echo "CC       = ${CC}"

.c.o:
	${CC} -c ${CFLAGS} $<

${OBJ}: config.h config.mk

dwm.o dwm-msg.o: sockpath.h

config.h:
	cp config.def.h $@

xidouwm: ${OBJ}
	${CC} -o $@ ${OBJ} ${LDFLAGS}

xidouwm-msg: dwm-msg.o
	${CC} -o $@ $< ${LDFLAGS}

clean:
	rm -f xidouwm xidouwm-msg ${OBJ} xidouwm-${VERSION}.tar.gz

dist: clean
	mkdir -p xidouwm-${VERSION}
	cp -R LICENSE Makefile README config.def.h config.mk\
		xidouwm.1 drw.h util.h sockpath.h ${SRC} dwm.png transient.c xidouwm-${VERSION}
	tar -cf xidouwm-${VERSION}.tar xidouwm-${VERSION}
	gzip xidouwm-${VERSION}.tar
	rm -rf xidouwm-${VERSION}

install: all
	mkdir -p ${DESTDIR}${PREFIX}/bin
	cp -f xidouwm xidouwm-msg ${DESTDIR}${PREFIX}/bin
	chmod 755 ${DESTDIR}${PREFIX}/bin/xidouwm
	chmod 755 ${DESTDIR}${PREFIX}/bin/xidouwm-msg
	mkdir -p ${DESTDIR}${MANPREFIX}/man1
	sed "s/VERSION/${VERSION}/g" < xidouwm.1 > ${DESTDIR}${MANPREFIX}/man1/xidouwm.1
	chmod 644 ${DESTDIR}${MANPREFIX}/man1/xidouwm.1

uninstall:
	rm -f ${DESTDIR}${PREFIX}/bin/xidouwm\
		${DESTDIR}${MANPREFIX}/man1/xidouwm.1

.PHONY: all clean dist install uninstall
