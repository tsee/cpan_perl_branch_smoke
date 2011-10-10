#!/usr/bin/env perl
# Based on David Golden's work.
use 5.010;
use strict;
use warnings;
use Path::Class;
use Getopt::Lucid qw/:all/;
use Test::Reporter;
use File::Copy qw/copy/;
use FindBin qw($RealBin);
use lib File::Spec->catdir($RealBin, File::Spec->updir, 'lib');
use MySmokeToolbox qw(get_report_info);

my @spec = (
  # required
  Param("config", sub { -r } )->required,
  List("perl_name|perl-name|perlname"),
  Param("output-dir", sub { 1 } )->required,
  # optional
  Switch("html"),
  Switch("help|h"),
  Switch("skip-missing"),
);

my $usage = << "ENDHELP";
usage: $0 <required options> <other options>

REQUIRED OPTIONS:
  --config              path to the configuration YAML file
  --perl-name           names of perl smokes to compare (see config).
                        must occurr at least twice
  --output-dir          output directory
  --skip-missing        skip all dists where either one of the perls
                        is missing the report

OTHER OPTIONS:
  --html                generate a index.html file with results
  --help|-h             usage guide
ENDHELP

# XXX nasty hack until Getopt::Lucid has better help
if ( grep { /^(?:--help|-h)$/ } @ARGV ) {
  print STDERR "$usage\n" and exit
}

my $opt = Getopt::Lucid->getopt( \@spec );

my $configfile = $opt->get_config;
my $cfg = MySmokeToolbox::SmokeConfig->new($configfile);
my @perlnames = $opt->get_perl_name;
if (@perlnames == 1) {
  die "Need at least two perl smokes to compare (use --perl-name=...)\n";
}
elsif (@perlnames == 0) {
  @perlnames = map $_->name, $cfg->perls;
}

my $skip_missing = $opt->get_skip_missing;

my $output_dir = dir( $opt->get_output_dir )->absolute;
my @perlspecs = map $cfg->perl($_), @perlnames;
my @report_dirs = map dir($_->smoke_report_output_dir)->absolute, @perlspecs;

# array of hashrefs containing distname => infohash
my @results = map +{read_results($_)}, @report_dirs;

foreach my $iperl (0.. $#perlspecs) {
  warn "Number of results for '" . $perlspecs[$iperl]->name . "': " . scalar(keys(%{$results[$iperl]})) . "\n";
}

my %all_dists;
foreach my $result (@results) {
  $all_dists{$_} = 1 for keys %$result;
}

warn "Total dists: " . scalar(keys %all_dists) . "\n";

