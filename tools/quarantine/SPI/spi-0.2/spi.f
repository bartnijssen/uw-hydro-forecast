cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c       Standardized Precipitation Index.
c
c
c      Usage: spi length [length ...] [<infile] [>outfile]
c
c      Where:
c         run_length - integer > 0; running sum length for SPI
c         infile - optional input file; if omitted, spi reads
c                  from standard input.
c         outfile - optional output file; if omitted, spi writes
c                  to standard output.
c
c
c      Notes on the ForTran version:
c
c      1) Lengths are hard coded to be 3, 6, 12, and 24 months.  This is
c      necessasry since ForTran has no standard way of passing command
c      line arguments.
c
c      2) System dependent code is bracketed with 'c*****'s
c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

      program spiprg
      parameter (nlen=4, maxyrs=120, amssng=-99.0,
     1          ibegyr=1880, iendyr=ibegyr+maxyrs)
      character header*80
      dimension len(nlen)
      real prec(maxyrs*12), beta(12), gamm(12), pzero(12), 
     1     spi(maxyrs*12,nlen)
      data len / 3, 6, 12, 24/
c*****
c
c  Open files.  These are defaults under most unix f77's
c
c      open(unit=0, file='stderr')
c      open(unit=5, file='stdin')
c      open(unit=6, file='stdout')
c
c*****
      call rdprec(header, prec, 5)
      write(6, 1000) header

c  Compute SPI's 
      do 10 i = 1, nlen
         call spigam (len(i), prec, beta, gamm, pzero, spi(1,i))
 10   continue


c  Skip leading missings
      ifirst = 0
 20   continue
      ifirst = ifirst + 1
      if (spi(ifirst,1) .eq. amssng) goto 20

c  Skip trailing missngs
      last = maxyrs*12 + 1
 30   continue
      last = last - 1
      if (spi(last,1) .eq. amssng) goto 30

c  Ouput SPI's
      do 40 i = ifirst, last
