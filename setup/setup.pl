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
   --system                  configures the forecast system
   --project=name            configures a forecast project
   --model=model             configures a new forecast model

=head1 SYSTEM

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
the identifier passed on the command-line.

Configuration of a project involves the following steps:

 * Create a file config.project.<name> in config (user is responsible for this)
 * Run setup/setup.pl --project=<name>

At this time, additional manual steps may be required.

=head1 MODEL

A new forecast model is identified by a file config.model.<model> where <model>
is the identifier passed on the command-line. Note that during the system setup,
all models that have a config.model.<model> entry will already be setup. You
only need to run this script to add additional models.

Configuration of model involves the following steps:

 * Create a file config.model.<model> in config (user is responsible for this)
 * Run setup/setup.pl --model=<model>

This will compile the model and install the executable in the right
directory. At this time, additional manual steps may be required.

=head1 TOOL

A new forecast tool is identified by a file config.tool.<tool> where <tool>
is the identifier passed on the command-line. Note that during the system setup,
all tools that have a config.tool.<tool> entry will already be setup. You
only need to run this script to add additional tools.

Note that this step is only necessary for some of the forecast tools that need
to be compiled and installed. Examples of this are vic2nc and regrid. Most
forecast tools are perl and shell scripts that are installed directly in tools/bin

Configuration of a tool involves the following steps:

 * Create a file config.tool.<tool> in config (user is responsible for this)
 * Run setup/setup.pl --tool=<tool>

This will compile the tool and install the executable in the right directory
(specified in the config.tool.<tool> file. At this time, additional manual steps
may be required.

=cut

use strict;
use warnings;                   # instead of -w since that does not work
                                # reliably with /usr/bin/env

use Cwd qw(abs_path chdir cwd);
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

  if (defined $system) {
    setup_system();
  } elsif (defined $project) {
    setup_project($project);
  } elsif (defined $model) {
    setup_model($model);
  } elsif (defined $tool) {
    setup_tool($tool);
  } else {
    die "Internal error: Unrecognized setup option\n";
  }
}

