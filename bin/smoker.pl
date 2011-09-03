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
  'perl=s' => \(my $perl),
  'perlname=s' => \(my $perlname),
  'm|mirror=s' => \(my $mirror),
  'o|outdir=s' => \(my $outdir),
  'restart' => \(my $restart),
);

die "No 'perl' specified\n" unless $perl;
defined $mirror or die "Need source CPAN mirror!";
defined $outdir or die "Need output directory!";
defined $perlname or die "Need a name assigned to the perl we're testing!";
die "No modules specified to smoke\n" unless scalar @ARGV;

$outdir = File::Spec->catdir(abs_path($outdir), "perl-$perlname");

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
}

# prepare output dir
File::Path::mkpath($outdir);
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

# prepare work dir and configuration
my $workdir = make_work_dir();
setup_cpanplus_dir($workdir);

my $smokebox = POE::Component::SmokeBox->spawn();

POE::Session->create(
  package_states => [
    'main' => [ qw(_start _stop _results) ],
  ],
  heap => { perl => $perl, pending => [ @todo] },
);

print "Running POE...\n";
$poe_kernel->run();
exit 0;

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

