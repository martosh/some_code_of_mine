#!/usr/bin/env perl
package CheckModules; 

use Moose;
use 5.10.1;
use strict;
use warnings;
use Data::Dumper;
use Module::ScanDeps;
use List::MoreUtils qw(uniq);
use lib '/home/mgrigorov/some_code_of_mine/';
use mtools q(d);
use File::Basename;


# create tar.gz rar
# See dependencies and install them automaticaly
# The question if see them is it tell you that you don't have these 
# I can test this actually 

# and also tool for tar.gz 
#
# moose 'Extends' key word is defaining is the class is sub class 

#has title => ( 
#    is => 'rw', 
#    reader => 'get_title',
#    accessor => 'set_title',
#    isa => 'Str',
##    lazy => '1', # This required default and it's called only once ???
##    isa => 'Defined',
##    isa => 'Values', # is not reference 
##    required => '1',
#    clearer => 'clearTitle', # removes title
#    predicate => 'has_title', # if defined $self->get_title();
##    default => 'Engeneer',
##    builder => '_build_something', # it's like default function 
##    trigger => #execute after calling
#);
#
## has '+title' to overwrite in sub_class
#
#has name  => ( 
#    is => 'ro', 
#    reader => 'get_name', 
#    isa => 'Str',
##    default => sub { my $self = shift; '123' + $self->get_title() },
#);

has files => (
    is => 'rw',
    reader => 'get_files',
    accessor=> 'set_files',
); 

has result_dependency => (
    is => 'rw',
    reader => 'result_deps',
    accessor=> 'set_deps',
); 

##############################
#
##############################

#sub name_and_title {
#    my $self = shift;
#
#    my $name = $self->get_name;
#    my $title = $self->get_title;
#
#    return "n[$name] t[$title]"; 
#
#}


#################################
 # Scan Files
#################################
sub scan_files {

    my $self  = shift;
    my $files = shift;
    my $files_hash = {};

    #NOTE Must be done with regexp 
    map { $files_hash->{ basename($_)} = 1 } @{$files};
    
#    d "files_hash", $files_hash;

    my @result_modules;

    my $number = @{$files};
    say "Given [$number] files:" .  Dumper $files;
    my $result = {};
#    d "print in -f-/home/mgrigorov/Work/script/list.txt", $files;

    #$self->set_files(@files);

    my $hash_ref = scan_deps(
        files => $files,
               recurse => 1,
        #       compile => 1,
    );

    for my $file ( keys %{$hash_ref} ) {
#        d $file, $hash_ref->{$file};
        my $type = $hash_ref->{$file}->{type};
        next if $type eq 'data';
        my $path    = $hash_ref->{$file}->{file};
        my $used_by = $hash_ref->{$file}->{used_by};
        my $uses    = [];

        if ( $hash_ref->{$file}->{uses} ) {
            $uses = $hash_ref->{$file}->{uses};
        }

        push @result_modules, $file;

        if ( @{$uses} ) {
            push @result_modules, @{$uses};
        }
    }

    #then remove files from our initial list
    
    map { $result->{$_} = '1' unless $files_hash->{$_} } @result_modules;

#    d "print in -f-/home/mgrigorov/Work/script/list.txt", $result;

    say 'RESULT' . Dumper $result; 

}

#################################
# take_mine_modules 
#################################
sub take_my_modules {
    #take my modules and compare to list


}

#    # shorthand; assume recurse == 1
#    my $hash_ref = scan_deps( 'a.pl', 'b.pl' );
#
#    # App::Packer::Frontend compatible interface
#    # see App::Packer::Frontend for the structure returned by get_files
#    my $scan = Module::ScanDeps->new;
#    $scan->set_file( 'a.pl' );
#    $scan->set_options( add_modules => [ 'Test::More' ] );
#    $scan->calculate_info;
#    my $files = $scan->get_files;
#


no Moose;

1;
