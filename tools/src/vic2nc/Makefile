INSTALLDIR = <MAKE_INSTALLDIR>
EXECUTABLE = <MAKE_EXECUTABLE>

CC = <MAKE_CC>
CFLAGS = <MAKE_CFLAGS>
NETCDFINC = <MAKE_NETCDF_INC>
NETCDFLIB = <MAKE_NETCDF_LIB>

HDRS = -I$(NETCDFINC)
LIBRARY = -L$(NETCDFLIB) -lnetcdf
RM = /bin/rm -f

OBJS = vic2nc.c

default: $(EXECUTABLE)

all : $(EXECUTABLE) install clean

clean :
	$(RM) *.o core Makefile.make *log *~

vic2nc: $(OBJS)
	$(CC) $(CFLAGS) -o $(EXECUTABLE) $(OBJS) $(LIBRARY) $(HDRS)

# --------------------------------------------------------------------
# install
# --------------------------------------------------------------------
install:
	mv $(EXECUTABLE) $(INSTALLDIR)
