#!/usr/bin/env perl
use strict;
use warnings;
my $packages_file = shift or die;

open my $fh, 'gzip -d -c ' . $packages_file . ' |' or die $!;
my %dists;
while (1) {
  last if <$fh> =~ /^\s*$/;
}

my @bl = <DATA>;
my @regexp = map {s/^REGEXP:\s*//; s/#.*$//; s/\s+$//; $_} grep /^REGEXP:/, @bl;

my $blacklist = '(?:\b'
                . join('|', map { chomp; s/^\s+//; s/#.*$//; s/\s+$//; /\S/ ? "(?:" . $_ . ")" : () } grep !/^REGEXP:/, @bl)
                . '-[v0-9])|'
                . join('|', map "(?:$_)", @regexp);

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

#Most of these are from Andreas Koenig's smoker.
Inline-Octave # reads from STDIN during Makefile.PL
Net-CLI-Interact # hangs
Net-Whois-IANA # endless loop in testing
REGEXP: \bLingua-PT-Speaker-0\.10\.tar\.gz$ # does not use prompt() and no $|
Acme-Mom-Yours # blocks the smoker for too long
Perl-Dist # Andreas says: probably removed all my Config.pms (?)
ThreatNet-IRC # RT 33544
Test-MockDBI # asks for DSN, user, etc.
OpenResty # 0.3.8 hangs after 'cp etc/openresty.conf etc/site-openresty.conf'
Dir-ListFilesRecursive # Deep recursion with high memory consumption
Geo-Raster # requires Raster Algebra Library, no debian package (?)
PerlCryptLib # hangs when searching header files
REGEXP: \bTemplate-Plugin-Latex-3.*\.tar\.gz$ # hangs with 3.02
WWW-Patent-Page # downloads something largish
Bundle-POE-All # broken idea of what a bundle is
ASNMTAP # switches to cpanplus and then hangs
REGEXP: \bDBD-SQLite-Amalgamation-3\.5\.8\.tar\.gz$ # test t/08create_functionhangs with 33430
Sendmail-PMilter # asks questions
App-Control # endless loop
sitemapper # questions
FlatFile-DataStore # hangs after t/FlatFile-DataStore-Toc.t
Device-RFXCOM # spits out EV: error in callback (ignoring): closed at t/01-rx.t line 116
MojoX-Run # hangs with 5.14.0-382
Module-Install-AutoLicense # hangs with 5.14.0-357
POE-Component-SmokeBox # hangs
DBIx-Perform # curses login (?)
XSDSQL_ # hangs with high memory usage
Catalyst-Authentication-Store-LDAP # hangs
REGEXP: \bNet-Proxy-0\.12\.tar\.gz$ # hangs quite often, not always
Audio-Ecasound # hangs very early: RT 32101
parrot
REGEXP: \bIPC-Shareable-0\.60\.tar\.gz$       # hangs
REGEXP: \bWWW-Blog-Metadata-0\.02\.tar\.gz$           # ExtUtils::AutoInstall 0.56 http://rt.cpan.org/Ticket/Display.html?id=40601
Chart-Graph #  hangs Makefile.PL: RT 33541
REGEXP: \bWWW-Salesforce # demands username and passwd
Task-BeLike-Cebjyre       # hangs somewhere
Games-Sudoku-SudokuTk # hangs: seen with 0.07 and 0.09
BioPerl   # asks questions
AxKit-XSP #  looped in a readline
Net-FTPSSL # asks questions during test without prompt()
MozRepl-RemoteObject       # hangs after 01-array.t
REGEXP: \bWWW-Mechanize-Shell-0\.[45]\.tar\.gz$       # hangs every so often in t/13-command-au.t
CursesForms
CursesWidgets
REGEXP: \bTest-Perl-Dist-0\.300\.tar\.gz # tells me that Win32 is missing and then stands still
REGEXP: \bTie-Quicksort-Lazy-0\.02\.tar\.gz # endless loop
Business-Shipping          # asks questions
REGEXP: \bTk-ObjEditor-2\.004\.tar\.gz$       # http://rt.cpan.org/Ticket/Display.html?id=29559
Text-MeCab                        # hangs asking questions
CGI-Wiki                        # asks database questions
WWW-BBB-API             # asks questions
REGEXP: \bProc-PID-File-1\.24\.tar\.gz$       # hangs during test.pl
REGEXP: \bText-GenderFromName-0\.32\.tar\.gz$   # bad prompt
REGEXP: \bMARC-Errorchecks-1\.13\.tar\.gz$     # complicated interactivity in make test
XUL-Node               # asks for port -- 8077?
REGEXP: (?:^|/)MOBY-.*\.gz$  # hangs
XML-SAX-RTF            # harmful: http://rt.cpan.org/Public/Bug/Display.html?id=5943
REGEXP: \bHTTP-Server-Simple-Er-v0\.0\.3\.tar\.gz$ # hangs on some perls
PNI-Node-Tk # hangs after t/PNI-Node-Tk.t
threads-emulate    # hangs in 00-load.t on 32642
REGEXP: \bAlien-SDL-1\.418\.tar\.gz$                  # questions
FreeHAL                                 # David Cantrell warns that it is a 137 MB thingy
Net-SNMP-Mixin            # asks questions about SNMP server
WebService-Upcoming             # for members only
REGEXP: \bOcsinventory-Agent-0\.0\.8\.tar\.gz$  # hangs
Ocsinventory-Agent           # hanger
DBIx-Recordset            # hangs
POE-Component-DirWatch     # the 03editedfile or so seems to take forever
Net-Server-Mail          # hangs
POE-Quickie                 # test hangs
REGEXP: \bBot-Net-0\.1\.0\.tar\.gz$                 # hangs during test t/TestNet/t/atoz-peer.t
Mail-Salsa                   # hangs/asks for installation directory
Catalyst-Example-InstantCRUDStylish # uninterruptible and demanding but maybe not his fault
LedgerSMB-API               # 0.04a nearly unstoppable endless loop
POE-Filter-Hessian        # hangs
REGEXP: \bCatalyst-Log-Log4perl-1\.00\.tar\.gz$ # endless loop with deep recursion
X3D                   # hangs at t/nodefield_sfdouble_06 on perl-5.10.0 at 33955
Nagios-WebTransact        # asks for a server and port
DbFramework                # asks questions but I have not time
REGEXP: \barclog-3\.\d                      # one test (01-exhaust) hangs with several perls
PPM-Make                 # asks questions
Module-New             # hangs after 00_load.t
Business-OnlinePayment-eSelectPlus # hangs with 5.14.0-357
REGEXP: \bNet-Server-0\.99\.6\.1\.tar\.gz$                # hangs
Font-TFM                   # asks for path to tfm files
REGEXP: \bData-Faker-0\.07\.tar\.gz   # t/Data-Faker-DateTime.t runs forever
REGEXP: \bCrypt-RandPasswd-0\.02\.tar\.gz$         # hangs *sometimes*
REGEXP: \bHTTP-Server-Simple-Recorder-0\.03\.tar\.gz$  # hangs *sometimes*, even on perls that have previously succeeded
Net-RabbitMQ                      # hangs
REGEXP: \bApp-MrShell-2\.0207\.tar\.gz$       # hangs with v5.15.0-2-g1162210/2b65
Net-Pcap-Easy             # asks questions
Net-IMAP-Simple            # questions
Finance-TickerSymbols             # talks endlessly with some ticker sites
Enbugger                      # steps into the debugger
REGEXP: \bNet-Link-0\.01\.tar\.gz$            # hangs in t/00_link on 33955
Xen-Control                # calls sudo
MP3-Podcast              # hangs in test
App-Nopaste-Service-AnyPastebin # hangs due Module::Install
WWW-DaysOfWonder-Memoir44    # hangs
AnyEvent-Retry           # hangs after release-pod-syntax.t
Term-Screen                # automated testing impossible
REGEXP: \bCPANPLUS-0\.8(5_08|6|601)\.tar\.gz$        # hangs
Catalyst-Authentication-Store-LDAP # hangs
REGEXP: \bParallel-Prefork-0\.02\.tar\.gz$            # hangs
REGEXP: \bServer-Starter-0\.11\.tar\.gz$              # hangs
REGEXP: \bPOE-Component-Client-Stomp-0\.05\.tar\.gz$ # hangs in t/02_basic.t with 5.10 proper
REGEXP: \bXML-Grove-0\.46alpha\.tar\.gz$     # (1999) seems to be unmaintained
REGEXP: \bMail-SpamAssassin-3\.3\.2\.tar\.gz$        # asks a new question
Alien-IUP                     # not analysed slowness and CPU hog; then again questions being asked
IPC-MPS                        # asks questions
REGEXP: \bXiaoI-0\.01\.tar\.gz$                # hung
REGEXP: \bXiaoI-0\.03\.tar\.gz$                # hung
WebService-ScormCloud # asks for an ID
Devel-ebug-HTTP          # http://rt.cpan.org/Ticket/Display.html?id=40599
Bio-SamTools                  # requires non-CPAN prereq
Audio-Play-MPlayer              # hangs
Filesys-SamFS                # have no SamFS
Egg-Release-DBI                   # brings laptop to its knees RT #39239
CGI-CMS                     # asks questions about paths
RadiusPerl       # hangs in test.pl
Flickr-Embed          # hangs in test basic.t
Data-Transform-SSL # memory accident?
WWW-Mechanize-Pluggable # killed the cpan shell with kill(); I don't understand how
Dist-Zilla-Plugin-RequiresExternal # endless loop if JSON::PP missing???
Authen-TacacsPlus # seems to hang
Mail-SpamCannibal     # IIUC it insists on answering aquestion with yes or no
Net-LDAPapi              # gives gooood advice and stops
SQL-Tree                  # hangs before the first test
REGEXP: \bAnyEvent-4\.232\.tar\.gz$                 # hangs after "t/06_socket.....ok"
Deliantra                      # looks complicated and not using CheckLib
REGEXP: \bPApp-1\.42\.tar\.gz$               # the autoconfiguration gets it wrong
App-Staticperl                 # highly dangerous stuff rewrites ~/.cpan/CPAN/MyConfig.pm
Mojolicious-Plugin-OAuth2  # hangs
Forks-Super                        # too demanding
REGEXP: \bDevice-Blkid-E2fsprogs-0\.2[24]\d*\.tar     # asks question without EUMM
GitMeta                   # all Git stuff seems to hang my v5.15 smoker
LWP-UserAgent-POE         # seems to hang
REGEXP: \bTest-Fork-0\.01_01\.tar\.gz$       # test hangs
REGEXP: \bXML-miniXQL-0\.04\.tar\.gz$       # rest in peace: missing dependency decl on XML::Parser but so old (1999) that I do not want to RT it
CGI-Test                 # asks if it should strip Carp::Datum calls
Db-Documentum              # press return to continue...
Net-Address-Ethernet        # interactive questions that we cannot answer as a bot
WWW-Search-Yahoo          # hangs in t/china.t
ResourcePool-Resource-SOAP-Lite # asks questions
CGI-Application-Plugin-DebugScreen # hangs on some perls (5.10.1 I think)
REGEXP: \bReflexive-Stream-Filtering-1\.103\.tar\.gz$ # hangs
REGEXP: \bPOE-Component-Supervisor-0.0[12]\.tar\.gz$ # hangs during t/04_global_restart_policy.
perl               # pumpkin
App-Unix-RPasswd          # takes too much time, no idea what it does
REGEXP: \bURI-ParseSearchString-More-0\.04\.tar\.gz$
Git-Wrapper               # some huge kill triggered?
CatalystX-ExtJS-Direct      #
Test-WWW-Mechanize        # hangs
IPC-PerlSSH-Async           # asks for a password during testing
IPC-PerlSSH                # asks for a password during testing
Net-SMS-Clickatell-SOAP
DBIx-MyParse             # too complicated to set up (mysql source etc.)
Bundle-DBD-DBM                  # takes too many hours
Template-Alloy-XS          # very hungry for memory, made amd64 unuseable
HTTP-Lite                  # asks for a URL
REGEXP: \bmod_perl-2\.0\.5\.tar\.gz$             # endless loop
REGEXP: \bCatalyst-Controller-WrapCGI-0\.0030\.tar\.gz$ # hangs
Schedule-Cron                 # hangs after load_crontab.t
jmx4perl                    # asks questions
Device-Velleman-K8055-Fuse     # asks for a hadness (don't know what that is)
REGEXP: \bData-Session-1\.03.tgz$           # hangs during basic.t with all CPU consumed
REGEXP: \bB-C-1\.34\.t                         # hangs with v5.15-135
REGEXP: \bB-Debugger-0\.01_03\.tar\.gz$        # hangs with perl-5.8.8 at 33430 during test.pl
REGEXP: \bC-DynaLib-0\.58\.t                   # hangs with 27040 (=5.8.8) on t/01test.t but not with others
Bio-Phylo                    # hangs after 03-node.t with v5.15.0-241-g0a044a7/2b65/
REGEXP: \bforks-0\.25\.t
Net-OpenSSH                     # asks for a password during test
Lingua-Translate                 # hangs often
Alien-FLTK                     # downloads with waiting time risk
REGEXP: \bCPAN-Dependency-0\.1[25]\d*\.t           # hangs in t/02internals: strace select(16, [4 8], NULL, NULL, NULL <unfinished ...>
REGEXP: \bAttribute-Persistent-1\.1\.tar\.gz$   # fails with out of memory and blocks the box for quite a while
REGEXP: \bXML-Grammar-Screenplay       # t/to-xhtml.t took ~17 minutes
X11-Protocol                # hangs after ok 2, uses only a test.pl
P4                              # asks for Perforce api paths
Alien-ROOT        # hangs (Note from Steffen: Curious. It should just exit(0) for automated smokers)
REGEXP: \bCatalyst-Plugin-HTML-Widget-1\.1\.tar\.gz$ # Module::Install 0.54 http://rt.cpan.org/Ticket/Display.html?id=40618
P4-Server                    # or maybe it was this one?
REGEXP: \bStem-0\.12\.tar\.gz$              # hangs
Cvs-Simple                 # asks for CVS paths
FCGI-Engine                  # 0.04 hangs on t/002_basic_with_listen
WWW-Myspace               # tests take too long
REGEXP: \bPluceneSimple-1\.04\.tar\.gz$     # seems to be abandoned
Device-Davis                # asks me for a tty to use
Net-INET6Glue                  # asks questions
Net-SSLGlue                    # asks questions
REGEXP: \bEzmlm-0\.08\.2\.t                  # questions
Acme-RPC # hangs
REGEXP: \bDebug-Client-0\.11\.tar\.gz$        # hangs
REGEXP: \bNet-RabbitMQ-Simple-0\.0004\.t$          # hangs
Amon2                       # test hangs with some perls
Moxy                      # test hangs (maybe during a prereq?)
Quota                        # 1.5.2 and 1.6.0 hang during test.pl
POE-XS-Loop-EPoll              # asks questions
kurila                        # asks too many questions
HTML-WikiConverter-DokuWikiFCK # hangs very early
DBD-Pg                # asks for pg_config
Stem                       # asks questions about conf directories
REGEXP: \bNet-SNMPTrapd-0\.04\.t            # asks question
REGEXP: \bNet-Syslogd-0\.04\.t             # asks question
REGEXP: \bMail-MboxParser-0\.55\.tar\.gz$   # hangs during some test
IPC-MorseSignals   # hangs too often (see Todo)
CGI-Application-Dispatch          # endless loop
RPC-Oracle                 # asks username for Oracle
Email-Folder-Exchange        # asks questions
Astro-SIMBAD-Client         # asks questions
Astro-satpass                  # asks sth (maybe without flush)
Games-Sudoku-General         # asks whether I want to install sudokug
Module-Install-ExtendsMakeTest  # hangs (0.0{2,3})
Module-Install-TestTarget     # hangs
REGEXP: \bMojoX-AIO-0\.02\.tar\.gz$            # hangs
CGI-QuickApp                  # hangs immediately
REGEXP: HTTP-Engine        # hangs in various versions
WWW-Patent-Page           # downloads something largish
PDE                       # probably a broken Makefile.PL that tries to install Module::Build even if it is installed and calls CPAN recursively; in any case an endless loop
POE-Component-WWW-Google-PageRank # hangs in 00-load with 34437
POE-Component-WebService-HtmlKitCom-FavIconFromImage # hangs
Alien-ActiveMQ           # downloads 50MB and leaves them in /tmp/
Fax-HylaFax-Client # 'make test' requires input and a working fax server.