c         if (spi(i,1) .eq. amssng) goto 50
         iy = (i-1)/12 + ibegyr
         im = mod (i-1,12)+1
         write(6, 1001) iy, im, (spi(i,j), j=1,nlen)
 40   continue
 50   continue
      stop
 1000 format(a80)
 1001 format(i4,i3,4f7.2)
      end
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c  Read monthly prec data.  
c
c   Format:
c        Header
c        Data- yyyy mm prec
c
c        Where:
c            yyyy - year; values > ENDYR and < BEGYR will be skipped.
c            mm   - month [1-12]
c            prec - precipitation (in 0.01's)
c
c        Special codes:
c            -9900 = Missing
c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine rdprec(header, prec, inprec)
      parameter (nlen=4, maxyrs=120, amssng=-99.0,
     1          ibegyr=1880, iendyr=ibegyr+maxyrs)
      character header*80
      real prec(maxyrs*12)
c   Set prec array to MISSING
      do 10 i = 1, maxyrs*12
         prec(i) = amssng
 10   continue
c   Read header
      read(inprec, 1000, err=40) header
c   Read data
 20   continue
         read(inprec, *, end=30, err=40) iy, im, iprc
         iy = iy - ibegyr
         if(iy .lt. 0) goto 20
         if(iy .gt. maxyrs) goto 30
         prec(iy*12+im) = iprc/100.0
c         write(6, *) iy, im, prec(iy*12+im)
      goto 20
 30   continue
      return
 40   continue
      write(0, *) 'Error reading input file.'
      stop
 1000 format(a80)
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c     These functions compute the Standardized Precipitation Index
c     using an incomplete gamma distribution function to estimate
c     probabilities.
c
c     Useful references are:
c
c     _Numerical Recipes in C_ by Flannery, Teukolsky and Vetterling
c     Cambridge University Press, ISBN 0-521-35465-x 
c
c     _Handbook of Mathematical Functions_ by Abramowitz and Stegun
c     Dover, Standard Book Number 486-61272-4
c
c     Notes for ForTran users:
c     - There is a companion _Numerical Recipes in Fortran.  The
c     following code was translated from the c code.
c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc

cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c   Calculate indices assuming incomplete gamma distribution.
c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine spigam (nrun, pp, beta, gamm, pzero, index)
      parameter (nlen=4, maxyrs=120, amssng=-99.0,
     1     ibegyr=1880, iendyr=ibegyr+maxyrs)
      real pp(maxyrs*12), index(maxyrs*12),tmparr(maxyrs+1),
     1     beta(12), gamm(12), pzero(12)
c
c   The first nrun-1 index values will be missing.
c
      do 10 j = 1, nrun-1
         index(j) = amssng
 10   continue
c
c     Sum nrun precip. values; 
c     store them in the appropriate index location.
c
c     If any value is missing; set the sum to missing.
c
      do 30 j = nrun, maxyrs*12
         index(j) = 0.0
         do 20 i = 0, nrun-1
            if(pp(j - i) .ne. amssng) then
               index(j) = index(j) + pp(j - i)
            else
               index(j) = amssng
               goto 30
            endif
 20      continue
 30   continue
c
c   For nrun<12, the monthly distributions will be substantially
c   different.  So we need to compute gamma parameters for
c   each month starting with the (nrun-1)th.
c
      do 50 i = 0,11
         n = 0
         do 40 j = nrun+i, maxyrs*12, 12
            if(index(j) .ne. amssng) then
               n = n + 1
               tmparr(n) = index(j)
            endif
 40      continue
         im = mod (nrun+i-1, 12) + 1
c       
c     Here's where we do the fitting.
c
         call gamfit (tmparr, n, alpha, beta(im), gamm(im), pzero(im))
 50   continue
c
c     Replace precip. sums stored in index with SPI's
c
      do 60 j = nrun, maxyrs*12
         im = mod (j-1,12) + 1
         if(index(j) .ne. amssng) then
c
c     Get the probability
c
	    index(j) = gamcdf(beta(im), gamm(im), pzero(im), index(j))
c
c     Convert prob. to z value. 
c
	    index(j) = anvnrm(index(j))
         endif
 60   continue
      return
      end

ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c   input prob; return z.
c
c   See Abromowitz and Stegun _Handbook of Mathematical Functions_, p. 933
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      function anvnrm (prob)
      data c0, c1, c2 /2.515517, 0.802853, 0.010328/
      data d1, d2, d3 /1.432788, 0.189269, 0.001308/
  
      if (prob .gt. 0.5) then
         sign = 1.0
         prob = 1.0 - prob
      else
         sign = -1.0
      endif
  
      if (prob .lt. 0.0) then
         write(0, *) 'Error in anvnrm(). Prob. not in [0,1.0]'
         anvnrm = 0.0
         return
      endif

      if (prob .eq. 0.0) then
         anvnrm = 1.0e37 * sign
         return
      endif
  
      t = sqrt(alog (1.0 / (prob * prob)))
      anvnrm = (sign * (t - ((((c2 * t) + c1) * t) + c0) / 
     1     ((((((d3 * t) + d2) * t) + d1) * t) + 1.0)))
      return
      end
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c  Estimate incomplete gamma parameters.
c
c  Input:
c     datarr - data array
c     n - size of datarr
c
c Output:
c     alpha, beta, gamma - gamma paarameters
c     pzero - probability of zero.
c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
      subroutine gamfit (datarr, n, alpha, beta, gamm, pzero)
      real datarr(*)
      if (n .le. 0) then
         write(0, *) 'Error in gamfit - empty data array'
         stop
      endif

      sum = 0.0
      sumlog = 0.0
      pzero = 0.0
      nact = 0
  
c     compute sums
      do 10 i = 1, n
         if (datarr(i) .gt. 0.0) then
            sum = sum + datarr(i)
            sumlog = sumlog + alog (datarr(i))
            nact = nact + 1
         else
            pzero = pzero + 1
         endif
 10   continue
      pzero = pzero / n
      if(nact .ne. 0.0) av = sum / nact
  
c     Bogus data array but do something reasonable
      if(nact .eq. 1) then
         alpha = 0.0
         gamm = 1.0
         beta = av
         return
      endif

c     They were all zeroes. 
      if(pzero .eq. 1.0) then
         alpha = 0.0
         gamm = 1.0
         beta = av
         return
      endif

c     Use MLE
      alpha = alog (av) - sumlog / nact
      gamm = (1.0 + sqrt (1.0 + 4.0 * alpha / 3.0)) / (4.0 * alpha)
      beta = av / gamm
  
      return
      end


cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c  Compute probability of a<=x using incomplete gamma parameters.
c
c  Input:
c      beta, gamma - gamma parameters
c      pzero - probability of zero.
c      x - value.
c
c  Return:
c      Probability  a<=x.
c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc


      function  gamcdf (beta, gamm, pzero, x)
      if(x .le. 0.0) then
         gamcdf = pzero
      else
         gamcdf = pzero + (1.0 - pzero) * gammap (gamm, x / beta)
      endif
      return
      end

cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c  Compute inverse gamma function i.e. return x given p where CDF(x) = p.
c
c  Input:
c      beta, gamma - gamma parameters
c      pzero - probability of zero.
c      prob - probability.
c
c  Return:
c      x as above.
c
c  Method:
c      We use a simple binary search to first bracket out initial
c      guess and then to refine our guesses until two guesses are within
c      tolerance (eps).  Is there a better way to do this?
c
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc


      function gaminv (beta, gamm, pzero, prob)
      data  eps /1.0e-7/
  
c     Check if prob < prob of zero
      if (prob .le. pzero) then
         gaminv = 0.0
         return
      endif
  
c     Otherwise adjust prob
      prob = (prob - pzero) / (1.0 - pzero)
  
c     Make initial guess. Keep doubling estimate until prob is
c     bracketed.
      thigh = 2.0*eps 
 10   continue
      phigh = gamcdf (beta, gamm, pzero, thigh)
      if(phigh .ge. prob) goto 20
      thigh = thigh*2.0
      goto 10
 20   continue
      tlow = thigh / 2.0
  
c     Iterate to find root.
      niter = 0
 30   continue
      if((thigh - tlow) .le. eps) goto 40
      niter = niter + 1
      t = (tlow + thigh) / 2.0
      p = gamcdf (beta, gamm, pzero, t)
      
      if (p .lt. prob) then
         tlow = t
      else
         thigh = t
      endif
      goto 30
 40   continue
      gaminv = (tlow + thigh) / 2.0
      return
      end
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c  Functions for the incomplete gamma functions P and Q
c
c                  1     /x  -t a-1
c   P (a, x) = -------- |   e  t    dt,  a > 0
c              Gamma(x)/ 0
c
c   Q (a, x) = 1 - P (a, x)
c
c Reference: Press, Flannery, Teukolsky, and Vetterling, 
c        _Numerical Recipes_, pp. 160-163
c
c Thanks to kenny@cs.uiuc.edu
c
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c Evaluate P(a,x) by its series representation.  
c
      function gamser (a, x)
c     Maximum number of iterations, and bound on error.
      parameter (maxitr=100, eps=3.0e-7)
      data iwarn /0/
      gln = gammln (a)
      if (x .eq. 0.0) then
         gamser = 0.0
         return
      endif
      ap = a
      sum = 1.0 / a
      del = sum
  
      do 10 n = 1, maxitr
         ap = ap + 1.0
         del = del * (x / ap)
         sum = sum + del
         if (abs (del) .lt. eps * abs (sum)) goto 20
 10   continue
      iwarn = iwarn + 1
      if (iwarn .lt. 20) then
         write (0, *) 'gamser(',a,x,'): not converging.'
         write (0, *) 'Approximate value of ',sum,'  + /-',del,' used.'
      endif
 20   continue
      gamser =  sum * exp (-x + a * alog (x) - gln)
      return
      end

c
c     Evaluate P(a,x) in its continued fraction representation.
c
      function gammcf (a, x)
      parameter (maxitr=100, eps=3.0e-7)
      data nwarn / 0 /, g / 0.0 /
  
      gln = gammln (a)
      gold = 0.0
      a0 = 1.0
      a1 = x
      b0 = 0.0
      b1 = 1.0
      fac = 1.0
      do 10 n = 1, maxitr
         an = n
         ana = an - a
         a0 = (a1 + a0 * ana) * fac
         b0 = (b1 + b0 * ana) * fac
         anf = an * fac
         a1 = x * a0 + anf * a1
         b1 = x * b0 + anf * b1
         if (a1 .ne. 0.0) then
            fac = 1.0 / a1
            g = b1 * fac
            if (abs((g - gold) / g) .lt. eps) goto 20
            gold = g
         endif
 10   continue
      nwarn = nwarn + 1
      if (nwarn .lt. 20) then
         write (0, *) 'gammcf(',a,x,'): not converging.'
         write (0, *) 'Inaccurate value of ', g, ' +/- ',
     1                abs(g - gold), ' used.'
      endif
 20   continue
      gammcf =  g * exp (-x + a * alog (x) - gln)
      return
      end
c
c     Evaluate the incomplete gamma function P(a,x), choosing the most 
c     appropriate representation.
c
      function gammap (a, x)
      if (x .lt. a + 1.0) then
         gammap = gamser (a, x)
      else
         gammap = 1.0 - gammcf (a, x)
      endif
      return
      end
c
c     Evaluate the incomplete gamma function Q(a,x), choosing the most 
c   appropriate representation.
c
      function gammaq (a, x)
      if (x .lt. a + 1.0) then
         gammaq = 1.0 - gamser (a, x)
      else
         gammaq = gammcf (a, x) 
      endif
      return
      end
c
c     For those who don't have a ln(gamma) function.
c
      function gammln(xx)
      dimension cof(6)
      data cof /76.18009173, -86.50532033, 24.01409822, -1.231739516,
     1     0.120858003e-2, -0.536382e-5/          
      x = xx - 1.0
      tmp = x + 5.5
      tmp = tmp - (x+0.5) * alog (tmp)
      ser = 1.0
      do 10 j = 1, 5
         x = x + 1.0
         ser = ser + cof(j) / x
 10   continue
      gammln = -tmp + alog (2.50662827465 * ser)
      return
      end
