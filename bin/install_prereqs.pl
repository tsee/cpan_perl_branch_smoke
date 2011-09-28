#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use FindBin qw($RealBin);

use lib File::Spec->catdir($RealBin, File::Spec->updir, 'lib');
use MySmokeToolbox qw(make_work_dir setup_cpan_dir);

GetOptions(
  'is-host-perl' => \(my $is_host_perl),
  'perl=s' => \(my $perl),
  'm|mirror=s' => \(my $mirror),
  'no-test|notest' => \(my $notest),
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

my $perl_type = $is_host_perl ? 'host_perl' : 'test_perl';

my %modules = (
  test_perl => [
    #Bundle::CPAN
    #CPAN::Reporter
    #CPAN::Reporter::Smoker
    #POE::Component::SmokeBox
    qw(

    CPANPLUS
    CPANPLUS::Config::BaseEnv
    CPANPLUS::YACSmoke

    Test::Reporter
    File::Fetch
    Parse::CPAN::Meta
    DBIx::Simple
    DBD::SQLite
    File::Copy::Recursive
  )],
  host_perl => [
    #Bundle::CPAN
    #CPAN::Reporter
    #CPAN::Reporter::Smoker
    qw(
    CPAN::Mini
    App::grindperl
    POE::Component::SmokeBox
    CPANPLUS
    CPANPLUS::Config::BaseEnv
    CPANPLUS::YACSmoke
    File::Copy::Recursive
    File::pushd
  )],
);

if ($notest) {
  system($perl, '-MCPAN', '-e', 'print("Installing $_\n"), CPAN::Shell->notest("install", $_) for @ARGV', @{$modules{$perl_type}})
    and die "Module installation failed!";
}
else {
  system($perl, '-MCPAN', '-e', 'print("Installing $_\n"), install($_) for @ARGV', @{$modules{$perl_type}})
    and die "Module installation failed!";
}

