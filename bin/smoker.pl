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
use MySmokeToolbox qw(make_work_dir setup_cpanplus_dir);

use constant DEBUG => 1;

$|=1;

GetOptions(
  'perl=s' => \(my $perl),
  'perlname=s' => \(my $perlname),
  'm|mirror=s' => \(my $mirror),
  'o|outdir=s' => \(my $outdir),
);

die "No 'perl' specified\n" unless $perl;
defined $mirror or die "Need source CPAN mirror!";
defined $outdir or die "Need output directory!";
defined $perlname or die "Need a name assigned to the perl we're testing!";
die "No modules specified to smoke\n" unless scalar @ARGV;

$outdir = File::Spec->catdir(abs_path($outdir), "perl-$perlname");
File::Path::mkpath($outdir);
$ENV{CPAN_REPORTER_OUTPUT_DIR} = $outdir;

$ENV{CPANMIRROR} = $mirror;
@ARGV = map {-f $_ ? do {open my $fh, "<", $_ or die $!; map {chomp $_; $_} <$fh>} : $_} @ARGV;

my $workdir = make_work_dir();
setup_cpanplus_dir($workdir);

my $smokebox = POE::Component::SmokeBox->spawn();

POE::Session->create(
  package_states => [
    'main' => [ qw(_start _stop _results) ],
  ],
  heap => { perl => $perl, pending => [ @ARGV ] },
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

