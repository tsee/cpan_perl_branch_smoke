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
  return File::Spec->catdir($self->_parent->perl_install_base, 'perl-' . $self->name);
}
sub executable {
  my $self = shift;
  return File::Spec->catfile($self->install_dir, 'bin', 'perl');
}

sub grindperl_opt {
  my $self = shift;
  my $opt = $self->{"grindperl-opt"}||[];
  return() if not defined $opt;
  return($opt) if not ref($opt);
  return @$opt;
}

sub _parent {$_[0]->{_parent}}
1;
