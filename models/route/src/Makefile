# Routing program Makefile
# --------------------------------------------------------------------

# -----------------------------------------------------------------------
# SET ENVIRONMENT-SPECIFIC OPTIONS HERE
# -----------------------------------------------------------------------

# Set SHELL = your shell here
SHELL = /bin/csh

# Set CC = your compiler here
CC = gcc

# Set INSTALLDIR
INSTALLDIR = ../bin

# Set EXECUTABLE
EXECUTABLE = route_forecast

# Uncomment for normal optimized code flags (fastest run option)
CFLAGS  = -I. -O3 -Wall -Wno-unused
LIBRARY = -lm

# Uncomment to include debugging information
#CFLAGS  = -I. -g -Wall -Wno-unused
#LIBRARY = -lm

# Uncomment to include execution profiling information
#CFLAGS  = -I. -O3 -pg -Wall -Wno-unused
#LIBRARY = -lm

# Uncomment to debug memory problems using electric fence (man efence)
#CFLAGS  = -I. -g -Wall -Wno-unused
#LIBRARY = -lm -lefence -L/usr/local/lib


# -----------------------------------------------------------------------
# MOST USERS DO NOT NEED TO MODIFY BELOW THIS LINE
# -----------------------------------------------------------------------

HDRS = 

OBJS = route_forecast.o 

SRCS = $(OBJS:%.o=%.c) 

default: depend model

all: depend model install

full: clean depend tags model

clean::
	\rm -f *.o core log *~ .depend

model: $(OBJS)
	$(CC) -o $(EXECUTABLE) $(OBJS) $(CFLAGS) $(LIBRARY)

clean::
	\rm -f $(EXECUTABLE)

# -------------------------------------------------------------
# tags
# so we can find our way around
# -------------------------------------------------------------
tags:	TAGS
TAGS:	$(SRCS) $(HDRS)
	etags $(SRCS) $(HDRS)

clean::
	\rm -f TAGS	       

# -------------------------------------------------------------
# depend
# -------------------------------------------------------------
depend: .depend
.depend:	$(SRCS) $(HDRS)
	$(CC) $(CFLAGS) -M $(SRCS) > $@

clean::
	\rm -f .depend

# --------------------------------------------------------------------
# install
# --------------------------------------------------------------------
install:
	mv route $(INSTALLDIR)
