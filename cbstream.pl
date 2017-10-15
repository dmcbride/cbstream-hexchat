#! /usr/bin/perl
use strict;
use warnings;

my $name = 'cbstream';
my $version = 0.09;

# what I need...
use YAML::Syck qw(LoadFile DumpFile);
use Data::Diver qw(DiveVal Dive DiveRef);
use LWP::Simple qw();
use XML::Twig;

# debugging tools...
use IO::Handle;
open my $log, '>', File::Spec->catfile(
                                       Xchat::get_info('xchatdir'),
                                       "$name.log"
                                      )
    or die "Can't open $name.log: $!";
$log->autoflush();
sub LOG { print $log scalar localtime, ": ", @_, "\n" }
LOG 'starting up...';

Xchat::register($name, $version, 'CBStream re-writer');

{
    use File::Spec;

    my $conf;
    my $loadtime;
    my $conf_file = File::Spec->catfile(Xchat::get_info('xchatdir'), $name . '.yaml');
    sub _conf {
        if (!$loadtime || -M $conf_file < $loadtime)
        {
            LOG "loading $conf_file";
            $conf = LoadFile($conf_file);
            $loadtime = -M $conf_file;
        }
        $conf
    }

    sub get_conf
    {
        my @var = @_;
        Dive(_conf, @var);
    }
    
    sub set_conf
    {
        my $val = pop;
        DiveVal(_conf, @_) = $val;
    }

    sub rm_conf
    {
        my $val = pop;
        my $rm  = Dive(_conf, @_);
        if ($rm)
        {
            delete $rm->{$val};
        }
    }

    sub save_conf
    {
        DumpFile($conf_file, $conf) if $conf;
        $loadtime = -M $conf_file; # we already have it loaded...
    }
}

# because hexchat reads $@ even when there is no error, we need to
# ensure it gets blanked out.
# ( see https://github.com/hexchat/hexchat/issues/2076 )
sub make_hook(&)
{
    my $func = shift;

    sub {
        # yeah, yeah... but it's really the same variable!
        my ($rc, @rc);

        my $success = wantarray ? eval {
            @rc = $func->(@_);
            1;
        } : eval {
            $rc = $func->(@_);
            1;
        };

        # if we succeeded, clobber $@
        $@ = undef if $success;

        return @rc if wantarray;
        return $rc;
    };
}

Xchat::hook_command('cblog', make_hook { Xchat::command 'join #cbstream-login'; Xchat::EAT_ALL });
Xchat::hook_print('You Join', make_hook \&JoinCBStreamLogin);
Xchat::hook_server('PRIVMSG', make_hook \&LeaveCBStreamLogin);

# once logged in, tell cbstream what our id and pw is.
sub JoinCBStreamLogin
{
    my $info = shift;

    if (lc Xchat::get_info('network') =~ 'freenode')
    {
        if ($info->[1] eq '#cbstream-login')
        {
            my $id = get_conf('cbstream','pmuser');
            my $pw = get_conf('cbstream','pmpassword');
            if ($id and $pw)
            {
                Xchat::set_context('#cbstream-login');
                Xchat::command("say plogin $id $pw");
            }
            return Xchat::EAT_NONE;
        }
    }
    Xchat::EAT_NONE;
}

sub LeaveCBStreamLogin
{
    my $msg = shift;
    my $nth = shift;

    if (lc Xchat::get_info('network') eq 'freenode')
    {
        if ($msg->[0] =~ /^:cbstream!/ and
            $msg->[1] eq 'PRIVMSG' and
            lc $msg->[2] eq lc Xchat::get_info('nick')
           )
        {
            if ($nth->[3] =~ /You are now persistently logged in as perlmonks user/ or
                $nth->[3] =~ /You are now logged in as perlmonks user/ or
                0
               )
            {
                #Xchat::set_context('cbstream');
                #Xchat::command('close');
                Xchat::set_context('#cbstream-login');
                Xchat::command('close');
                Xchat::set_context('#cbstream');
                (my $realmsg = $nth->[3]) =~ s/^:\+//;
                Xchat::print("CBLOGIN: $realmsg");

                return Xchat::EAT_ALL;
            }
            else
            {
                Xchat::set_context('#cbstream');
                (my $realmsg = $nth->[3]) =~ s/^:\+//;
                Xchat::print("CB: $realmsg");
                
                return Xchat::EAT_ALL;
            }
        }
    }
    return Xchat::EAT_NONE;
}

# check for ignored users...
Xchat::hook_command('cbig', make_hook \&get_ignored);
sub get_ignored
{
    Xchat::print("Gathering ignores from Perlmonks");
    rm_conf(qw(cbstream ignore byname));

    require URI::Escape;
    my $user = URI::Escape::uri_escape(get_conf('cbstream', 'pmuser'));
    my $pass = URI::Escape::uri_escape(get_conf('cbstream', 'pmpassword'));

    my $me = LWP::Simple::get("http://www.perlmonks.org/index.pl?op=login;user=$user;passwd=$pass;displaytype=xml;ticker=yes;node=$user");
    my $twig = XML::Twig->new();
    $twig->parse($me);

    my @elt = $twig->get_xpath('//var[@name="ignoredusers"]');
    if (@elt)
    {
        my $ignored = $elt[0]->text();
        my @uids = ($ignored =~ /\|(\d+),/g);

        my @users = map {
            my $nick = get_conf(qw(cbstream ignore byid), $_) || do {
                my $xml = LWP::Simple::get("http://www.perlmonks.org/index.pl?displaytype=xml;node_id=$_");
                my $nicktwig = XML::Twig->new();
                $nicktwig->parse($xml);
                (my $user = ($nicktwig->get_xpath('//author'))[0]->text()) =~ s/^\s+//;
                $user =~ s/\s+$//;
                set_conf(qw(cbstream ignore byid), \$_, $user);
                $user;
            };
            set_conf(qw(cbstream ignore byname), $nick, $_);
            $nick;
        } @uids;

        if (@users)
        {
            Xchat::print("Ignoring: @users");
        }
        else
        {
            Xchat::print("Ignoring no one");
        }

        save_conf();
    }
    else
    {
        Xchat::print "no one being ignored (maybe failed to log in?)";
    }

    Xchat::EAT_ALL;
}

