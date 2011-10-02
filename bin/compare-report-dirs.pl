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

#my $nsame = 0;
#my $nmissing = 0;
#my $ndiff = 0;

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
  
  my $this_nmissing = scalar(grep !defined, @grades);

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
  next if (@grades-$this_nmissing) == scalar(grep defined($_) && $_ eq $firstgrade, @grades);

  #++$nsame, next if exists $old{$d} && exists $new{$d} 
  #                  && $old{$d}{grade} eq $new{$d}{grade};

  $_ ||= 'missing' for @grades;

  #my $old_grade = $old{$d}{grade} || 'missing';
  #my $new_grade = $new{$d}{grade} || 'missing';
  #if ($skip_missing and $old_grade eq 'missing' || $new_grade eq 'missing') {
  #  ++$nmissing;
  #  next;
  #}
  #++$ndiff;

  if ( $opt->get_html ) {
    my @rel_report_paths = map { exists $results[$_]{$d}{file} ? $results[$_]{$d}{file}->relative($report_dirs[$_]) : '' } (0..$#perlspecs);

    # make the actual report text files available in the output dir
    my @file_copies;
    foreach my $ipath (0..$#rel_report_paths) {
      next if not $rel_report_paths[$ipath];
      push @file_copies, $web_report_outdirs[$ipath]->file($results[$ipath]{$d}{file}->basename . ".txt");
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

=for comment

if ( $opt->get_html ) {
  print {$html_fh} "</table>\n";

  my %grades = map {$_=>1} (keys %$dist_grades_old, keys %$dist_grades_new);
  my @grades = sort keys %grades;
  my %grade_totals = map {$_ => ($dist_grades_new->{$_}||0) + ($dist_grades_old->{$_}||0)} @grades;

  print {$html_fh} <<HERE;
<p>
  Distributions in both data sets: $nsame<br/>
  Distributions missing in one data set: $nmissing<br/>
  Distributions that differ: $ndiff
</p>

<h3>Total numbers of distribution test grades</h3>
<table border="1" cellpadding="2" cellspacing="0">
<tr><th>perl</th>
HERE

  print {$html_fh} (map qq{<th class="grade $_">$_</th>}, @grades), "</tr>\n";

  foreach my $s ( ['old', $dist_grades_old],
                  ['new', $dist_grades_new],
                  ['total', \%grade_totals], )
  {
    my $nthisrow = 0;
    $nthisrow += $_||0 for values %{$s->[1]};

    print {$html_fh} "<tr><th>$s->[0]</th>";
    foreach (@grades) {
      print {$html_fh} '<td class="statstd">' . sprintf("%i (%.0f%%)", $s->[1]{$_}||0, 100*($s->[1]{$_}||0)/$nthisrow) . "</td>";
    }
    print {$html_fh} "</tr>\n";
  }
  print {$html_fh} "</table>\n";

  print {$html_fh} "</body></html>\n";
  close $html_fh;
}

=cut


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


