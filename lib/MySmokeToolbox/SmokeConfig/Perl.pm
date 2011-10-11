package
  MySmokeToolbox::SmokeConfig::Perl;
use strict;
use warnings;
use YAML::Tiny (); # We ship this.
use Carp qw(croak);
use File::Spec;

sub _new {
  my $class = shift;
  my $parent = shift;
  my $hashref = shift;
  my $self = bless({%$hashref, _parent => $parent} => $class);
  eval { # paranoid.
    require Scalar::Util;
    Scalar::Util::weaken($self->{_parent});
  };
  return $self;
}

sub name { $_[0]->{"perl-name"} }
sub smoke_branch { $_[0]->{"smoke-branch"} }

sub install_dir {
  my $self = shift;
  # $basedir/$smokename/perl-$perlname
  return File::Spec->catdir($self->_parent->perl_install_base, $self->_parent->name, 'perl-' . $self->name);
}
sub executable {
  my $self = shift;
  if (defined $self->{executable}) {
    return $self->{executable};
  }
  return File::Spec->catfile($self->install_dir, 'bin', 'perl');
}
sub has_explicit_executable {
  my $self = shift;
  return defined $self->{executable};
}

sub smoke_report_output_dir {
  my $self = shift;
  # $basedir/$smokename/$perlname
  return File::Spec->catdir($self->_parent->smoke_report_output_base, $self->_parent->name, $self->name);
}

sub assert_smoke_report_output_dir {
  my $self = shift;
  $self->_parent->_assert_dir($self->smoke_report_output_dir);
}

sub grindperl_opt {
  my $self = shift;
  my $opt = $self->{"grindperl-opt"}||[];
  return($opt) if not ref($opt);
  return @$opt;
}

sub _parent {$_[0]->{_parent}}
1;

__END__

=head1 NAME

MySmokeToolbox::SmokeConfig::Perl - Object representing a single perl in a CPAN smoke

=head1 SYNOPSIS

  use MySmokeToolbox::SmokeConfig;
  my $cfg = MySmokeToolbox::SmokeConfig->new('smokeconfig.yml');
  my $perl = $cfg->perl($name); # or $cfg->perls to get all

=head1 DESCRIPTION

Instances of this class represent a single perl installation in a full
CPAN smoke configuration. You should create objects of this class
directly but instead use the C<perl($name)> and C<perls()> methods of
L<MySmokeToolbox::SmokeConfig> to get instances.

=head1 METHODS

=head2 name, smoke_branch

Simple accessors to the YAML configuration properties of the same names
(with dashes replaced by underscores).

=head2 install_dir

Returns the path to the perl installation directory. In a nutshell:

  $basedir/$smokename/perl-$perlname

=head2 executable

Returns the path of the perl executable.
If explicitly defined in the YAML configuration, returns that value,
otherwise constructs it from the installation directory.

=head2 has_explicit_executable

Returns whether or not there is an explicit executable configured for
this perl.

=head2 smoke_report_output_dir

Returns the output path for smoke reports for this perl.

=head2 assert_smoke_report_output_dir

Creates the smoke report output directory if it does not exist.

=head2 grindperl_opt

Returns the C<grindperl_opt> setting from the YAML file with some minor
modification: If the setting is undef, this returns the empty list.
It it's an array reference, this returns a list, if it's a scalar/string,
it returns that string.

=head1 AUTHOR

Steffen Mueller C<E<gt>smueller@cpan.orgE<lt>>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

