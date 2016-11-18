#!/usr/bin/perl
use 5.10.1;

use lib '/Users/c16143a/private/work/mrepo/some_code_of_mine';
use mtools qw( duplicate_check );
#Added for test
my $hash = {
    '3' => 43,
    '4' => 712,
    '9' => ' 10',
    '8 ' => 'undef',
    '1' => 22,
    '11' => 24,
    '7' => 85,
    '71' => ' 81 ',
    '5' => 6,
    '56' => " 1",
     99  => '',
};

my $array = [ 1 .. 100 ];

my $duplicated = duplicate_check({
#        hash=>$hash,  #.......# This may be array=>\@array or hash=>\%hash, structure to check for duplication
        array=>$array,
        dup_regex=>'(^.{1})', # Regex to map hash values or array elements in that case will check only first symbols ('4','7','') for duplications
        dup_clean=>sub { my $v = shift;  $v =~ s/\s*//; return $v; }, # This is same as regex but more flexible
        return_hash => 1 # return output is hash, default is array 
        });
use Data::Dumper;

say Dumper $duplicated;

