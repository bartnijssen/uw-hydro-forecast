#!/usr/bin/env perl
=pod

=head1 NAME

setup.pl

=head1 SYNOPSIS

setup.pl
 [options]

 Options:
   --help|?                  brief help message
   --man|info                full documentation
   --silent|quiet|verbose    verbosity level
   --system=system           configures the forecast system
   --project=name            configures a forecast project
   --model=model             configures a new forecast model

=head1 SYSTEM

A forecast project is identified by a file config.system.<name> where <name> is
the identifier passed on the command-line.

 * Create a file config.system.<name> in config (user is responsible for this)
 * Run setup/setup.pl --system=<name>

The forecast system consists of the code that allows the production of
forecasts. However, no actual forecasts will be produced until one or more
forecast projects are configured. Multiple forecast projects can use the same
forecast system to produce forecasts. This simply means that the forecast
algorithms are the same for these individual projects.

Configuration of a forecast system involves the following steps:

 * Compilation and installation of forecast code
 * Compilation and installation of hydrological and routing models
 * Changing of file mode to ensure that scripts are executable by the system
 * Checking of paths

At this point, much of the setup is still manual. For example, the user will
need to ensure that the crontab is in place. However, the setup script will at a
minimum alert the user to paths that are not accessible and other
inconsistencies.

=head1 PROJECT

A forecast project is identified by a file config.project.<name> where <name> is
the identifier passed on the command-line. Each project is associated with a
specific system identified as config.system.<system>.

Configuration of a project involves the following steps:

 * Create a file config.project.<name> in config (user is responsible for this)
 * Run setup/setup.pl --project=<name> --system=<system>

At this time, additional manual steps may be required.

=head1 MODEL

A new forecast model is identified by a file config.model.<model> where <model>
is the identifier passed on the command-line. Each model is associated with a
specific system identified as config.system.<system>.

Note that during the system setup, all models that have a config.model.<model>
entry will already be setup. You only need to run this script to add additional
models.

Configuration of model involves the following steps:

 * Create a file config.model.<model> in config (user is responsible for this)
 * Run setup/setup.pl --model=<model> --system=<system>

This will compile the model and install the executable in the right
directory. At this time, additional manual steps may be required.

=head1 TOOL

A new forecast tool is identified by a file config.tool.<tool> where <tool>
is the identifier passed on the command-line. Each tool is associated with a
specific system identified as config.system.<system>.

Note that during the system setup, all tools that have a config.tool.<tool>
entry will already be setup. You only need to run this script to add additional
tools.

Note that this step is only necessary for some of the forecast tools that need
to be compiled and installed. Examples of this are vic2nc and regrid. Most
forecast tools are perl and shell scripts that are copied directly in tools/bin
when the system is installed.

Configuration of a tool involves the following steps:

 * Create a file config.tool.<tool> in config (user is responsible for this)
 * Run setup/setup.pl --tool=<tool> --system=<system>

