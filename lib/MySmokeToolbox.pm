package
  MySmokeToolbox;
use strict;
use warnings;
use File::Spec;
use File::Temp qw(tempdir);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(make_work_dir src_conf_dir setup_cpanplus_dir setup_cpan_dir);

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

  `cp -r $cpanpdir $workdir`; # FIXME portability
}

sub setup_cpan_dir {
  my $workdir = shift;
  my $cpandir = File::Spec->catdir(src_conf_dir(), '.cpan');

  `cp -r $cpandir $workdir`; # FIXME portability
}


1;

