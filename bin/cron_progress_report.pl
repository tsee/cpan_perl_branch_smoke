#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec;
use FindBin qw($RealBin);
use Getopt::Long qw(GetOptions);
use File::Basename qw(fileparse);

use lib File::Spec->catdir($RealBin, File::Spec->updir, 'lib');

use MySmokeToolbox;

# This isn't portable at all. It's also really shit code.
# But I don't care, it makes my life easier.

GetOptions(
  'config=s' => \(my $configfile),
) or die "Invalid options";

my $cfg = MySmokeToolbox::SmokeConfig->new($configfile);

my ($name, $path, $suffix) = fileparse($configfile, 'yml', 'yaml');
my $pidfile = File::Spec->catfile($path, $name . '.pid');

my $pid = -f $pidfile ? `cat $pidfile` : 0;
my $psinfo = "";
if ($pid) {
  $psinfo = `pstree -p $pid`;
}

my $meminfo = `free -m`;
my $load = `cat /proc/loadavg`;
my ($load1, $load5, $load15) = split /\s+/, $load;
my $diskinfo = `df -h`;

my @perls = $cfg->perls;
my $total_ndists;
my $distfile = $cfg->distribution_list_file;
if (defined $distfile and -e $distfile) {
  $total_ndists = `cat $distfile | wc -l`;
}

my @perl_names;
my @perl_unique_dists_done;
my @perl_total_dists_done;
my @perl_work_magnification_factor;
foreach my $perl (@perls) {
  push @perl_names, $perl->name;
  my $outdir = $perl->smoke_report_output_dir;
  my $unique = `find $outdir | perl -pe 's/(?:x86_64|i[36]68|armel).*\$//' | sort | uniq | wc -l`;
  my $total = `find $outdir | perl -pe 's/(?:x86_64|i[36]68|armel).*\$//' | wc -l`;
  chomp $_ for ($unique, $total);
  push @perl_unique_dists_done, $unique;
  push @perl_total_dists_done, $total;
  push @perl_work_magnification_factor, sprintf("%.2f", $total/($unique||1));
}


my $smokename = $cfg->name;
print <<HERE;
<html>
<head>
<title>Smoke status for $smokename</title>
</head>
<body>
<h1>Smoke status for $smokename</h1>
HERE

if ($psinfo) {
  print <<HERE
<h2>Smoke process info</h2>
<pre>
$psinfo
</pre>
HERE
}

print <<HERE;
<h2>Completion info</h2>
<table cellpadding="2" cellspacing="0" border="1">
<tr><th></th><th>Unique dist reports</th><th>Total dist reports</th><th>Work magnification</th></tr>
HERE
foreach my $iperl (0..$#perls) {
  my $name = 
  print <<HERE;
<tr><td>$perl_names[$iperl]</td>
  <td>$perl_unique_dists_done[$iperl]</td>
  <td>$perl_total_dists_done[$iperl]</td>
  <td>$perl_work_magnification_factor[$iperl]</td></tr>
HERE
}
print "</table>\n";

print <<HERE;
<h2>Machine health</h2>

<h3>Load</h3>
<p>
<table cellpadding="2" cellspacing="1" border="0">
<tr><th>1</th><th>5</th><th>15</th></tr>
<tr><td>$load1</td><td>$load5</td><td>$load15</td></tr>
</table>

<h3>Memory Usage (free -m)</h3>
<pre>
$meminfo
</pre>

<h3>Disk Usage (df -h)</h3>
<pre>
$diskinfo
</pre>
HERE

print <<HERE;
</body></html>
HERE

