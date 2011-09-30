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

1;