Xchat::hook_command('cbignore', make_hook \&add_ignore);
sub add_ignore
{
    my $person = $_[1][1];
    return Xchat::EAT_ALL unless $person;
    $person =~ s/^\[(.*)\]/$1/;

    Xchat::print "Adding [$person] to PM ignores";
    Xchat::command "say /ignore [$person]";

    set_conf(qw(cbstream ignore byname), $person, -1);

    Xchat::EAT_ALL;
}

Xchat::hook_command('cbunignore', make_hook \&rm_ignore);
sub rm_ignore
{
    my $person = $_[1][1];
    return Xchat::EAT_ALL unless $person;
    $person =~ s/^\[(.*)\]/$1/;

    Xchat::print "Removing [$person] from PM ignores";
    Xchat::command "say /unignore [$person]";

    rm_conf(qw(cbstream ignore byname), $person);

    Xchat::EAT_ALL;
}

Xchat::hook_command('cbmsg', make_hook \&cb_msg);
sub cb_msg
{
    my $msg = shift;
    my $nth = shift;
    
    Xchat::print "Sending $nth->[1] (don't expect a response here)";
    Xchat::command "say /msg $nth->[1]";

    Xchat::EAT_ALL;
}

my $lastalias;

Xchat::hook_server('RAW LINE', (make_hook \&rewrite_cb), { priority => Xchat::PRI_LOW });
sub rewrite_cb
{
    my $msg = shift;
    my $nth = shift;

    if (lc (Xchat::get_info('network')||'unknown') eq 'freenode')
    {
        #LOG(@$msg);
        if ($msg->[0] =~ /^:cbstream!/ and
            $msg->[1] eq 'PRIVMSG' and
            $msg->[2] eq '#cbstream' and
            1
           )
        {
            my $prefix = get_conf('cbstream','nick-prefix') || '';
            my $suffix = get_conf('cbstream','nick-suffix') || '';

            (my $alias) = $nth->[3] =~ /^\S*\[(.*?)\]/;
            $alias ||= $lastalias;
            $lastalias = $alias;
            (my $safealias = $alias) =~ s/\s/_/g;
            (my $newmsg = $nth->[0]) =~ s/^:cbstream!/:$prefix$safealias$suffix!/;
            $newmsg =~ s/\[\Q$alias\E\]\s+//;

            # check if it's someone we think we're ignoring...
            if (! get_conf(qw(cbstream ignore byname), $alias) )
            {
                # if it's an action, we need to convert it to such.
                $newmsg =~ s[:\+*/me (.*)][:\001ACTION $1\001];
                Xchat::command("recv $newmsg");
            }
            elsif (my $mode = get_conf(qw(cbstream ignore_mode)))
            {
                if ($mode eq '1' or $mode eq 'brief')
                {
                    Xchat::print("$alias said something, but we're ignoring them.");
                }
                elsif ($mode eq '2' or $mode eq 'verbose')
                {
                    $newmsg =~ s[^.*:\+][];
                    Xchat::print("$alias said '$newmsg', but we're ignoring them.");
                }
            }

            Xchat::EAT_ALL;
        }
    }
}

Xchat::hook_command('cbset', make_hook \&cb_set);
sub cb_set
{
    my $msg = shift;
    my $nth = shift;

    set_conf('cbstream', @{$msg}[1..$#$msg]);
    Xchat::print ("set " .
                  join(' ', map { "[$_]" } @{$msg}[1..$#$msg-1]) .
                  " to {" . $msg->[-1] . "}");
    save_conf();

    Xchat::EAT_ALL;
}

Xchat::hook_command('cbget', make_hook \&cb_get);
sub cb_get
{
    my $msg = shift;
    my $nth = shift;

    my $val = get_conf('cbstream', @{$msg}[1..$#$msg]);
    if (defined $val)
    {
        if ($nth->[1] =~ /password/)
        {
            $val = '(not displayed)';
        }
        else
        {
            $val = "{ $val }"
        }
    }
    else
    {
        $val = '<not defined>';
    }

    Xchat::print(join(' ', map { "[$_]" } @{$msg}[1..$#$msg]) .
                 " = $val");
    Xchat::EAT_ALL;
}

Xchat::hook_command('cbrm', make_hook \&cb_rm);
sub cb_rm
{
    my $msg = shift;
    my $nth = shift;

    rm_conf('cbstream', @{$msg}[1..$#$msg]);
    Xchat::print('deleted ' .
                 join(' ', map { "[$_]" } @{$msg}[1..$#$msg]));
    save_conf();

    Xchat::EAT_ALL;
}
