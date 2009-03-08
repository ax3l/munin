use warnings;
use strict;

use Test::More tests => 16;

use English qw(-no_match_vars);
use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok('Munin::Node::Config');

my $conf = Munin::Node::Config->new();
isa_ok($conf, 'Munin::Node::Config');

###############################################################################
#                       _ P A R S E _ L I N E

### Corner cases

is($conf->_parse_line(""), undef, "Empty line is undef");

eval {
    $conf->_parse_line("foo");
};
like($@, qr{Line is not well formed}, "Need a name and a value");

is($conf->_parse_line("#foo"), undef, "Comment is undef");


### Hostname

my @res = $conf->_parse_line("hostname foo");
is_deeply(\@res, [fqdn => 'foo'], 'Parsing host name');

# The parser is quite forgiving ...
@res = $conf->_parse_line("hostname foo bar");
is_deeply(\@res, [fqdn => 'foo bar'],
          'Parsing invalid host name gives no error');


### Default user

my $uname = getpwuid $UID;

@res = $conf->_parse_line("default_client_user $uname");
is_deeply(\@res, [defuser => $UID], 'Parsing default user name');

@res = $conf->_parse_line("default_client_user $UID");
is_deeply(\@res, [defuser => $UID], 'Parsing default user ID');


### Default group

my $gid   = (split / /, $GID)[0];
my $gname = getgrgid $gid;

@res = $conf->_parse_line("default_client_group $gname");
is_deeply(\@res, [defgroup => $gid], 'Parsing default group');

eval {
    $conf->_parse_line("default_client_group xxxyyyzzz");
};
like($@, qr{Default group does not exist}, "Default group exists");


### Paranoia

@res = $conf->_parse_line("paranoia off");
is_deeply(\@res, [paranoia => 0], 'Parsing paranoia');  

###############################################################################
#                       _ S T R I P _ C O M M E N T

{
    my $str = "#Foo" ;
    $conf->_strip_comment($str);
    is($str, "", "Strip comment");
}

{
    my $str = "foo #Foo" ;
    $conf->_strip_comment($str);
    is($str, "foo ", "Strip comment 2");
}

{
    my $str = "foo" ;
    $conf->_strip_comment($str);
    is($str, "foo", "Strip comment 3");
}


###############################################################################
#                         P A R S E _ C O N F I G

{
    my $conf = Munin::Node::Config->new();
    $conf->parse_config(*DATA);
    my $expected = {
        'fqdn' => 'foo.example.com',
        'sconf' => {
            'setsid' => 'yes',
            'background' => '1',
            'log_file' => '/var/log/munin/munin-node.log',
            'host' => '*',
            'setseid' => '1',
            'pid_file' => '/var/run/munin/munin-node.pid',
            'group' => 'root',
            'log_level' => '4',
            'user' => 'root',
            'allow' => '^127\\.0\\.0\\.1$',
        },
        'ignores' => [
            '~$',
            '\\.bak$',
            '%$',
            '\\.dpkg-(tmp|new|old|dist)$',
            '\\.rpm(save|new)$',
            '\\.pod$',
        ],
    };
    is_deeply($conf, $expected);
}

__DATA__
#
# Example config-file for munin-node
#

log_level 4
log_file /var/log/munin/munin-node.log
pid_file /var/run/munin/munin-node.pid

background 1
setseid 1

user root
group root
setsid yes

# Regexps for files to ignore

ignore_file ~$
ignore_file \.bak$
ignore_file %$
ignore_file \.dpkg-(tmp|new|old|dist)$
ignore_file \.rpm(save|new)$
ignore_file \.pod$

# Set this if the client doesn't report the correct hostname when
# telnetting to localhost, port 4948
#
host_name foo.example.com

# A list of addresses that are allowed to connect.  This must be a
# regular expression, due to brain damage in Net::Server, which
# doesn't understand CIDR-style network notation.  You may repeat
# the allow line as many times as you'd like

allow ^127\.0\.0\.1$

# Which address to bind to;
host *
# host 127.0.0.1
