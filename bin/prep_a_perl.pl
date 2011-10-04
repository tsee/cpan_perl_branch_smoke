#!/usr/bin/env perl
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use FindBin qw($RealBin);

use lib File::Spec->catdir($RealBin, File::Spec->updir, 'lib');
use MySmokeToolbox qw(make_work_dir can_run runsys runsys_fatal);

use File::Path qw(mkpath);
use File::pushd qw(pushd);
use ExtUtils::MakeMaker ();

my $GitCmd = 'git';
if (not can_run($GitCmd)) {
  die "Cannot run '$GitCmd'. Please make sure you have a working git in your PATH.";
}

GetOptions(
  my $opt = {},
  'config=s',
  'local_repo|local-repo|localrepo=s',
  'perl_name|perl-name|perlname=s@',
  'no_test|no-test|notest'                                => \(my $no_test),
) or die "Invalid options";

my $cfg = MySmokeToolbox::SmokeConfig->new($opt->{config});

my @perlnames;
if (not defined $opt->{perl_name} or not ref($opt->{perl_name}) eq 'ARRAY') {
  @perlnames = map $_->name, $cfg->perls;
}
else {
  @perlnames = @{$opt->{perl_name}};
}
my @perls = grep defined($_->smoke_branch), map $cfg->perl($_), @perlnames;

if (not defined $cfg->perl_git_remote and not defined $opt->{local_repo}) {
  die "Need either git-remote from config or local-repo option";
}

$cfg->assert_perl_install_base;
my $workdir = make_work_dir();

# get a perl repo one way or another
my $perl_repo_dir;
if (defined $opt->{local_repo}) {
  # update
  if (-d $opt->{local_repo} and -d File::Spec->catdir($opt->{local_repo}, '.git'))
  {
    git_run($opt->{local_repo}, 'fetch');
  }
  else { # setup in specific path and keep around
    File::Path::mkpath($opt->{local_repo});
    $perl_repo_dir = setup_git_clone($cfg->perl_git_remote, $opt->{local_repo});
  }
}
else {
  # temporary
  $perl_repo_dir = setup_git_clone($cfg->perl_git_remote, File::Spec->catdir($workdir, 'perl-clone'));
}

foreach my $perlcfg (@perls) {
  print "Processing perl '" . $perlcfg->name . "'...\n";
  # clean repo
  git_run($perl_repo_dir, 'clean', '-dxf');

  # checkout smoke branch
  git_run($perl_repo_dir, 'checkout', '--force', $perlcfg->smoke_branch);

  print "Using perl source tree from: $perl_repo_dir\n";

  # install perl into perl-base
  my $install_dir = $perlcfg->install_dir;
  install_a_perl($perl_repo_dir => $install_dir, [$perlcfg->grindperl_opt]);

  # create symlinks
  setup_perl_exe_links($install_dir);

  # install prerequisites
  runsys_fatal(
    $^X,
    File::Spec->catfile($RealBin, 'install_prereqs.pl'),
    '--config' => $opt->{config},
    '--perl_name', $perlcfg->name,
    #'--mirror', $cfg->cpan_mirror,
    ($no_test ? ('--no-test') : ()),
  );
}

exit(0);

#########

sub install_a_perl {
  my ($srcdir, $targetdir, $opt) = @_;

  my $d = pushd($srcdir);
  my @cmd = (
    'grindperl',
    ($opt ? @$opt : ()),
    '--porting',
    '--install',
    '--prefix' => $targetdir,
  );
  runsys(@cmd);
  if (not -d $targetdir or not glob(File::Spec->catfile($targetdir, 'bin', 'perl*'))) {
    die "Seems like we failed to properly install this perl";
  }
}

sub setup_perl_exe_links {
  my $perldir = shift;
  my $bindir = File::Spec->catdir($perldir, 'bin');
  return if not eval { symlink("",""); 1 };

  die "Could not find perl binaries directory for symlinking '$bindir'" if not -d $bindir;
  my $d = pushd($bindir);
  my @files = glob("*5.*");
  foreach my $file (@files) {
    my $target = $file;
    $target =~ s/5\.\d+\.\d+$//;
    symlink($file, $target); # this can fail
  }
}

sub setup_git_clone {
  my ($remote, $target_dir) = @_;

  runsys_fatal($GitCmd, 'clone', $remote, $target_dir);
  
  if (not -d $target_dir or not -d File::Spec->catdir($target_dir, '.git')) {
    die "After git clone, target directory '$target_dir' "
      . "does not exist or is not a git repository";
  }

  return $target_dir;
}


sub git_run {
  my ($repo_path, @args) = @_;
  croak("Undefined or nonexistent perl reposority path") if not defined $repo_path or not -d $repo_path;
  my $p = pushd($repo_path);
  runsys_fatal($GitCmd, @args);
}

