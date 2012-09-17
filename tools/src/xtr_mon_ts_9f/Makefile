INSTALLDIR = <MAKE_INSTALLDIR>
EXECUTABLE = <MAKE_EXECUTABLE>

CC = <MAKE_CC>
CFLAGS = <MAKE_CFLAGS>

RM = /bin/rm -f

OBJS = xtr_mon_ts.9f.c

default: $(EXECUTABLE)

all : $(EXECUTABLE) install clean

clean :
	$(RM) *.o core Makefile.make *log *~

vic2nc: $(OBJS)
	$(CC) $(CFLAGS) -o $(EXECUTABLE) $(OBJS)

# --------------------------------------------------------------------
# install
# --------------------------------------------------------------------
install:
	mv $(EXECUTABLE) $(INSTALLDIR)
