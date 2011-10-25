package
  MySmokeToolbox::SmokeConfig;
use strict;
use warnings;
use YAML::Tiny (); # We ship this.
use Carp qw(croak);
use MySmokeToolbox::SmokeConfig::Perl;

sub new {
  my $class = shift;
  my $src = shift;
  croak("Invalid parameters") if not defined $src;

  my $self;
  if (ref($src) eq 'SCALAR') {
    $self = YAML::Tiny::Load($$src);
  }
  elsif (not ref($src)) {
    $self = YAML::Tiny::LoadFile($src);
  }
  else {
    croak("Invalid ref passed to constructor");
  }
  $self = $self->[0] if ref($self) eq 'ARRAY';

  $self = bless($self => $class);
  return $self;
}

sub name { $_[0]->{name} }
sub perl_git_remote { $_[0]->{"perl-git-remote"} }
sub cpan_mirror { $_[0]->{"cpan-mirror"} }
sub perl_install_base { $_[0]->{"perl-install-base"} }
sub smoke_report_output_base { $_[0]->{"smoke-report-output-base"} }
sub smoke_processes_per_perl { $_[0]->{"smoke-processes-per-perl"} }

SCOPE: {
  my $tmpdir;
  sub tmpdir {
    my $self = shift;
    return $tmpdir if defined $tmpdir;

    foreach my $test ($self->{tmpdir}, File::Spec->tmpdir) {
      if (defined $test and -r $test) {
        $tmpdir = $test;
        return $tmpdir;
      }
    }
    die "Failed to figure out temp directory"
  }
} # END SCOPE

sub perl {
  my $self = shift;
  my $perlname = shift;
  croak("need perl name!") if not defined $perlname;

  my @matching = grep $_->{'perl-name'} eq $perlname, @{$self->{perls}};
  croak("Unknown perl '$perlname'") if not @matching;
  croak("Multiple perls of name '$perlname'. That makes no sense.") if @matching > 1;

  return MySmokeToolbox::SmokeConfig::Perl->_new($self, $matching[0]);
}

sub perls {
  my $self = shift;
  return map MySmokeToolbox::SmokeConfig::Perl->_new($self, $_), @{$self->{perls}};
}

sub assert_perl_install_base {
  my $self = shift;
  $self->_assert_dir($self->perl_install_base);
}

sub assert_smoke_report_output_base {
  my $self = shift;
  $self->_assert_dir($self->smoke_report_output_base);
}

sub _assert_dir {
  require File::Path;
  File::Path::mkpath($_[1]);
  return 1;
}

sub distribution_list_file {
  my $self = shift;
  my $smoke_out = $self->smoke_report_output_base;
  return File::Spec->catfile($smoke_out, $self->name, 'smoke_distributions.txt');
}

sub assert_distribution_list_file {
  my $self = shift;
  my $file = $self->distribution_list_file;
  return() if -e $file;
  MySmokeToolbox::MakeDistList->make_dist_list($self->cpan_mirror, $self->distribution_list_file);
}

1;

__END__

=head1 NAME

MySmokeToolbox::SmokeConfig - Object representing the smoke configuration

=head1 SYNOPSIS

  use MySmokeToolbox::SmokeConfig;
  my $cfg = MySmokeToolbox::SmokeConfig->new('smokeconfig.yml');
  # or ->new(\$smokeconfig_content) to load from a string

=head1 DESCRIPTION

Instances of this class represent a full CPAN smoke configuration including
any number of perls to test.

=head1 METHODS

=head2 new

Creates a new configuration object. Requires either a path to a YAML configuration
file or a reference to a scalar containing the YAML.

=head2 name, perl_git_remote, cpan_mirror, perl_install_base,
smoke_report_output_base, smoke_processes_per_perl

Simple accessors to the YAML configuration properties of the same names
(with dashes replaced by underscores).

=head2 tmpdir

Returns the path to the temporary directory to use for this smoke.
This defaults to C<File::Spec-E<gt>tmpdir> if not configured using the
C<tmpdir> property in the YAML.

The path does not necessarily exist.

=head2 perls

Returns all L<MySmokeToolbox::SmokeConfig::Perl> objects in this configuration
in the order they're defined in the YAML configuration.

This creates new objects, any modifications done to objects returned by
previous invocations won't be included.

=head2 perl

Takes the name of a perl as configured in the YAML configuration.
Returns the corresponding L<MySmokeToolbox::SmokeConfig::Perl> object.

Like C<perls()>, this creates a new object per invocation.

=head2 assert_perl_install_base

Creates the perl installation base path if it does not exist.

=head2 assert_smoke_report_output_base

Creates the smoke report output base path if it does not exist.

=head2 distribution_list_file

Returns the path to the text file containing the distributions
to smoke.

=head2 assert_distribution_list_file

If the distribution list file doesn't exist, this will
generate it from 02packages in the configured minicpan.

=head1 AUTHOR

Steffen Mueller C<E<gt>smueller@cpan.orgE<lt>>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

