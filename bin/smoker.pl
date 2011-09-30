# A simple smoker that takes modules to smoke from @ARGV

use strict;
use warnings;
use POE;
use POE::Component::SmokeBox;
use POE::Component::SmokeBox::Smoker;
use POE::Component::SmokeBox::Job;
use Getopt::Long;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path ();
use FindBin qw($RealBin);
use Cwd qw(abs_path);

use lib File::Spec->catdir($RealBin, File::Spec->updir, 'lib');
use MySmokeToolbox qw(make_work_dir setup_cpanplus_dir get_report_info);

use constant DEBUG => 1;

$|=1;

GetOptions(
  'config=s'                                                     => \(my $configfile),
  'perl_name|perl-name|perlname=s'                               => \(my $perlname),
  'restart_from_scratch|restart-from-scratch|restartfromscratch' => \(my $restart),
);

my $cfg = MySmokeToolbox::SmokeConfig->new($configfile);
my $perlcfg = $cfg->perl($perlname);
my $processes = $cfg->smoke_processes_per_perl;
$processes = 1 if not $processes;
my $mirror = $cfg->cpan_mirror;
my $perl = $perlcfg->executable;

die "No modules specified to smoke\n" unless scalar @ARGV;

$perlcfg->assert_smoke_report_output_dir;
my $outdir = $perlcfg->smoke_report_output_dir;

if ($restart) {
  local $| = 1;
  print "I am going to restart the smoker, so all previous progress will\n"
      . "be lost. Continue? [yN]";
  my $what = <STDIN>;
  if ($what !~ /^\s*y/i) {
    print "Not running.\n";
    exit;
  }

  File::Path::rmtree($outdir); # nuke progress
  $perlcfg->assert_smoke_report_output_dir;
}

# prepare output dir
$ENV{CPAN_REPORTER_OUTPUT_DIR} = $outdir;
$ENV{CPANMIRROR} = $mirror;

# read dist list from files in @ARGV or use the module names provided.
my @todo = map {-f $_ ? do {open my $fh, "<", $_ or die $!; map {chomp $_; $_} <$fh>} : $_} @ARGV;

# read in progress
# FIXME skipping already-done modules only works if the todos
# are distribution files instead of module names.
my $suffix = qr{\.(?:tar\.(?:bz2|gz|Z)|t(?:gz|bz)|(?<!ppm\.)zip|pm.gz)$}i; 
my $done_dists = read_progress($outdir);
print "Original todo list: " . scalar(@todo) . " distributions.\n";
@todo = grep {
  my ($v, $d, $f) = File::Spec->splitpath($_);
  $f =~ s/$suffix//;
  not $done_dists->{$f}
} @todo;
print "Filtered todo list: " . scalar(@todo) . " distributions.\n";

my @pids;
my @proc_todo; # per-process todo lists
my $proc_no; # this process' running id (only in children)
my $per_proc = int(scalar(@todo) / $processes); # no. of items to do per process
push @proc_todo, [splice(@todo, 0, $per_proc)] for 1..$processes-1; # divide work
push @proc_todo, \@todo; # the rest

if ($processes > 1) {
  print "Divided todo list in " . $processes . " chunks:\n";
  print join(', ', map {"[" . scalar(@{ $proc_todo[$_] }) . "]"} 0..$#proc_todo), "\n";
}


# spawn workers
foreach my $this_proc_no (1..$processes) {
  my $pid = fork;
  $proc_no = $this_proc_no, last if not $pid;
  push @pids, $pid;
}

# The parent process just waits for all children to finish
if (!$proc_no) {
  waitpid($_, 0) for @pids;
  print "Parent, all children done!\n";
  exit;
}

# prepare work dir and configuration
my $workdir = make_work_dir();
setup_cpanplus_dir($workdir);

# Okay, I admit that it looks like SmokeBox can run many smokers
# in parallel, but the interface still eludes me and doesn't seem
# to be geared towards dividing work between multiple cores but rather
# smoking the same modules on multiple perls (which would be useful, too,
# but not at all the primary objective of the above fork hacks).

my $smokebox = POE::Component::SmokeBox->spawn();

POE::Session->create(
  package_states => [
    'main' => [ qw(_start _stop _results) ],
  ],
  heap => { perl => $perl, pending => $proc_todo[$proc_no-1] },
);

print "Running POE...\n";
$poe_kernel->run();

print "Child $proc_no: Done.\n";
exit(0);

sub _start {
  my ($kernel,$heap) = @_[KERNEL,HEAP];

  my $smoker = POE::Component::SmokeBox::Smoker->new( perl => $perl, );

  $smokebox->add_smoker( $smoker );

  for (@{ $heap->{pending} }) {
    $smokebox->submit(
      event => '_results',
      job => POE::Component::SmokeBox::Job->new( command => 'smoke', module => $_ )
    )
  }
  warn "_start";
  return undef;
}

sub _stop {
  warn "_stop";
  $smokebox->shutdown();
  return undef;
}

sub _results {
  my $results = $_[ARG0];
  warn "_results";
  use Data::Dumper; warn Dumper $results;
  print $_, "\n" for map { @{ $_->{log} } } $results->{result}->results();
  return undef;
}

sub read_progress {
  my $dir = shift;
  print "Reading previous progress. This can take a while...\n";

  my $progress = {};
  opendir my $dh, $dir or die "Cannot open output directory for reading: $!";
  while ($_ = readdir($dh)) {
    next unless /\.rpt$/;
    my $file = File::Spec->catdir($dir, $_);
    next unless -f $file;
    my $info = get_report_info($file);
    $progress->{$info->{distribution}} = $info;
  }
  closedir $dh;
  return $progress;
}

