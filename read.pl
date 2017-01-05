#!/usr/bin/perl -w
use Tie::File;
use strict;
use Data::Dumper;
use 5.10.0;
use Carp;
use Cwd;
use  lib '/historical/testexports/mgrigorov';
use mtools qw(d);
use File::Find;
use Getopt::Long;
use IO::File;

#########################################################
# Author MGrigorov v0.0 2016.12.09 initial development
#########################################################
# TODO: fix bug with test/ in current dir 
# speed testing
#
#  OPTIONS:
#  Only files = find only files maybe default
#  Endless greps and vgreps
#  Multiple dirs 
#  give it as fh
#  read all of them

my $Options = {};
$Options->{_Status} = GetOptions(
#        "gt_size=i"           => \$Options->{GtSize},          ### report dirs with size grater than $nuber
#        "st_size=i"           => \$Options->{StSize},          ### Future development
#        "skip_bkp"      =>    \$Options->{SkipBkp},            ### skip backup files
#        "bkp_extention"      =>    \$Options->{BkpExt},        ### change bkp file extention 
        "files_only"           => \$Options->{OnlyFiles},       ### skips directori
        "dir|d=s@"               => \$Options->{Dir},           ### Set dir for parse 
        "o=s"                 => \$Options->{Output},           ### Output file Future dev 
        "grep|g=s@"              => \$Options->{Grep},          ### Grep for some files regex
        "rgrep|gv=s@",            => \$Options->{RGrep},        ### reverse grep for files
        "help|h",             => \$Options->{Help},            # Print Help
        ) or confess("Err: command line arguments are wrong\n");

#d "Opt", $Options;
$Options->{OnlyFiles} = '1';

my $Finder = SeekAndDestroy->new($Options);
my @files = $Finder->get_result();
d "files" , \@files;

for my $file (@files) {
    next if $file =~/bkp/;
    my $fh = new IO::File;
    $fh->open($file);
    my @lines = <$fh>;

    my $fh_o = new IO::File "> $file.new";
    my $i;

    for my $line (@lines) {
        $i++;
        $line =~ s/(^[^"]*)//;
        if ($i > 1 ) {
               if ($line !~ /1"\s*$/) {
                   $line =~ s/\s*$/,"","",""\n/;
                    }
        }
    print $fh_o $line;
#        d $line;
    }
    $fh->close;
    $fh_o->close;
}

#d "Show me F", $Finder;

package SeekAndDestroy ;
use strict;
use Data::Dumper;
use 5.10.0;
use Carp;
use Cwd;
use  lib '/historical/testexports/mgrigorov';
use mtools qw(d);
use File::Find;
use Getopt::Long;
################################## 

sub new {
    my $self = shift;
    my $Options = shift;
    confess "Error: some argument are required in hash ref" unless ref $Options eq 'HASH';

    $self = bless $Options, $self; 
 
    $self->_checkOptions();
#       d "Opt", $Options; 
    $self->execute_find();
    return $self; #

}
################################## 
sub _checkOptions {
    my $self = shift;

    if ( $Options->{Dir} and ref $Options->{Dir} eq 'ARRAY' ){

        for my $i ( 0 .. $#{$Options->{Dir}}) {
            my $dir = $Options->{Dir}->[$i];

            if ( $dir !~ /\/$/ ) { $Options->{Dir}->[$i] = $dir . '/' } #add slash just to be pretty 
            
            # check options dirs are they real
                unless (-d $dir ){
                    confess "Error: the requested dir[$dir] does not exists";
                }
        }

    }else{
        # default behavior for dir Option
        push @{$Options->{Dir}}, getcwd();
        carp "No dirs given as argument so it will use " . getcwd(); 
    }


    return $self;
}

################################## 
sub execute_find {
    my $self = shift;

    find(\&wanted, @{$Options->{Dir}} );

    #File::Find starts this foreach file
    sub wanted {

#    my ( $size, $owner );
        my $is_file;

        if ( -f $File::Find::name ) {
            $is_file = 1;
        } else{
            return if $Options->{OnlyFiles};
        }

    #grep in whole path Option
    my $file_name;
    # GrepOptions applied to the whole path or just in the basename
    if ($Options->{GrepPath}){
        $file_name = $File::Find::name;
        }else{
        $file_name = $_;
        }


    if ( $Options->{Grep} and ref $Options->{Grep} eq 'ARRAY' ){
        for my $grep (@{$Options->{Grep}}) {
            return unless ( $file_name =~ /$grep/ ) ;                
        }
    }

    if ( $Options->{RGrep} and ref $Options->{RGrep} eq 'ARRAY' ){
        for my $rgrep (@{$Options->{RGrep}}) {
            return if ( $file_name =~ /$rgrep/ ) ;                
        }
    }

    push @{$Options->{Found}}, $File::Find::name;
#    d "args dir[$File::Find::dir] name[$File::Find::name]", $_;
        

#    my $stat = stat($File::Find::name) or carp "Warning: can't stat file[$File::Find::name] std_err[$!]";
#    return unless $stat;
#    $owner = ( getpwuid $stat->uid )[0];

#    unless ($owner) {
#        my $uid = $stat->uid;
#        return if $Options->{SkipUO};
#        carp "Warning: can't get owner from stat->uid[$uid] for file[$File::Find::name]";
#        $owner = "unknown[$uid]";
#    }
#
#    $size = $stat->size;

#    if ( $Options->{Owner} ) {
#        return unless $owner =~ /$Options->{Owner}/;
#    }


    }
}

#############################
sub get_result {
    my $self = shift;
    if ($Options->{Found}) {
        return @{$Options->{Found}};
        } else {
        return undef;
        }
}

1;
