#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use FindBin qw($RealBin);

use lib File::Spec->catdir($RealBin, File::Spec->updir, 'lib');
use MySmokeToolbox qw(make_work_dir setup_cpan_dir);

GetOptions(
  'into-host-perl=s' => \(my $into_host_perl),
  'config=s' => \(my $config_file),
  'perl_name|perl-name|perlname=s' => \(my $perl_name),
  'no-test|notest' => \(my $notest),
) or die "Invalid options";

(defined $into_host_perl || defined $perl_name)
&& !(defined $into_host_perl && defined $perl_name)
  or die "Need target perl as --into-host-perl=path XOR --perl-name=nameInConfig!";

my $cfg = MySmokeToolbox::SmokeConfig->new($config_file);

my $perl;
if ($into_host_perl) {
  $perl = $into_host_perl;
}
else {
  $perl = $cfg->perl($perl_name)->executable;
}
-x $perl or die "Can't execute the target perl '$perl'!";

my $mirror = $cfg->cpan_mirror;
defined $mirror or die "Need source CPAN mirror!";

$ENV{CPAN_MIRROR} = $mirror;
$ENV{AUTOMATED_TESTING} = 1;
$ENV{PERL_MM_USE_DEFAULT} = 1;
$ENV{PERL_EXTUTILS_AUTOINSTALL} = "--defaultdeps";

my $workdir = make_work_dir();
setup_cpan_dir($workdir);

my $perl_type = defined($into_host_perl) ? 'host_perl' : 'test_perl';

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
    Parse::CPAN::Packages
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

