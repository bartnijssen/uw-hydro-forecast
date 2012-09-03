
#
#  Makefile for Standardized Precipitation Index programs
#

#CC = acc
CC = gcc
F77 = g77

CFLAGS = -g -Wall 

SPI_OBJS =  spi.o rd_prec.o spi_gamma.o spi_empiric.o

VERSION=spi-0.2

all: spi spi_f mon_filter ghcn_filter

spi: $(SPI_OBJS)
	$(CC) $(CFLAGS) $(SPI_OBJS) -lm -o spi

spi_f: spi.f
	$(F77) spi.f -o spi_f

mon_filter: mon_filter.o
	$(CC) $(CFLAGS) mon_filter.o -lm -o mon_filter

ghcn_filter: ghcn_filter.o
	$(CC) $(CFLAGS) ghcn_filter.o -lm -o ghcn_filter

ghcn_filter_f: ghcn_filter.f
	$(F77) ghcn_filter.f -o ghcn_filter_f

clean:
	rm -f core *.o *~ #* *.trace

real_clean: clean
	rm -f spi spi_f ghcn_filter ghcn_filter_f mon_filter