my @web_report_outdirs;
my $html_fh;
if ( $opt->get_html ) {
  @web_report_outdirs = map $output_dir->subdir("web-" . $_->name), @perlspecs;
  $_->rmtree, $_->mkpath for @web_report_outdirs;

  open $html_fh, ">", $output_dir->file("index.html");
  my $timestamp = localtime();

  print {$html_fh} <<"HTML";
<html>
<head><title>Regression test</title>
<style>
  body { font-family:sans-serif; background-color: white }
  .grade    { text-align: center; font-weight:bold }
  .statstd  { text-align: center }
  .grade a  { text-decoration: none }
  .pass     { background-color: #00ff00 }
  .fail     { background-color: #ff0000 }
  .na       { background-color: orange }
  .unknown  { background-color: silver }
  .missing  { background-color: transparent }
</style>
</head>
<body><h1>Regresssion test</h1>
<p>Generated at $timestamp.</p>
<table><tr>
HTML
  foreach my $perl (@perlspecs) {
    print {$html_fh} "<th>" . $perl->name . "</th>";
  }
  print {$html_fh} "<th>Distribution</th></tr>\n";
}
else {
  for ([map {substr($_, 0, 8)} ((map $_->name, @perlspecs), "dist")], [('------') x scalar(@perlspecs), '-------']) {
    printf(
      ("%8s " x scalar(@perlspecs)) . "%s\n",
      @$_
    );
  }
}

my $nexist_all = 0; # dists in all datasets
my $nexist_multi = 0; # dists in multiple datasets
my $nsame = 0; # identical results across all perls
my $ndiff = 0; # different results for at least one perl
# Number of identical / differing results per perl-perl combination
my @pairwise_nsame = map [(0) x scalar(@perlspecs)], (0..$#perlspecs); # matrix
my @pairwise_ndiff = map [(0) x scalar(@perlspecs)], (0..$#perlspecs); # matrix
# Number of missing distribitions per perl
my @nmissing = ((0) x scalar(@perlspecs)); # vector

# FIXME by turning the data structures inside out, this could become much faster...

# One grade hash per perl
my @dist_grades = map +{}, @perlspecs;
for my $d ( sort keys %all_dists ) {
  my @grades = map $results[$_]{$d}{grade}, (0..$#perlspecs);

  foreach my $iperl (0..$#perlspecs) {
    if (defined $grades[$iperl]) {
      $dist_grades[$iperl]{ $grades[$iperl] }++;
    }
  }

  # Gather some stats
  my $this_nmissing = 0;
  foreach my $iperl (0..$#perlspecs) {
    if (not defined($grades[$iperl])) {
      ++$this_nmissing;
      ++$nmissing[$iperl];
    }

    foreach my $iperl2 (0.. $#perlspecs) {
      my $increment_ary;
      if (!defined($grades[$iperl])) {
        $increment_ary = !defined($grades[$iperl2]) ? \@pairwise_nsame : \@pairwise_ndiff;
      }
      else { # $iperl defined
        $increment_ary = !defined($grades[$iperl2]) ? \@pairwise_ndiff : \@pairwise_nsame;
      }

      ++$increment_ary->[$iperl][$iperl2];
      #++$increment_ary->[$iperl2][$iperl];
    }
  }

  ++$nexist_all if $this_nmissing == 0;
  ++$nexist_multi if scalar(@perlspecs) - $this_nmissing >= 2;

  # Skip if we just have one result and --skip-missing
  next if $skip_missing and $this_nmissing == @grades-1;

  my $firstgrade;
  SCOPE: {
    my $gradeno = 0;
    while (!defined($firstgrade)) {
      $firstgrade = $grades[$gradeno++];
    }
  }

  # Skip all dists that have consistently the same result
  if ($skip_missing
      and (@grades-$this_nmissing)
          == scalar(grep defined($_) && $_ eq $firstgrade, @grades))
  {
    ++$nsame, next;
  } elsif (@grades == scalar(grep defined($_) && $_ eq $firstgrade, @grades)) {
    ++$nsame, next;
  }
  ++$ndiff;

  $_ ||= 'missing' for @grades;

  if ( $opt->get_html ) {
    my @rel_report_paths = map { exists $results[$_]{$d}{file} ? $results[$_]{$d}{file}->relative($report_dirs[$_]) : '' } (0..$#perlspecs);

    # make the actual report text files available in the output dir
    my @file_copies;
    foreach my $ipath (0..$#rel_report_paths) {
      next if not $rel_report_paths[$ipath];
      $file_copies[$ipath] = $web_report_outdirs[$ipath]->file($results[$ipath]{$d}{file}->basename . ".txt");
      copy( "" . $results[$ipath]{$d}{file} => $file_copies[-1] ) or die "copy failed: $!";
      $file_copies[-1] = $file_copies[-1]->relative( $output_dir );
    }
    print {$html_fh} qq{<tr>\n};

    foreach my $iperl (0..$#perlspecs) {
      print {$html_fh} colorspan($grades[$iperl], $file_copies[$iperl]);
    }

    print {$html_fh} qq{  <td><a href="http://search.cpan.org/dist/$d">$d</a></td>\n</tr>\n};
  }
  else {
    printf( ("%8s " x scalar(@perlspecs)) . "%s\n", @grades, $d);
  }
}

if ( $opt->get_html ) {
  print {$html_fh} "</table>\n";

  print {$html_fh} <<HERE;
<p>
  Distributions in all data sets: $nexist_all<br/>
  Distributions in at least two sets: $nexist_multi<br/>
  Distributions with identical grade across all perls: $nsame<br/>
  Distributions with differing grade in some perls: $ndiff<br/>
</p>
<p>
  No. of distributions missing from each perl:<br/>
  <table border="1" cellpadding="2" cellspacing="0">
    <tr>
HERE

  print {$html_fh} "    <th>" . $_->name . "</th>" for @perlspecs;
  print {$html_fh} "</tr>\n    <tr>";
  print {$html_fh} "<td>$_</td>" for @nmissing;
  print {$html_fh} <<HERE;
    </tr>
  </table>
</p>
HERE

  my %grades;
  foreach my $gradeset (@dist_grades) {
    $grades{$_} += $gradeset->{$_} for keys %$gradeset;
  }
  my @grades = sort keys %grades;

  print {$html_fh} <<HERE;
<h3>Total numbers of distribution test grades</h3>
<table border="1" cellpadding="2" cellspacing="0">
<tr><th>perl</th>
HERE

  print {$html_fh} (map qq{<th class="grade $_">$_</th>}, @grades), "</tr>\n";

  my @rows = (
    (map [$perlspecs[$_]->name, $dist_grades[$_]], 0..$#perlspecs),
    ['total', \%grades]
  );
  foreach my $s (@rows)
  {
    my ($thisrow_name, $thisrow_grades) = @$s;
    my $nthisrow = 0;
    $nthisrow += $_||0 for values %{$thisrow_grades};

    print {$html_fh} "<tr><th>$thisrow_name</th>";
    foreach (@grades) {
      print {$html_fh} '<td class="statstd">' . sprintf("%i (%.0f%%)", $thisrow_grades->{$_}||0, 100*($thisrow_grades->{$_}||0)/$nthisrow) . "</td>";
    }
    print {$html_fh} "</tr>\n";
  }
  print {$html_fh} "</table>\n";

  print {$html_fh} "<h3>Pairwise numbers of differing grades</h3>\n";
  my @perlnames = map $_->name, @perlspecs;
  matrix_html_table($html_fh, \@perlnames, \@perlnames, \@pairwise_ndiff, "statstd");

  print {$html_fh} "<h3>Pairwise numbers of matching grades</h3>\n";
  matrix_html_table($html_fh, \@perlnames, \@perlnames, \@pairwise_nsame, "statstd");

  print {$html_fh} "</body></html>\n";
  close $html_fh;
}



#########################################################

sub read_results {
  my ($dir) = @_;
  my %results;
  #my @files = $dir->children; # SLOOOOW
  # This may not be as portable, but seriously, Path::Class && File::Spec are slow as molasses
  my $dirstr = "$dir";
  opendir my $dh, $dirstr or die $!;
  my @files = grep -f, map "$dirstr/$_", readdir($dh);
  closedir($dh);
  print scalar(@files) . " files to process...\n";
  my $i = 0;
  for my $f ( @files ) {
    ++$i;
    printf("  %.1f%%\n", $i/scalar(@files)*100) if $i % 1000 == 0;
    my $info = eval { get_report_info($f) };
    $info->{file}=file($info->{file});
    warn("Can't get report info for '$f'\n"), next if not $info;
    #if (exists $results{$info->{distribution}}) {
    #  warn "Duplicate dist: " . $info->{distribution};
    #}
    $results{ $info->{distribution} } = $info;
  }
  return %results;
}

sub colorspan {
  my ($grade, $path) = @_;
  my $color;
  return defined($path)
          ? qq{  <td class="grade $grade"><a href="$path">$grade</a></td>\n}
          : qq{  <td class="grade $grade">$grade</td>\n};
}

sub matrix_html_table {
  my $fh = shift;
  my $coltitles = shift;
  my $rowtitles = shift;
  my $matrix = shift;
  my $cssclass = shift;
  my $classstr = defined($cssclass) ? qq{ class="$cssclass"} : "";

  print {$fh} qq{<table cellspacing="0" border="1" cellpadding="2"><tr><th$classstr> </th>},
              (map "<th$classstr>$_</th>", @$coltitles), "</tr>";
  foreach my $irow (0..$#$matrix) {
    my $row = $matrix->[$irow];
    print {$fh} "<tr><th$classstr>$rowtitles->[$irow]</th>",
                (map "<td$classstr>$_</td>", @$row), "</tr>";
  }
  print {$fh} qq{</table>\n};
}
