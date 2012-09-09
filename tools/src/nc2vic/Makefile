# Set INSTALLDIR
INSTALLDIR = ../../bin/

# Set EXECUTABLE
EXECUTABLE = xxxxx

#FLAGS = -Wall -O
FLAGS = -O

NETCDFINC = /opt/local/include

NETCDFLIB = /opt/local/lib

CC        = gcc 
HDRS       = -I$(NETCDFINC)
LIBRARY      = -L$(NETCDFLIB) -lnetcdf
RM          = /bin/rm -f

OBJS = nc2vic.c nc2vicIO.c

default: nc2vic

all: nc2vic	install

clean :
	$(RM) *.o core log *~ 

nc2vic: $(OBJS)
	$(CC) $(FLAGS) -o $(EXECUTABLE) $(OBJS) $(LIBRARY) $(HDRS)

# --------------------------------------------------------------------
# install
# --------------------------------------------------------------------
install:
	mv $(EXECUTABLE) $(INSTALLDIR)
