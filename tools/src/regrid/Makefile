# Makefile for regrid code
#
# NOTES
# If the code is to be run on another operating system "make clean" before
# recompiling.
# It is recommended that this code is NOT optimised above O2, due to the
# dynamic memory allocation.
# The -C flag will not work on this code due to the dynamic memory allocation.

# Set INSTALLDIR
INSTALLDIR = <MAKE_INSTALLDIR>

F77 = <MAKE_FORTRAN>

FFLAGS  = <MAKE_FFLAGS>

EXECUTABLE = <MAKE_EXECUTABLE>

OBJECTS = \
	indexx.o \
	isaleap.o \
	iso_weight.o \
	latlong.o \
	near_neigh.o \
	symap.o\
	chgtemp.o\
	grd.o 

SOURCE = \
	indexx.f \
	isaleap.f \
	iso_weight.f \
	latlong.f \
	near_neigh.f \
	symap.f\
	chgtemp.f\
	grd.f

LIBS =

default: $(EXECUTABLE)

all: $(EXECUTABLE) install

.f.o:
	$(F77) $(FFLAGS) -c $< -o $@

$(EXECUTABLE): $(OBJECTS)
	$(F77) $(FFLAGS) $(OBJECTS) -o $(EXECUTABLE) $(LIBS)

clean:
	/bin/rm -f *.o $(EXECUTABLE)

# --------------------------------------------------------------------
# install
# --------------------------------------------------------------------
install:
	mv $(EXECUTABLE) $(INSTALLDIR)
