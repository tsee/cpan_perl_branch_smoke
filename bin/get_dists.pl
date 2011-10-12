#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec;
use FindBin qw($RealBin);
use Getopt::Long qw(GetOptions);

use lib File::Spec->catdir($RealBin, File::Spec->updir, 'lib');

use MySmokeToolbox;

GetOptions(
  'config=s' => \(my $configfile),
  'stdout'   => \(my $stdout),
) or die "Invalid options";

my $cfg = MySmokeToolbox::SmokeConfig->new($configfile);
my $cpanmirror = $cfg->cpan_mirror;

MySmokeToolbox::MakeDistList->make_dist_list(
  $cpanmirror,
  ($stdout ? undef : $cfg->distribution_list_file)
)
and !$stdout
and print "Wrote output to '" . $cfg->distribution_list_file . "'\n";

