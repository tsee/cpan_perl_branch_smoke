#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec;
use FindBin qw($RealBin);
use Getopt::Long qw(GetOptions);
use File::Basename qw(fileparse);
use File::Temp qw(tempdir);

use lib File::Spec->catdir($RealBin, File::Spec->updir, 'lib');

use MySmokeToolbox;

# This isn't portable at all. It's also really shit code.
# But I don't care, it makes my life easier.

GetOptions(
  'config=s' => \(my $configfile),
) or die "Invalid options";

my $cfg = MySmokeToolbox::SmokeConfig->new($configfile);

my ($name, $path, $suffix) = fileparse($configfile, '.yml', '.yaml');
my $pidfile = File::Spec->catfile($path, $name . '.pid');

my $pid = -f $pidfile ? `cat $pidfile` : 0;

if (not $pid) {
  print "No PID file found, assuming no smoke running. Exiting.\n";
  exit(0);
}

my $report_script = File::Spec->catfile($RealBin, 'compare-report-dirs.pl');

my ($tmpdir, $skipped_dir, $all_dir) = make_reports($report_script, $configfile, $cfg);
foreach my $dir ($skipped_dir, $all_dir) {
  $dir =~ s/\/$//;
  system(qq{rsync -rz $dir dromedary:public_html/}) and die $!;
}

sub make_reports {
  my ($script, $cfgfile, $cfg) = @_;
  my $tmpdir = tempdir(CLEANUP => 1);

  my $name = $cfg->name;

  my @outdirs = (File::Spec->catdir($tmpdir, $name));
  my @cmd = ($^X, $script, '--html', '--config', $cfgfile, '--output-dir', $outdirs[-1], '--skip-missing');
  system("@cmd 2>&1")
    and die "Failed to generate report: $!";

  push @outdirs, $outdirs[-1] . '_withmissing_dists';
  pop @cmd;
  $cmd[-1] = $outdirs[-1];
  system("@cmd 2>&1")
    and die "Failed to generate report: $!";

  return($tmpdir, @outdirs);
}
