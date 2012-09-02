CC        = gcc $(MY_CFLAGS)
HDRS       = -I$(INC_NETCDF)
LIBRARY      = -L$(LIB_NETCDF) -lnetcdf
RM          = /bin/rm -f

OBJS = nc2vic.c nc2vicIO.c

all : 
	make nc2vic

default:
	make nc2vic

clean :
	$(RM) *.o core log *~ 

nc2vic: $(OBJS)
	$(CC) -g -o nc2vic $(OBJS) $(LIBRARY) $(HDRS)