############################### make_and_install ###############################
sub make_and_install {
  my ($srcdir, $exe, $mref, $sref) = @_;

  print "Make and install $exe ...\n" if $verbose;
  open MAKE, "<Makefile" or
    die "Cannot open Makefile in $srcdir: $!\n";
  my @make = <MAKE>;
  close MAKE or warn "Cannot close Makefile: $!\n";
  open OUT, ">Makefile.make"
    or die "Cannot open Makefile.make in $srcdir: $!\n";
  for my $line (@make) {
    for my $key (keys %$mref) {
      if ($line =~ m/\s*$key\s*=.*/) {
        $line = "$key = $mref->{$key}\n";
      }
    }
    print OUT $line;
  }
  close OUT or warn "Cannot close Makefile.make: $!\n";
  
  for my $key (keys %$sref) {
    modify_source(cwd(), $sref->{$key});
  }
  
  # run make all (which will also do the install)
  my @args = ('-f', 'Makefile.make', 'all');
  system($make, @args);
  # run make clean
  @args = ('clean');
  system($make, @args);
  # check that executable is created - if not, give a warning
  if (not -e $exe or not -x $exe) {
    warn "Failed installing " . $exe;
  }
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
  for my $file (@filelist) {
    open IN, "<$file" or die "Cannot open $file: $!\n";
    my @content = <IN>;
    close IN or warn "Cannot close $file: $!\n";
    my $changed = 0;
    for (my $i = 0; $i < @content; $i++) {
      if ($content[$i] =~ m/$match/) {
        print "$file: $content[$i]\n";
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
                          "system" => \$system,
                          "project=s" => \$project,
                          "model=s" => \$model,
                          "tool=s" => \$tool);

  pod2usage(-verbose => 2, -exitstatus => 0) if $man;
  pod2usage(-verbose => 1, -exitstatus => 0) if $help;

  my $total = 0;
  $total +=1 if defined $system;
  $total +=1 if defined $project;
  $total +=1 if defined $model;
  $total +=1 if defined $tool;

  pod2usage(-verbose => 1, -exitstatus => 1) if $total == 0;
  if ($total > 1) {
    warn "\nError: Can only specify either system, project, model or tool\n\n";
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

################################## setup_model #################################
sub setup_model {
  my ($model) = @_;
  my %info;

  # Setting up a model is very similar to setting up a tool. The two functions
  # should probably be merged.

  print "Setting up model: $model ...\n" if $quiet;
  %info = read_configuration("$basepath/config/config.model.$model");
  for my $key (keys %info) {
    $info{$key} =~ s/<BASEDIR>/$basepath/;
  }

  # make sure that MODEL_EXE_DIR exists, if not create it
  if (not -d $info{MODEL_EXE_DIR}) {
    make_path($info{MODEL_EXE_DIR}, {verbose => $verbose, mode => 0755}) or
      die "Cannot make path $info{MODEL_EXE_DIR}: $!";
  } else {
    chmod 0744, $info{MODEL_EXE_DIR} or die "Cannot change permission: $!\n";
  }

  # change to MODEL_SRC_DIR
  my $wd = cwd();
  print "Changing to $info{MODEL_SRC_DIR} ...\n" if $verbose;
  chdir $info{MODEL_SRC_DIR} or
    die "Cannot change to $info{MODEL_SRC_DIR}: $!\n";

  # Makefile
  my %mapping = ('EXECUTABLE' => $info{MODEL_EXE_NAME},
                 'TARGET' => $info{MODEL_EXE_NAME},
                 'INSTALLDIR' => $info{MODEL_EXE_DIR},
                 'TARGETDIR' => $info{MODEL_EXE_DIR}
                );

  # Determine source code modifications
  my %sourcemods;
  for my $key (keys %info) {
    if ($key =~ m/_SRCMOD_/) {
      my @fields = split /_SRCMOD_/, $key;
      $sourcemods{$fields[1]} = $info{$key};
    }
  }

  # make and install
  make_and_install(cwd(), join('/', $info{MODEL_EXE_DIR}, $info{MODEL_EXE_NAME}),
                   \%mapping, \%sourcemods);

  # change back to the starting directory
  print "Changing to $wd ...\n" if $verbose;
  chdir $wd or die "Cannot change to $wd: $!\n";
}

################################# setup_project ################################
sub setup_project {
  my ($project) = @_;

  print "Setting up project: $project ...\n" if $quiet;
}

################################## setup_tool ##################################
sub setup_tool {
  my ($tool) = @_;
  my %info;

  print "Setting up tool: $tool ...\n" if $quiet;
  %info = read_configuration("$basepath/config/config.tool.$tool");
  for my $key (keys %info) {
    $info{$key} =~ s/<BASEDIR>/$basepath/;
  }

  # make sure that TOOL_EXE_DIR exists, if not create it
  if (not -d $info{TOOL_EXE_DIR}) {
    make_path($info{TOOL_EXE_DIR}, {verbose => $verbose, mode => 0755}) or
      die "Cannot make path $info{TOOL_EXE_DIR}: $!";
  } else {
    chmod 0744, $info{TOOL_EXE_DIR} or die "Cannot change permission: $!\n";
  }

  # change to TOOL_SRC_DIR
  my $wd = cwd();
  print "Changing to $info{TOOL_SRC_DIR} ...\n" if $verbose;
  chdir $info{TOOL_SRC_DIR} or
    die "Cannot change to $info{TOOL_SRC_DIR}: $!\n";

  # Makefile
  my %mapping = ('EXECUTABLE' => $info{TOOL_EXE_NAME},
                 'TARGET' => $info{TOOL_EXE_NAME},
                 'INSTALLDIR' => $info{TOOL_EXE_DIR},
                 'TARGETDIR' => $info{TOOL_EXE_DIR}
                );

  # Determine source code modifications
  my %sourcemods;
  for my $key (keys %info) {
    if ($key =~ m/_SRCMOD_/) {
      my @fields = split /_SRCMOD_/, $key;
      $sourcemods{$fields[1]} = $info{$key};
    }
  }

  make_and_install(cwd(), join('/', $info{TOOL_EXE_DIR}, $info{TOOL_EXE_NAME}),
                   \%mapping, \%sourcemods);

  # change back to the starting directory
  print "Changing to $wd ...\n" if $verbose;
  chdir $wd or die "Cannot change to $wd: $!\n";
}

################################# setup_system #################################
sub setup_system {

  print "Setting up system ...\n" if $quiet;

  print "Checking directories and permissions ...\n" if $quiet;

  # make sure that the scripts in $basepath/tools/bin are executable
  my @filelist;
  my $dirname = "$basepath/tools/bin";
  opendir(DIR, "$dirname") or die "Cannot opendir $dirname: $!";
  @filelist = grep !/^\./, readdir(DIR);
  closedir(DIR);
  @filelist = map { join('/', $dirname, $_) } @filelist;
  map { print "chmod 0755 for $_\n" } @filelist if $verbose;
  chmod 0744, @filelist;

  # Create bin directory in $basepath/models
  if (not -d "$basepath/models/bin") {
    make_path("$basepath/models/bin", {verbose => $verbose, mode => 0755}) or
      die "Cannot make path $basepath/models/bin: $!";
  } else {
    chmod 0744, "$basepath/models/bin" or die "Cannot change permission: $!\n";
  }

  # setup tools
  print "Setting up tools ...\n" if $quiet;
  $dirname = "$basepath/config";
  opendir(DIR, "$dirname") or die "Cannot opendir $dirname: $!";
  my @toollist = grep /^config\.tool/, readdir(DIR);
  closedir(DIR);
  map { $_ =~ s/config\.tool\.// } @toollist;
  map { print "Tools to configure: $_\n" } @toollist if $verbose;
  map { setup_tool($_) } @toollist;

  # setup models
  print "Setting up models ...\n" if $quiet;
  $dirname = "$basepath/config";
  opendir(DIR, "$dirname") or die "Cannot opendir $dirname: $!";
  my @modellist = grep /^config\.model/, readdir(DIR);
  closedir(DIR);
  map { $_ =~ s/config\.model\.// } @modellist;
  map { print "Models to configure: $_\n" } @modellist if $verbose;
  map { setup_model($_) } @modellist;
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
