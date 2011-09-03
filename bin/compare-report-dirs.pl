#!/usr/bin/env perl
# Mostly unchanged from David Golden's original script.
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
  Param("reference-dir", sub { -d } )->required,
  Param("test-dir", sub { -d } )->required,
  Param("output-dir", sub { 1 } )->required,
  #Param("list|L", sub { -r } )->required,
  # optional
  Switch("html"),
  Switch("help|h"),
  Switch("skip-missing"),
);

my $usage = << "ENDHELP";
usage: $0 <required options> <other options>

REQUIRED OPTIONS:
  --reference-dir       directory containing reports from reference perl
  --test-dir            directory containing reports from test perl
  --output-dir          output directory
  --list|-L   FILE      file with list of dists to test
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

my $output_dir = dir( $opt->get_output_dir )->absolute;
#my $list = file($opt->get_list)->absolute;
my $old_report_dir = dir($opt->get_reference_dir)->absolute;
my $new_report_dir = dir($opt->get_test_dir)->absolute;
my $skip_missing = $opt->get_skip_missing;

my $suffix = qr{\.(?:tar\.(?:bz2|gz|Z)|t(?:gz|bz)|(?<!ppm\.)zip|pm.gz)$}i; 

#my %mb_dists = map {
#  s{^.+/(.*)$suffix}{$1};
#  ( $_ => 1 )
#} $list->slurp( chomp => 1 );

my %old = read_results( $old_report_dir );
my %new = read_results( $new_report_dir );

warn "Results old: " . scalar(keys %old) . "\n";
warn "Results new: " . scalar(keys %new) . "\n";

my %all_dists = map { $_ => 1 } keys %old, keys %new;

warn "Total dists: " . scalar(keys %all_dists) . "\n";

my $html_fh;
if ( $opt->get_html ) {
  $output_dir->subdir("web-old")->rmtree;
  $output_dir->subdir("web-old")->mkpath;
  $output_dir->subdir("web-new")->rmtree;
  $output_dir->subdir("web-new")->mkpath;
  open $html_fh, ">", $output_dir->file("index.html");
  print {$html_fh} << 'HTML';
<html>
<head><title>Regression test</title>
<style>
  body { font-family:sans-serif; background-color: white }
  .grade    { text-align: center; font-weight:bold }
  .grade a  { text-decoration: none }
  .pass     { background-color: #00ff00 }
  .fail     { background-color: #ff0000 }
  .na       { background-color: orange }
  .unknown  { background-color: silver }
  .missing  { background-color: transparent }
</style>
</head>
<body><h1>Regresssion test</h1>
<table><tr><th>Old</th><th>New</ht><th>Dist</th></tr>
HTML
}
else {
  printf "%8s %8s %s\n", @$_ for ["  old  ", "  new  ", "dist"], [qw/------ ------ -------/];
}

for my $d ( sort keys %all_dists ) {
  #next unless exists $mb_dists{$d};
  next if exists $old{$d} && exists $new{$d} 
              && $old{$d}{grade} eq $new{$d}{grade};
  my $old_grade = $old{$d}{grade} || 'missing';
  my $new_grade = $new{$d}{grade} || 'missing';
  if ($skip_missing and $old_grade eq 'missing' || $new_grade eq 'missing') {
    next;
  }

  if ( $opt->get_html ) {
    my $old_path = exists $old{$d}{file} ? $old{$d}{file}->relative( $old_report_dir ) : '';
    my $new_path = exists $new{$d}{file} ? $new{$d}{file}->relative( $new_report_dir ) : '';
    my ($old_copy, $new_copy); 
    if ( $old_path ) { 
      $old_copy = $output_dir->subdir("web-old")->file($old{$d}{file}->basename . ".txt"); 
#      print "old: copying '$old{$d}{file}' to '$old_copy'\n";
      copy( "$old{$d}{file}" => "$old_copy" ) or die "copy failed: $!";
      $old_copy = $old_copy->relative( $output_dir );
    }
    if ( $new_path ) { 
      $new_copy = $output_dir->subdir("web-new")->file($new{$d}{file}->basename . ".txt"); 
#      print "new: copying '$new{$d}{file}' to '$new_copy'\n";
      copy( "$new{$d}{file}" => "$new_copy" ) or die "copy failed: $!";
      $new_copy = $new_copy->relative( $output_dir );
    }
    print {$html_fh} qq{<tr>\n};
    print {$html_fh} colorspan($old_grade, $old_copy);
    print {$html_fh} colorspan($new_grade, $new_copy);
    print {$html_fh} qq{  <td><a href="http://search.cpan.org/dist/$d">$d</a></td>\n</tr>\n};
  }
  else {
    printf "%8s %8s %s\n", $old_grade, $new_grade, $d;
  }
}

if ( $opt->get_html ) {
  print {$html_fh} "</table></body></html>\n";
  close $html_fh;
}

sub read_results {
  my ($dir) = @_;
  my %results;
  my @files = $dir->children;
  print scalar(@files) . " files to process...\n";
  my $i = 0;
  for my $f ( @files ) {
    ++$i;
    printf("  %.1f%%\n", $i/scalar(@files)*100) if not $i % 100;
    my $info = eval { get_report_info($f) };
    warn("Can't get report info for '$f'\n"), next if not $info;
    $results{ $info->{distribution} } = $info;
  }
  return %results;
}

sub colorspan {
  my ($grade, $path) = @_;
  my $color;
  return $path  ? qq{  <td class="grade $grade"><a href="$path">$grade</a></td>\n} 
                : qq{  <td class="grade $grade">$grade</td>\n};
}


