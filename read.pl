#!/usr/bin/perl -w
use Tie::File;
use strict;
use Data::Dumper;
use 5.10.0;
use Carp;
use Cwd;
use lib qw(/historical/testexports/mgrigorov/scripts /Users/c16143a/work/some_code_of_mine/
  /Users/c16143a/work/scripts /Users/c16143a/work/scripts/CTAH);
use mtools qw(d);
use CTAH::CSVtok qw(:compat);

#use lib '/data/ops/lib/';
#use OpsKit::Utils::CDB_Data;
#my $CDB = OpsKit::Utils::CDB_Data->new();
#my $pid_to_aid = $CDB->readcdb('/cdb/data/pid_aid.cdb');

#########################################################
# TODO:
# fix bug with test/ in current dir
# speed testing

# Developer notes and ideas:
#    'Onlyfiles' Option will be requested at most of the times, so IncludeDirs maybe must be the proper option
#    Do not include target dir in get_result method() MANDA 
#    make Tmp dir to be hiden
#    setFiles() methods to be useful from perl
#    Add option to turn of TmpDir .. or maybe change the internal object to use an other dir
#    Error if external arguments are wrong
#    method witch give found files as a fh
#    method witch reads every file with CTAH::CSVtok;

my $Finder = SeekAndDestroy->new( \@ARGV, 'execute_find' );
d 'Show me object after new', $Finder;


my $code = sub {

    #    my $self      = shift;
    my $params      = shift;
    my $line        = $params->{ line };
    my @filelds     = $params->{ fields };
    my $sep         = $params->{ sep };
    my $new_sep     = $params->{ new_sep };
    my $file_name   = $params->{ file };
    my $header      = $params->{ header };
    my $quote       = $params->{ quoting };
    my $new_quoting = $params->{ new_quoting };

    my ( $new_line ) = $line =~ s/^\w+?//g;
    return $new_line;

};

###############
my $config = {
    sep         => "Old_separator",
    new_sep     => "new_separator",
    quoting     => "Old_quote",
    new_quoting => "new_quote",
    code        => $code,

    #        regex       => "regex",           #to take some part of lines
    #        v_regex     => "reverse_regex",
};

#my $config = { regex=>
$Finder->modify( $config );

#       for my $field (@_) {
#           $field =~ s/\"//g;
#       $field =~ s/MAILING_ID/AID/;
#       }
#
#       push @_, 'AID' if $_[3] eq 'MAILING_ID';
#
#       if ($_[3] and $_[3] =~ /\d+/ ){
#           my $field = $_[3];
#
#           if ($pid_to_aid->{$field}){
#               my $aid = $pid_to_aid->{$field};
#               $aid =~ s/,//;
#
#                   push @_, $aid;
#       #d "field[$field]aid[$aid]",  \@_;
#           }
#       }
#
#       my $line = join ("\t", @_);
#       $line = $line . "\n";
#       # say $line;
#       my $new_file =  basename($file);
#       $new_file = '/historical/testexports/mgrigorov/ELC_workaround/2068011888-201610_new/' . $new_file;
#       my $f_o = new IO::File ">> $new_file";
#       print $fh_o $line;
#       #return @_;
#       return 1;
#$Finder->qa();
#d "object", $Finder;

#$$Options->{OnlyFiles} = '1';
#my @files = $Finder->get_result();

#d "files" , \@files;
#parser = sub ( do some changes and then $self->write(@array, $new_sep, $new_qouting );
#$Finder->openFiles ( sep, quoting, parser );

#for my $file ( @files ) {
#
#    #   next if $file =~/bkp/;
#    my $fh = new IO::File;
#    $fh->open( $file );
#
#    #    d "File[$file]";
#    my $config = {
#        quoting => 'none',
#        sep     => 'tab',    # seperator
#                             #          esc=>(bs|*none|<literal-char>), # escape character, UNEMPLENTED
#                             #          wrap=>(*yes|1|no|0), # allow embedded newlines
#                             #          trim=>(yes|1|*no|0), # trim leading whitespace FROM WITHIN QUOTES
#                             #          rich=>(yes|1|*no|0), # csv_parse only, see example
#    };
#
#    #   my $parser = sub {
#    #
#    #   };
#
#    #csv_parse($fh, $config, $parser) or die "parse failed";
#    #   my @lines = <$fh>;
#    #
#    #   my $fh_o = new IO::File "> $file.new";
#    #   my $i;
#    #
#    #   for my $line (@lines) {
#    #       $i++;
#    #       $line =~ s/(^[^"]*)//;
#    #       if ($i > 1 ) {
#    #              if ($line !~ /1"\s*$/) {
#    #                  $line =~ s/\s*$/,"","",""\n/;
#    #                   }
#    #       }
#    #   print $fh_o $line;
#    #        d $line;
#    #   }
#    #   $fh->close;
#    #   $fh_o->close;
#}

