# Set INSTALLDIR
INSTALLDIR = <MAKE_INSTALLDIR>

# Set EXECUTABLE
EXECUTABLE = <MAKE_EXECUTABLE>

CFLAGS = <MAKE_CFLAGS>

CC = <MAKE_CC>
RM = /bin/rm -f
LIBRARY = <MAKE_LIBS>
OBJS = tools.c fcst_sflow.c

default: $(EXECUTABLE)

all: $(EXECUTABLE) install

clean :
	$(RM) *.o core log *~

nc2vic: $(OBJS)
	$(CC) $(CFLAGS) -o $(EXECUTABLE) $(OBJS) $(LIBRARY) $(HDRS)

# --------------------------------------------------------------------
# install
# --------------------------------------------------------------------
install:
	mv $(EXECUTABLE) $(INSTALLDIR)
