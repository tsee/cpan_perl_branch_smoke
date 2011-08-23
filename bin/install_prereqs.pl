#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use FindBin qw($RealBin);

use lib File::Spec->catdir($RealBin, File::Spec->updir, 'lib');
use MySmokeToolbox qw(make_work_dir setup_cpan_dir);

GetOptions(
  'perl=s' => \(my $perl),
  'm|mirror=s' => \(my $mirror),
) or die "Invalid options";

defined $perl or die "Need target --perl!";
-x $perl or die "Can't execute the target perl '$perl'!";
defined $mirror or die "Need source CPAN mirror!";
$ENV{CPAN_MIRROR} = $mirror;
$ENV{AUTOMATED_TESTING} = 1;
$ENV{PERL_MM_USE_DEFAULT} = 1;
$ENV{PERL_EXTUTILS_AUTOINSTALL} = "--defaultdeps";

my $workdir = make_work_dir();
setup_cpan_dir($workdir);

my @mod = map {chomp; $_} grep /\S/, grep !/^#/, <DATA>;
system($perl, '-MCPAN', '-e', 'install($_) for @ARGV', @mod)
  and die "Module installation failed!";

__DATA__

#Bundle::CPAN
#CPAN::Reporter
#CPAN::Reporter::Smoker
POE::Component::SmokeBox

CPANPLUS
CPANPLUS::Config::BaseEnv
CPANPLUS::YACSmoke

Test::Reporter
File::Fetch
Parse::CPAN::Meta
File::Temp
DBIx::Simple
DBD::SQLite