#d "Show me F", $Finder;
#################################################################
package SeekAndDestroy;
#################################################################
use strict;
use Data::Dumper;
use 5.10.0;
use Carp;
use Cwd;
use lib qw(/historical/testexports/mgrigorov/scripts /Users/c16143a/work/some_code_of_mine/
  /Users/c16143a/work/scripts /Users/c16143a/work/scripts/CTAH);
use mtools qw(d);
use File::Find;
no warnings 'File::Find';
use File::Copy;
use File::Path qw(make_path remove_tree);
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Getopt::Long qw(GetOptionsFromArray);
use POSIX qw(strftime);
use File::Basename;

#Getopt::Long::Configure qw(pass_through);
Getopt::Long::Configure qw(ignorecase_always permute);
use CTAH::CSVtok qw(:compat);

##################################
sub new {
##################################
    my $self = shift;

    #    d "args", \@_;
    my $Options       = shift;
    my $find          = shift;
    my $filledOptions = {};

    # Requeres array ref or hash ref

    if ( ref $Options eq 'HASH' ) {    #if you want mannualy to create hash with Options
        $filledOptions = $Options;
    } elsif ( ref $Options eq 'ARRAY' ) {    # if Options are given via ARGV
        $filledOptions = _makeOptionsFromArray( @{ $Options } );
    } else {
        confess "Error: the object requires argv array ref or hash ref with options";
    }
    # Default move extention for tmp files 
    $filledOptions->{ MoveExt } = '.tmp~';
    $self = bless {}, $self;
    $self->{ Options } = $filledOptions;

    $self->_checkOptions();

    #    d "Opt", $Options;
    if ( $find eq 'execute_find' ) {
        $self->execute_find();
    }
    return $self;    #

}

##################################
sub _makeOptionsFromArray {
##################################
    my @Options_array = @_;
    my $Options       = {};

    #d "Options in makeOptions", \@Options_array;

    if ($Options_array[0] and $Options_array[0] !~ /^--?/ ){ #prevent user mistake
        confess "Error: Wrong argv. First \@ARGV argumet must start with single or double dash -|-- false arg[$Options_array[0]";
    }

    GetOptionsFromArray(
        \@Options_array,
        "files_only"   => \$Options->{ OnlyFiles },    ### skips directory
        "dir|d=s@"     => \$Options->{ Dir },          ### Set dir for parse
        "o=s"          => \$Options->{ Output },       ### Output file Future dev
        "grep|g=s@"    => \$Options->{ Grep },         ### Grep for some files regex
        "rgrep|gv=s@", => \$Options->{ RGrep },        ### reverse grep for files
        "clean_tmp",   => \$Options->{ ClearTmp },     ### ClearTmp dir
        "tmp_dir=s",   => \$Options->{ TmpDir },       ### custom tmp dir, default pwd/tmp_dir/
        "help|h",      => \$Options->{ Help },         ### Print Help
        #        "gt_size=i"           => \$Options->{GtSize},       ### Future dev report dirs with size grater than $nuber
        #        "st_size=i"           => \$Options->{StSize},       ### Future dev find size smaller than ..
        #        "skip_bkp"            => \$Options->{SkipBkp},      ### Future dev - skip backup files
        #        "bkp_extention"       => \$Options->{BkpExt},       ### Future dev -change bkp file extention
    ) or confess( "Err: command line arguments are wrong\n" );

    if ( $Options->{ Help } ) {
        say "\tHelp Options:For help use perldoc module_dir/SeenAndDestroy.pm";
        exit 0;
    }

    d "Show created options from array", $Options;
    return $Options;
}
##################################
sub _checkOptions {
##################################
    my $self    = shift;
    my $Options = $self->Options();
    #$Options->{ OnlyFiles } = 1; # default behavior for now 

    if ( $Options->{ Dir } and ref $Options->{ Dir } eq 'ARRAY' ) {

        for my $i ( 0 .. $#{ $Options->{ Dir } } ) {
            my $dir = $Options->{ Dir }->[ $i ];

            if ( $dir !~ /\/$/ ) { $Options->{ Dir }->[ $i ] = $dir . '/' }    #add slash just to be pretty

            # check options dirs are they real

            unless ( -d $dir ) {
                confess "Error: the requested dir[$dir] does not exists";
            }
        }

    } else {

        # default behavior for dir Option
        if ( defined $Options->{ Dir } ) {    # if user calls new() with Hash_ref and miss that $Options is array
            my $dir = $Options->{ Dir };
            $Options->{ Dir } = [];
            push @{ $Options->{ Dir } }, $dir;
        } else {
            push @{ $Options->{ Dir } }, getcwd();
            carp "\n\tWarning:No dirs given as argument so it will use " . getcwd();
        }
    }

    unless ( $Options->{ TmpDir } ) {
        $Options->{ TmpDir } = getcwd() . '/tmp_dir/';

    }

    if ( -d $Options->{ TmpDir } ) {
        carp "\n\tWarning: the temp dir already exists[$Options->{TmpDir}]";

        if ( $Options->{ ClearTmp } ) {
            $self->_emptyDir( $Options->{ TmpDir } );
        }

    } else {
        make_path( $Options->{ TmpDir } ) or confess "Error:cannot create path[$Options->{TmpDir}]";
    }

    return $self;

}
################################
sub _emptyDir {
################################
    my $self = shift;
    my $dir = shift || confess "Error: missing argument, must be dir_name";
    confess "Error: the desired dir[$dir] for rm does not exists" unless -d $dir;
    my $Options = {};
    $Options->{ Dir }       = $dir;
    my $newFinder = SeekAndDestroy->new( $Options, 'execute_find' );
    my @rm_files = $newFinder->get_result();

    #    d "files to be removed", \@rm_files;

    for my $file ( @rm_files ) {
        if ( $file ) {
            unlink $file or confess "Error: cannot unlink file[$file] std_err[$!]";
        }
    }

}
##################################
sub Options {
##################################
    # Getter and setter for Options
    my $self        = shift;
    my $userOptions = shift;

    if ( ref $userOptions eq 'HASH' ) {

        for my $option ( keys %{ $userOptions } ) {
            $self->{ Options }->{ $option } = $userOptions->{ $option };
        }

    } else {

        # carp "Warn: invalid or no arguments found in Options method so it'll act as Getter";
        return $self->{ Options };
    }

}

