#!/usr/bin/perl -w

# This code below can be usefull if you have deleted some file that was recently editted
# So the script will search in some cash where recently editted files can be found.

use strict;
use 5.10.1;
use Data::Dumper;

#version 0.0.2

print "Usage <dev> <regex>\nExample $0 /dev/sda1 'sub mapPosition'\nFor more info you can see your fstab with cat /etc/fstab\n" if $ARGV[0] eq '-h';
my $dev;

if ($ARGV[0]) {
	$dev = $ARGV[0] if $ARGV[0] =~ /dev/ ;
}

die "Wrong or mising first argument\n" unless $dev;

my $regex;

if ($ARGV[1]) {
	$regex = $ARGV[1];
} else {
	die "Wrong or mising second argument\n" unless $dev;
}

#$regex = eval { qr/$regex/ };
#die "DIED:invalid regex: $@" if $@;
say "DEBUG ARGUMENTS I will search in dev[$dev] with pattern[$regex]";

open(DEV, $dev) or die "Can't open: $!\n";
my $buf;
while (read(DEV, $buf, 4096)) {
	print tell(DEV), "\n", $buf, "\n" if $buf =~ /$regex/;
}
1;
