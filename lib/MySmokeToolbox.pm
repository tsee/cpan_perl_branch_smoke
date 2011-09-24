package
  MySmokeToolbox;
use strict;
use warnings;
use File::Spec;
use File::Temp qw(tempdir);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(make_work_dir src_conf_dir setup_cpanplus_dir setup_cpan_dir get_report_info);

SCOPE: {
  my $conf_dir;
  sub src_conf_dir {
    return $conf_dir if defined $conf_dir;
    require FindBin;
    $conf_dir = File::Spec->catdir($FindBin::RealBin, File::Spec->updir, 'config');
  }
}

sub make_work_dir {
  my $workdir = tempdir(CLEANUP => 1, DIR => File::Spec->tmpdir);
  $ENV{HOME} = $ENV{PERL5_CPANPLUS_BASE} = $ENV{PERL5_YACSMOKE_BASE} = $workdir;
  return $workdir;
}

sub setup_cpanplus_dir {
  my $workdir = shift;
  my $cpanpdir = File::Spec->catdir(src_conf_dir(), '.cpanplus');

  require File::Copy::Recursive;
  File::Copy::Recursive::dircopy($cpanpdir, File::Spec->catdir($workdir, '.cpanplus')) or die $!;
}

sub setup_cpan_dir {
  my $workdir = shift;
  my $cpandir = File::Spec->catdir(src_conf_dir(), '.cpan');

  require File::Copy::Recursive;
  File::Copy::Recursive::dircopy($cpandir, File::Spec->catdir($workdir, '.cpan')) or die $!;
}


# This attempts to determine the distname and test grade from the report file name.
# While a hack, this is practically a requirement over using Test::Reporter to
# parse the actual test result because Test::Reporter parsing is so painfully
# slow that the comparison report generation takes until the heat death of the
# universe (or until my patience runs out).
sub get_report_info {
  my $file = shift;
  my ($v, $d, $fcopy) = File::Spec->splitpath($file);

  # this is a hack, but orders of magnitude faster than using
  # Test::Reporter for large sets of reports
  $fcopy =~ s/^(\w+)\.// or return _get_report_info_reporter($file);
  my $grade = $1;

  # FIXME In principle, we could get the archname from the perl in question... can't be bothered now.
  $fcopy =~ s/^(.*?)\.(?:i[356]86|x86_64|arm|mips)// or return _get_report_info_reporter($file);
  my $distname = $1;

  return {distribution => $distname, file => $file, grade => $grade};
}

sub _get_report_info_reporter {
  my $file = shift;
  require Test::Reporter;
  my $tr = eval { Test::Reporter->new->read( $file ) };
  die if not $tr;
  return { file => $file, grade => $tr->grade, distribution => $tr->distribution };
}


1;

