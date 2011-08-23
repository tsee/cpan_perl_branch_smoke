#!/usr/bin/env perl
use strict;
use warnings;
my $packages_file = shift or die;

open my $fh, 'gzip -d -c ' . $packages_file . ' |' or die $!;
my %dists;
while (1) {
  last if <$fh> =~ /^\s*$/;
}
while (<$fh>) {
  chomp;
  /^\S+\s+\S+\s+(.*)$/ or next;
  $dists{$1}++;
}
close $fh;
print "$_\n" for sort keys %dists;
