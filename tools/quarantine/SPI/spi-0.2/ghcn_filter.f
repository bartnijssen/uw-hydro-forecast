cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c  This program is a filter that takes as input a file of monthly
c  precipitation data in the Global Historic Climate format and  
c  outputs monthly precipitation in SPI format.
c
c
c   Input format:
c        Data- stanumyyyy jan_prec feb_prec ... dec_prec
c
c        Where:
c            stanum - Station ID
c            yyyy - year
c
c            prec - precipitation (in 0.1s mm)
c                Special codes:
c                    -9999 = missing
c
c   Output format:
c        Header
c        Data- yyyy mm prec
c
c        Where:
c            yyyy - year; 
c            mm   - month [1-12]
c            prec - precipitation (in 0.01's)
c
c        Special codes:
c            -9900 = Missing
c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
	program ghcn
	parameter (missng=-9900)
	character line*80
	dimension iprc(12)
c
c       Copy header line
c
	read(*,1000) line
	write(*,*) line
c
c       Read until EOF
c
 10	continue
	read(*,1001, end=30) n, iy, (iprc(i), i=1,12)
	do 20 im = 1,12
	   if(iprc(im) .eq. -9999) iprc(im) = missng
	   write(*,1002) iy, im, iprc(im)
 20	continue
	goto 10
 30	continue
	stop
 1000	format(a80)
 1001	format(i10,i4,12i5)
 1002	format(i4, i3, i7)
	end
