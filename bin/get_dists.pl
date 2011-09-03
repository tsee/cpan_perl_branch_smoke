#!/usr/bin/env perl
use strict;
use warnings;
my $packages_file = shift or die;

open my $fh, 'gzip -d -c ' . $packages_file . ' |' or die $!;
my %dists;
while (1) {
  last if <$fh> =~ /^\s*$/;
}
my $blacklist = '\b'
                . join('|', map { chomp; s/^\s+//; s/#.*$//; s/\s+$//; /\S/ ? "(?:" . quotemeta($_) . ")" : () } <DATA>)
                . '-[v0-9]';


while (<$fh>) {
  chomp;
  /^\S+\s+\S+\s+(.*)$/ or next;
  my $d = $1;
  warn("Blacklisted: $d\n"), next if $d =~ $blacklist;
  $dists{$d}++;
}
close $fh;
print "$_\n" for sort keys %dists;

__DATA__

Inline-Octave # reads from STDIN during Makefile.PL
