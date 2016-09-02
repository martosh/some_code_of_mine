#!/usr/bin/perl -w
use strict;
use 5.10.1;
use Data::Dumper;
use lib qw( /home/martosh/scripts/Mmod /home/admin_la/mgrigorov/Mmod /proj/inbox/dataproc/lib );
#use ExportingTools;
use Carp;
use utf8;
use mtools qw(d);
use File::Find;
use File::stat;
use Getopt::Long;
use Sort::Naturally;

$Data::Dumper::Sortkeys = sub {
    [ sort { ncmp( $a, $b ) } keys %{ $_[0] } ];
};

# Author MGrigorov mgrigorov@emis.com
# VERSION 0.0.0 => 04.01.2016 Development
# LS how many files we have in every dir recursivly and show size

#### For Version 0.0.1
	# Add files time as well
 	# Ignore errors
 	# Add RM Option
 	# remove mtools;
	# Replace gt_files and gt_size with Options files='<123123' or files='>123123' #must use eval
	# Build Formated_size_to_bytes() 
	# AND option where all conditions must be true

my $seen    = {};
my $Options = {};

$Options->{_Status} = GetOptions(
    "dir=s"               => \$Options->{Dir},             ### Set dir for reporting
    "gt_size=i"           => \$Options->{GtSize},          ### report dirs with size grater than $nuber
    "owner=s"             => \$Options->{Owner},           ### set for what owners you want to select dirs
    "o=s"                 => \$Options->{Output},          ### Output File as report
    "rm"                  => \$Options->{Rm},              # Rm after report DISABLED FOR NOW
    "gt_files_num=i"      => \$Options->{GtFileNumber},    ### report dirs with -recursively have more files than $FileNumber
    "grep=s"              => \$Options->{Grep},            ### Grep for some dirs
    "rgrep=s",            => \$Options->{RGrep},           ### reverse grep
    "help|h",               => \$Options->{Help},            # Print Help
    "sort=s",             => \$Options->{Sort},            # Sorting
    "skip_unknown_owner", => \$Options->{SkipUO},          ### Skip files with uknown owners
) or confess("Err: command line arguments are wrong\n");

if ( $Options->{Help} ) {
    say "\n This script is designed to give report of directory's size and file amounts\n";
    say "\t-dir=/some/dir/          -> Give dir path for check and report for";
    say "\t-gt_size=123123          -> Report only dirs with size >= than given num";
    say "\t-owner=gosho             -> Set for what owners you want to select dirs";
    say "\t-o=/some/report_file.txt -> Output File as report";
    say "\t-rm -> FUTURE DEV        -> Rm after report DISABLED FOR NOW";
    say "\t-gt_files_num=10         -> Report only dirs with -recursively have files >= than given num";
    say "\t-grep='test'             -> Grep regex for dirs";
    say "\t-rgrep='rest'            -> Reverse Grep for found dirs";
    say "\t-help                    -> Prints help"; 
    say "\t-sort=??? FUTURE DEV     -> Sorting the result";
    say "\t-skip_unknown_owner      -> Skips files with uknown owners";
    exit 0;
}

### QA ARGS  and default values ####
confess "\nErr: GetOptions was failed"                                    unless $Options->{_Status};
confess "\nErr: -dir=\$some_dir option is manda, see -help for more info" unless $Options->{Dir};
confess "\nErr: -dir[$Options->{Dir}] is not valid dir"                   unless -d $Options->{Dir};

if ( $Options->{Dir} !~ /\/$/ ) { $Options->{Dir} = $Options->{Dir} . '/' }

$Options->{Grep} = '.*' unless $Options->{Grep};    # default regex

#d " Options", $Options;
find( \&wanted, $Options->{Dir} );

sub wanted {

    #d "args dir[$File::Find::dir]", $_;
    my ( $size, $owner );
    my $file_or_dir;

    if ( -f $File::Find::name ) {
        $file_or_dir = 'file';
    } else {
        $file_or_dir = 'dir';
    }

    my $stat = stat($File::Find::name) or carp "Warning: can't stat file[$File::Find::name] std_err[$!]";
    return unless $stat;
    $owner = ( getpwuid $stat->uid )[0];

    unless ($owner) {
        my $uid = $stat->uid;
        return if $Options->{SkipUO};
        carp "Warning: can't get owner from stat->uid[$uid] for file[$File::Find::name]";
        $owner = "unknown[$uid]";
    }

    $size = $stat->size;

    if ( $Options->{Owner} ) {
        return unless $owner =~ /$Options->{Owner}/;
    }

    if ( $File::Find::name =~ /$Options->{Grep}/ ) {

        #	d "match to regex File", $File::Find::name;

        if ( $Options->{RGrep} ) {
            push @{ $seen->{$File::Find::dir} }, { file => $_, size => $size, owner => $owner, type => $file_or_dir } unless $File::Find::name =~ /$Options->{RGrep}/;
        } else {
            push @{ $seen->{$File::Find::dir} }, { file => $_, size => $size, owner => $owner, type => $file_or_dir };
        }
    }

}

#	d "Seen DIRS ", $seen;

my $result = {};

# CALCULATED RESULT
for my $dir ( keys %{$seen} ) {

  FILE: for my $file ( 0 .. $#{ $seen->{$dir} } ) {

        if ( $seen->{$dir}->[$file]->{type} eq 'file' ) {

            $result->{$dir}->{size} += $seen->{$dir}->[$file]->{size};
            $result->{$dir}->{counted_files}++;
        }
    }
}

undef $seen;

#d "Result", $result;
# Human readable and filtering

for my $dir ( keys %{$result} ) {
    my $dir_size     = $result->{$dir}->{size};
    my $fsize        = formatSize($dir_size);
    my $file_counter = $result->{$dir}->{counted_files};

    my $flag_match;

    if ( $Options->{GtSize} ) {

        #        d "Dir size[$dir_size]", $Options->{GtSize};
        if ( $dir_size >= $Options->{GtSize} ) {
            $flag_match++;
            $result->{$dir}->{size} = $fsize;
        }
    }

    if ( $Options->{GtFileNumber} ) {
        if ( $file_counter >= $Options->{GtFileNumber} ) {
            $result->{$dir}->{size} = $fsize;
            $flag_match++;
        }
    }

    if ( $Options->{GtFileNumber} or $Options->{GtSize} ) {
        delete $result->{$dir} unless $flag_match;
    } else {
        $result->{$dir}->{size} = $fsize;
    }
}

d "Report", $result;
d "Rported Number", scalar keys %{$result};

if ($Options->{Output}) {
	d "Rported Number-f-$Options->{Output}", scalar keys %{$result};
	d "Report-f-$Options->{Output}", $result;
    }

#################################
# Other Custom functions
#################################

sub formatSize {

    # This fuction can be exported from mtools.pm but it isn't to skip module dependence
    my $size = shift;
    my $exp  = 0;

    state $units = [qw(B KB MB GB TB PB)];

    for (@$units) {
        last if $size < 1024;
        $size /= 1024;
        $exp++;
    }

    return wantarray ? ( $size, $units->[$exp] ) : sprintf( "%.2f %s", $size, $units->[$exp] );
}

1;
