#!/bin/csh
set indir = "/raid8/forecast/proj/uswide/tools" 
set basin = $1
`$indir/update_forcings_asc.pl $basin 2006-01-01 2006-02-29 2006-02-29`
`$indir/add_forc.scr $basin`
`$indir/update_forcings_asc.pl $basin 2006-03-01 2006-04-30 2006-04-30`
`$indir/add_forc.scr $basin`
`$indir/update_forcings_asc.pl $basin 2006-05-01 2006-06-30 2006-06-30`
`$indir/add_forc.scr $basin`
#`$indir/update_forcings_asc.pl $basin 2006-07-01 2006-08-31 2006-08-31`
#`$indir/add_forc.scr $basin`
#`$indir/update_forcings_asc.pl $basin 2006-09-01 2006-10-31 2006-10-31`
#`$indir/add_forc.scr $basin`
#`$indir/update_forcings_asc.pl $basin 2006-11-01 2006-12-31 2006-12-31`
#`$indir/add_forc.scr $basin`
#`$indir/update_forcings_asc.pl $basin 2009-01-01 2009-02-28 2009-02-28`
#`$indir/add_forc.scr $basin`
#`$indir/update_forcings_asc.pl $basin 2009-03-01 2009-04-30 2009-04-30`
#`$indir/add_forc.scr $basin`
#`$indir/update_forcings_asc.pl $basin 2009-05-01 2009-06-30 2009-06-30`
#`$indir/add_forc.scr $basin`

