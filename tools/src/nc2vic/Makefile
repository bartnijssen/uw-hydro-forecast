# Set INSTALLDIR
INSTALLDIR = <MAKE_INSTALLDIR>

# Set EXECUTABLE
EXECUTABLE = <MAKE_EXECUTABLE>

CFLAGS = <MAKE_CFLAGS>

NETCDFINC = <MAKE_NETCDF_INC>

NETCDFLIB = <MAKE_NETCDF_LIB>

CC        = <MAKE_CC>
HDRS       = -I$(NETCDFINC)
LIBRARY      = -L$(NETCDFLIB) -lnetcdf
RM          = /bin/rm -f

OBJS = nc2vic.c nc2vicIO.c

default: nc2vic

all: nc2vic	install

clean :
	$(RM) *.o core log *~

nc2vic: $(OBJS)
	$(CC) $(CFLAGS) -o $(EXECUTABLE) $(OBJS) $(LIBRARY) $(HDRS)

# --------------------------------------------------------------------
# install
# --------------------------------------------------------------------
install:
	mv $(EXECUTABLE) $(INSTALLDIR)
