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
  'git-remote|git_remote|gitremote=s'                     => \(my $git_remote),
  'local-repo|local_repo|localrepo=s'                     => \(my $local_repo),
  'smoke-branch|smoke_branch|smokebranch=s'               => \(my $smoke_branch),
  'smoke-name|smoke_name|smokename=s'                     => \(my $smoke_name),
  'perl-install-base|perl_install_base|perlinstallbase=s' => \(my $perl_install_base),
  'grindperl-opt|grindperl_opt|grindperlopt=s'            => \(my @perl_opt),
) or die "Invalid options";

foreach my $req ([$smoke_branch, 'smoke-branch'],
                 [$smoke_name, 'smoke-name'],
                 [$perl_install_base, 'perl-install-base'], )
{
  die "The '--$req->[1]' parameter is required" if not defined $req->[0];
}

if (not defined $git_remote and not defined $local_repo) {
  die "Need either git-remote or local-repo options";
}

mkpath($perl_install_base);
my $workdir = make_work_dir();

# get a perl repo one way or another
my $perl_repo_dir;
if (defined $local_repo) {
  # update
  if (-d $local_repo and -d File::Spec->catdir($local_repo, '.git'))
  {
    git_run($local_repo, 'fetch');
  }
  else { # setup in specific path and keep around
    File::Path::mkpath($local_repo);
    $perl_repo_dir = setup_git_clone($git_remote, $local_repo);
  }
}
else {
  # temporary
  $perl_repo_dir = setup_git_clone($git_remote, File::Spec->catdir($workdir, 'perl-clone'));
}

# clean repo
git_run($perl_repo_dir, 'clean', '-dxf');

# checkout smoke branch
git_run($perl_repo_dir, 'checkout', '--force', $smoke_branch);

print "Using perl source tree from: $perl_repo_dir\n";

# install perl into perl-base
my $install_dir = File::Spec->catdir($perl_install_base, 'perl-' . $smoke_name);
install_a_perl($perl_repo_dir => $install_dir, \@perl_opt);

# install prerequisites

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
  my @files = glob("*.5*");
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
  croak("Undefined or nonexistent perl repoisority path") if not defined $repo_path or not -d $repo_path;
  my $p = pushd($repo_path);
  runsys_fatal($GitCmd, @args);
}

