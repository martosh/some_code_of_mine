#!/usr/bin/env perl
use 5.10.1;
use strict;
use warnings;
use Data::Dumper;
use CheckModules;
use Getopt::Long;
use lib '/home/mgrigorov/some_code_of_mine/';
use SeekAndDestroy;
use mtools qw(d);

my $Finder = SeekAndDestroy->new(\@ARGV);
my @files = $Finder->get_result();
#d "files", \@files;

my $Checker = CheckModules->new();
$Checker->scan_files(\@files);
#say Dumper $Checker;

#$Checker->set_title ( $Options->{Test} );
#say $Checker->name_and_title();