##################################
sub execute_find {
##################################
    my $self    = shift;
    my $Options = $self->Options();

    find( \&wanted, @{ $Options->{ Dir } } );

    #File::Find starts this foreach file
    sub wanted {

        #    my ( $size, $owner );
        my $is_file;

        if ( -f $File::Find::name ) {

            if ( $File::Find::name =~ /$0(?:\.swp)?/ ) { #if file is script itself
                return;
            }
            $is_file = 1;
        } else { #Directory


            for my $request_dir ( @{ $Options->{ Dir } } ) {    #do not include the request dirs itself
                if ( $File::Find::name eq $request_dir ) {
                    return;
                }
            }
            return if $Options->{ OnlyFiles };
        }

        return undef if $Options->{TmpDir} =~ /$File::Find::name/i; # skip tmp dirs as well
        #grep in whole path Option
        my $file_name;

        # GrepOptions applied to the whole path or just in the basename

        if ( $Options->{ GrepPath } ) {
            $file_name = $File::Find::name;
        } else {
            $file_name = $_;
        }

        if ( $Options->{ Grep } and ref $Options->{ Grep } eq 'ARRAY' ) {
            for my $grep ( @{ $Options->{ Grep } } ) {
                return unless ( $file_name =~ /$grep/ );
            }
        }

        if ( $Options->{ RGrep } and ref $Options->{ RGrep } eq 'ARRAY' ) {
            for my $rgrep ( @{ $Options->{ RGrep } } ) {
                return if ( $file_name =~ /$rgrep/ );
            }
        }

        push @{ $Options->{ Found } }, $File::Find::name;

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
#############################
    my $self    = shift;
    my $Options = $self->Options();

    if ( $Options->{ Found } ) {
        return @{ $Options->{ Found } };
    } else {
        return undef;
    }
}

#############################
sub _move {
#############################
    my $self     = shift;
    my $file     = shift;
    my $new_name = shift;
#   d "move[$file] to [$new_name]";
    move( $file, $new_name ) or confess "Error: cannot move file[$file] to [$new_name] std_err[$!]";
    return 1;
}

############################
sub __move {
#############################
    my $self  = shift;
    my $files = shift;
    confess "Error: require hash ref as argument" unless ref $files eq 'HASH';

    for my $old_name ( keys %{ $files } ) {
        $self->_move( $old_name, $files->{ $old_name } );
    }

}

##########################
sub modify {
##########################
    my $self   = shift;
    my $config = shift;
    confess "Error: wrong argument, require hash ref for this method for argument!" unless ref $config eq 'HASH';
    my $Options = $self->Options();

    $config = {
        sep         => "Old_separator",
        new_sep     => "new_separator",
        quoting     => "Old_quote",
        new_quoting => "new_quote",
        regex       => "regex",           #to take some part of lines
        v_regex     => "reverse_regex",
        code        => "code",
    };

    my @files = $self->get_result();

    if ( $config->{ regex } ) {

        #$self->qa_regex($config->{regex});
    #    @files = grep( /$config->{regex}/, @files );
    }

    if ( $config->{ v_regex } ) {

        #$self->qa_regex($config->{regex});
     #   @files = grep( !/$config->{v_regex}/, @files );
    }

    d "files ", \@files;

    for my $file ( @files ) {

        # d "foreach", " move[$file] to [" . $file . $Options->{ MoveExt } . "]";
        # move files in tmp_dir before any interaction
        my $time =  strftime("%Y%m%d%H%M%S", gmtime);
        my $tmp_filename =  $Options->{TmpDir} . basename($file) . "_$time" . $Options->{ MoveExt };
        d "tmp_filename", $tmp_filename;
        $self->_move( $file, $tmp_filename );

        #$self->if_gunzip($tmp_file);
        if ($tmp_filename =~ /\.gz/ ) {
            my $unziped_filename = $tmp_filename;
            $unziped_filename =~ s/\.gz//;
            gunzip( $tmp_filename => $unziped_filename )
               or die "Error:gunzip failed: $GunzipError\n";
            $tmp_filename = $unziped_filename;
          }
        
        #$self->open(@files);
        my $fh_read = new IO::File;

        $fh_read->open( $tmp_filename ) or confess "Error:file[$tmp_filename] cannot be openned std_err[$!]";

        my $csv_parse_config = {
#            sep => $config->{sep} ? $config->{sep} : 'tab' ,
#            quoting => $config->{quoting} ? $config->{quoting} : 'none',
            #          esc=>(bs|*none|<literal-char>), # escape character, UNEMPLENTED
            #          wrap=>(*yes|1|no|0), # allow embedded newlines
            #          trim=>(yes|1|*no|0), # trim leading whitespace FROM WITHIN QUOTES
            #          rich=>(yes|1|*no|0), # csv_parse only, see example
        };

        csv_parse($fh_read, $csv_parse_config, $config->{code}) or die "Error: cannot parse file[$tmp_filename] parse failed";
           $fh_read->close;
           #
        # This must be in the parser_code in csv_parse
           #my @lines = <$fh>;
        
           my $fh_out = new IO::File "> $file";
           my $line; 
           print $fh_out $line;
           $fh_out->close;

        #    d "File[$file]";
        
    }
    
    #$self->_if_header($file);
    #$self->_quess_sep() unless $sep
    #$self->_quess_quoting() unless $quoting LOGGING
    #$self->_open_tmp_file();
    #$self->write($file);


}
################################
# POD
################################

=head1 Author:

MGrigorov

=head1 Versions:

0.0.1/2016.12.09 init Development

0.0.2/2017.01.09 new methods Options(), _makeOptionsFromArray,

=head1 Documentation by:

MGrigorov 2017-01-05

=head1 Description:

This module is designed to be a wrapper for linux find command Example:

    my $Finder = SeekAndDestroy->new($Options); #see options bellow 
    my @files = $Finder->get_result();
    say Dumper \@files; # this will take result 

=head1 Options:

        "files_only"           => \$Options->{OnlyFiles},     ### skips directory
        "dir|d=s@"             => \$Options->{Dir},           ### give a dirs to parse  (more than one) if missing pwd is default
        "o=s"                  => \$Options->{Output},        ### Output file Future dev 
        "grep|g=s@"            => \$Options->{Grep},          ### Grep for some files regex (more than one)
        "rgrep|gv=s@",         => \$Options->{RGrep},         ### reverse grep for files    (more than one)
        "help|h",              => \$Options->{Help},          ### Print Help
        "tmp_dir=s",           => \$Options->{TmpDir},        ### custom tmp dir, default pwd/tmp_dir/
        "clean_tmp",           => \$Options->{ClearTmp},      ### ClearTmp dir
=over

=item new

=back

=cut 

1;