This will compile the tool and install the executable in the right directory
(specified in the config.tool.<tool> file. At this time, additional manual steps
may be required.

=cut

use strict;
use warnings;                   # instead of -w since that does not work
                                # reliably with /usr/bin/env

use Cwd qw(abs_path chdir cwd);
use File::Copy qw(copy);
use File::Path qw(make_path);
use File::Temp qw(tempfile tempdir);
use File::Basename;
use Getopt::Long;
use Pod::Usage;

# unix utils that are used
my $make = 'make';

# TOKEN to separate source code modifications
my $srcmodtoken = 'XXX';

my $quiet = 0;                  # not quite silent, just some progress messages
my $verbose = 0;                # highest verbosity level

my $scriptname;                 # name of this script
my $basepath;                   # base path for the forecast system

################################################################################
#                                     MAIN                                     #
################################################################################
{
  my $suffix;
  my $path;

  my ($system, $project, $model, $tool) = processcommandline();

  ($scriptname, $path, $suffix) = fileparse($0, ".pl");
  $basepath = abs_path($path);
  $basepath =~ s/\/setup$//;
  require "$basepath/tools/bin/simma_util.pl";

  if (defined $project) {
    setup_project($system, $project);
  } elsif (defined $model) {
    setup_model($system, $model);
  } elsif (defined $tool) {
    setup_tool($system, $tool);
  } else {
    setup_system($system);
  }
}

#################################### testpath ##################################
sub testpath {
  my ($path, $checks) = @_;

  if ($checks =~ /e/) {
    -e $path or return "Error: path does not exist: $path";
  }
  if ($checks =~ /d/) {
    -d $path or return "Error: Not a directory: $path";
  }
  if ($checks =~ /f/) {
    -f $path or return "Error: Not a file: $path";
  }
  if ($checks =~ /r/) {
    -r $path or return "Error: Not readable: $path";
  }
  if ($checks =~ /w/) {
    -w $path or return "Error: Not writable: $path";
  }
  if ($checks =~ /x/) {
    -x $path or return "Error: Not executable: $path";
  }

  return "success";
}

################################### get_tags ###################################
sub get_tags {
  my ($file, $tag) = @_;
  my %tags;
  my $str;

  my %info = read_configuration($file);
  for my $key (keys %info) {
    if ($key =~ /$tag/) {
      ($str = $key) =~ s/\s*(${tag}.*?)\s*$/($1)/;
      $tags{$key} = $info{$key};
    }
  }
  return %tags;
}

############################### make_and_install ###############################
sub make_and_install {
  my ($srcdir, $exe, $makefile, $sourcemodsref) = @_;

  print "Make and install $exe ...\n" if $verbose;

  # change to MODEL_SRC_DIR
  my $wd = cwd();
  print "Changing to $srcdir ...\n" if $verbose;
  chdir $srcdir or
    die "Cannot change to $srcdir: $!\n";

  for my $key (keys %$sourcemodsref) {
    modify_source(cwd(), $sourcemodsref->{$key});
  }

  # redirect STDOUT to make.log
  open OUT, ">&STDOUT";
  open ERR, ">&STDERR";
  open STDOUT, "> make.log" or die "Cannot open make.log: $!\n";
  open STDERR, "> make.err.log" or die "Cannot open make.err.log: $!\n";
  # Following line is stupid hack to prevent warning about ERR
  print ERR "";

  # run make all (which will also do the install)
  my @args = ('-f', $makefile, 'all');
  system($make, @args);
  # run make clean
  @args = ('-f', $makefile, 'clean');
  system($make, @args);
  # redirect STDOUT and STDERR back to where it belonged
  close STDOUT;
  open STDOUT, ">&OUT";
  close STDERR;
  open STDERR, ">&ERR";

  # check that executable is created - if not, give a warning
  if (not -e $exe or not -x $exe) {
    warn "Failed installing " . $exe;
  } else {
    print "Installed $exe ...\n" if $quiet;
  }

  # change back to the starting directory
  print "Changing to $wd ...\n" if $verbose;
  chdir $wd or die "Cannot change to $wd: $!\n";
}

################################ modify_source #################################
sub modify_source {
  my ($srcdir, $mod) = @_;
  
  my ($match, $value) = trim(split /$srcmodtoken/, $mod);
  print "Modifying source code in $srcdir: $value ...\n" if $verbose;
  my @filelist;
  opendir(DIR, $srcdir) or die "Cannot opendir $srcdir: $!";
  @filelist = grep !/^\./, readdir(DIR);
  closedir(DIR);
  @filelist = map { join('/', $srcdir, $_) } @filelist;
  my $changed;
  for my $file (@filelist) {
    next unless -T $file;
    open IN, "<$file" or die "Cannot open $file: $!\n";
    my @content = <IN>;
    close IN or warn "Cannot close $file: $!\n";
    $changed = 0;
    for (my $i = 0; $i < @content; $i++) {
      if ($content[$i] =~ m/$match/) {
        $content[$i] = "$value\n";
        $changed += 1;
      }
    }
    if ($changed) {
      open OUT, ">$file" or die "Cannot open $file: $!\n";
      print OUT @content;
      close OUT or warn "Cannot close $file: $!\n";
      print "Modified source code in $file\n" if $verbose;
    }
  }
}

############################## processcommandline ##############################
sub processcommandline {
  my $help;
  my $man;
  my $model;
  my $project;
  my $system;
  my $tool;

  my $result = GetOptions("silent" => sub {$quiet = 0, $verbose = 0},
                          "quiet" => sub {$quiet = 1, $verbose = 0},
                          "verbose" => sub {$quiet = 1, $verbose = 1},
                          "help|?" => \$help,
                          "man|info" => \$man,
                          "system=s" => \$system,
                          "project=s" => \$project,
                          "model=s" => \$model,
                          "tool=s" => \$tool);

  pod2usage(-verbose => 2, -exitstatus => 0) if $man;
  pod2usage(-verbose => 1, -exitstatus => 0) if $help;

  if (not defined $system) {
    warn "Error: Must specify system\n";
    pod2usage(-verbose => 1, -exitstatus => 1);
  }

  if (defined $model and not defined $system) {
    warn "Error: need to define system when defining model\n";
    pod2usage(-verbose => 1, -exitstatus => 1)
  }
  if (defined $project and not defined $system) {
    warn "Error: need to define system when defining project\n";
    pod2usage(-verbose => 1, -exitstatus => 1)
  }
  if (defined $tool and not defined $system) {
    warn "Error: need to define system when defining tool\n";
    pod2usage(-verbose => 1, -exitstatus => 1)
  }

  my $total = 0;
  $total +=1 if defined $project;
  $total +=1 if defined $model;
  $total +=1 if defined $tool;

  pod2usage(-verbose => 1, -exitstatus => 1) 
    if not defined $system and $total == 0;
  if ($total > 1) {
    warn "\nError: Cannot specfiy more  than one project, model or tool\n\n";
    pod2usage(-verbose => 1, -exitstatus => 1)
  }

  return ($system, $project, $model, $tool);
}

############################## read_configuration ##############################
sub read_configuration {
  my ($configfile) = @_;

  # to be consistent use the simma_util way of reading these files, even though
  # that is rather clunky
  my $href =  &read_config($configfile);

  return %{$href};
}

################################### sed_file ###################################
sub sed_file {
  my ($src, $target, $tref) = @_;

  open IN, "<$src" or die "Cannot open $src: $!\n";
  my @content = <IN>;
  close IN or warn "Cannot close $src: $!\n";
  my $changed = 0;
  for (my $i = 0; $i < @content; $i++) {
    for my $pattern (keys %$tref) {
      my $replace = $tref->{$pattern};
      if ($content[$i] =~ m/\<$pattern\>/) {
        $content[$i] =~ s/\<$pattern\>/$replace/;
        $changed += 1;
      }
    }
  }
  if ($changed or $src !~ $target) {
    open OUT, ">$target" or die "Cannot open $target: $!\n";
    print OUT @content;
    close OUT or warn "Cannot close $target: $!\n";
    print "Replaced tags: $src ==> $target\n" if $verbose and $changed;
    print "Copied: $src ==> $target\n" if $verbose and not $changed;
  }
}

################################## setup_model ##################################
sub setup_model {
  my ($system, $model) = @_;

  print "Setting up model: $model in $system ...\n" if $quiet;
  
  my %sysinfo = read_configuration("$basepath/config/config.system.$system");
  my %systags = get_tags("$basepath/config/config.system.$system", "SYSTEM");
  my $runtime = $sysinfo{SYSTEM_INSTALLDIR};

  my $srcfile = "$basepath/config/config.model.$model";
  my $targetfile = "$runtime/config/config.model.$model";
  sed_file($srcfile, $targetfile, \%systags);

  my %info = read_configuration("$runtime/config/config.model.$model");

  # Determine source code modifications
  my %sourcemods;
  for my $key (keys %info) {
    if ($key =~ m/_SRCMOD_/) {
      my @fields = split /_SRCMOD_/, $key;
      $sourcemods{$fields[1]} = $info{$key};
    }
  }

  # edit Makefile
  my %maketags = get_tags("$runtime/config/config.model.$model", "MAKE");
  $srcfile = "$info{MODEL_SRC_DIR}/Makefile";
  $targetfile = "$info{MODEL_SRC_DIR}/Makefile.make";
  sed_file($srcfile, $targetfile, \%maketags);

  make_and_install($info{MODEL_SRC_DIR}, 
                   "$info{MAKE_INSTALLDIR}/$info{MAKE_EXECUTABLE}",
                   "$info{MODEL_SRC_DIR}/Makefile.make", \%sourcemods);
}

################################# setup_project ################################
sub setup_project {
  my ($system, $project) = @_;
  my $result;

  print "Setting up project: $project in $system ...\n" if $quiet;
  my %sysinfo = read_configuration("$basepath/config/config.system.$system");
  my %systags = get_tags("$basepath/config/config.system.$system", "SYSTEM");

  my $runtime = $sysinfo{SYSTEM_INSTALLDIR};

  my $srcfile = "$basepath/config/config.project.$project";
  my $targetfile = "$runtime/config/config.project.$project";
  sed_file($srcfile, $targetfile, \%systags);

  my %info = read_configuration("$runtime/config/config.project.$project");

  # Check whether paths exist and print a message for each path. Recognize a
  # path by '/' in value. This is not fool-proof. Also no easy way to check for 
  # variables designated SUBDIR
  for my $key (sort keys %info) {
    next unless $info{$key} =~ /\//;
    $result = testpath($info{$key}, 'e');
    if ($result =~ /success/i) {
      print "\tSuccess: Found\t$key:\t$info{$key}\n" if $verbose;
    } else {
      print "\tWarning: Not found\t$key:\t$info{$key}\n";
    }
  } 

  # Check models
  my @models = split /,/, $info{MODEL_LIST};
  for my $model (@models) {
    $result = testpath("$runtime/bin/$model", 'e');
    if ($result =~ /success/i) {
      print "\tSuccess: Found\tModel $model\n" if $verbose;
    } else {
      print "\tWarning: Not found\tModel $model\n";
    }
  }
}

################################## setup_tool ##################################
sub setup_tool {
  my ($system, $tool) = @_;

  print "Setting up tool: $tool in $system ...\n" if $quiet;
  
  my %sysinfo = read_configuration("$basepath/config/config.system.$system");
  my %systags = get_tags("$basepath/config/config.system.$system", "SYSTEM");
  my $runtime = $sysinfo{SYSTEM_INSTALLDIR};

  my $srcfile = "$basepath/config/config.tool.$tool";
  my $targetfile = "$runtime/config/config.tool.$tool";
  sed_file($srcfile, $targetfile, \%systags);

  my %info = read_configuration("$runtime/config/config.tool.$tool");

  # Determine source code modifications
  my %sourcemods;
  for my $key (keys %info) {
    if ($key =~ m/_SRCMOD_/) {
      my @fields = split /_SRCMOD_/, $key;
      $sourcemods{$fields[1]} = $info{$key};
    }
  }

  # Makefile
  my %maketags = get_tags("$runtime/config/config.tool.$tool", "MAKE");
  $srcfile = "$info{TOOL_SRC_DIR}/Makefile";
  $targetfile = "$info{TOOL_SRC_DIR}/Makefile.make";
  sed_file($srcfile, $targetfile, \%maketags);

  make_and_install($info{TOOL_SRC_DIR}, 
                   "$info{MAKE_INSTALLDIR}/$info{MAKE_EXECUTABLE}",
                   "$info{TOOL_SRC_DIR}/Makefile.make", \%sourcemods);
}

################################# setup_system #################################
sub setup_system {
  my ($system) = @_;

  print "Setting up system: $system ...\n" if $quiet;
  my %info = read_configuration("$basepath/config/config.system.$system");

  # Create SYSTEM_INSTALLDIR/bin and SYSTEM_INSTALLDIR/config 
  my $runtime = $info{SYSTEM_INSTALLDIR};
  if (not -d "$runtime/config") {
    make_path("$runtime/config", {verbose => $verbose, mode => 0755}) or
      die "Cannot make path $runtime/config: $!";
  }
  if (not -d "$runtime/bin") {
    make_path("$runtime/bin", {verbose => $verbose, mode => 0755}) or
      die "Cannot make path $runtime/bin: $!";
  }
 
  my %tags = get_tags("$basepath/config/config.system.$system", "SYSTEM");

  # Get listing of executable files
  my @filelist;
  my %files;
  my @dirlist = ("$basepath/tools/bin", "$basepath/tools/publish");
  my $targetdir = "$runtime/bin";
  for my $srcdir (@dirlist) {
    opendir(DIR, $srcdir) or die "Cannot opendir $srcdir: $!";
    @filelist = grep !/^\./, readdir(DIR);
    closedir(DIR);
    for my $file (@filelist) {
      $files{"$srcdir/$file"} = "$targetdir/$file";
    }
  }

  # replace tags in scripts
  for my $srcfile (keys(%files)) {
    my $targetfile = $files{$srcfile};
    if (-T $srcfile) {
      sed_file($srcfile, $targetfile, \%tags);
    } else {
      copy($srcfile, $targetfile) 
        or die "Cannot copy $srcfile ==> $targetfile: $!\n";
    }
  }
  my $srcfile = "$basepath/config/config.system.$system";
  my $targetfile = "$runtime/config/config.system.$system";
  copy($srcfile, $targetfile) 
    or die "Cannot copy $srcfile ==> $targetfile: $!\n";
  print "Copied: $srcfile ==> $targetfile\n" if $verbose;

  # setup tools
  print "Setting up tools ...\n" if $quiet;
  my $dirname = "$basepath/config";
  opendir(DIR, "$dirname") or die "Cannot opendir $dirname: $!";
  my @toollist = grep /^config\.tool/, readdir(DIR);
  closedir(DIR);
  map { $_ =~ s/config\.tool\.// } @toollist;
  map { print "Tools to configure: $_\n" } @toollist if $verbose;
  map { setup_tool($system, $_) } @toollist;

  # setup models
  print "Setting up models ...\n" if $quiet;
  $dirname = "$basepath/config";
  opendir(DIR, "$dirname") or die "Cannot opendir $dirname: $!";
  my @modellist = grep /^config\.model/, readdir(DIR);
  closedir(DIR);
  map { $_ =~ s/config\.model\.// } @modellist;
  map { print "Models to configure: $_\n" } @modellist if $verbose;
  map { setup_model($system, $_) } @modellist;

  # make sure that the scripts in $basepath/tools/bin are executable
  opendir(DIR, "$runtime/bin") or die "Cannot opendir $runtime/bin: $!";
  @filelist = grep !/^\./, readdir(DIR);
  closedir(DIR);
  @filelist = map { join('/', "$runtime/bin", $_) } @filelist;
  map { print "chmod 0744 for $_\n" } @filelist if $verbose;
  chmod 0744, @filelist;

}

##################################### trim #####################################
sub trim {
  my @out = @_;
  foreach (@out) {
    s/^\s+//;
    s/\s+$//;
  }
  return wantarray ? @out : $out[0];
}
