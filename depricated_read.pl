#!/usr/bin/perl -w
use Tie::File;
use strict;
use Data::Dumper;
use 5.10.0;
use Carp;
use Cwd;
#use CTAH::CSVtok qw(:compat);



#########################################################
# TODO:
#########################################################
# General Testing
# Speed testing
# See close file handler

# Using the module with @ARGV 
die "Depricated, it was modified";
my $Finder = SeekAndDestroy->new( \@ARGV );

# Using module with hash ref options

#my $Options = {
#    Dir => ['/etc', '/home' ],
#    mir=> '123123',
#    DoNotDie => 1, 
#    Grep => [ 'test' ],
#};

#my $Finder = SeekAndDestroy->new( $Options  );

my @files = $Finder->get_result();

$Finder->qa();

#################################################################
package SeekAndDestroy;
#################################################################
die "Depricated, it was modified";
use strict;
use Data::Dumper;
use 5.10.0;
use Carp;
use Cwd;
#use lib qw(/historical/testexports/mgrigorov/scripts );
use File::Find;
no warnings 'File::Find';
use File::Path qw(make_path );
use Getopt::Long qw(GetOptionsFromArray);
Getopt::Long::Configure qw(ignorecase_always permute);
use File::Basename;
use POSIX 'strftime';

##################################
sub new {
##################################
    my $self = shift;
    my $Options       = shift;
    my $find          = shift;
    my $filledOptions = {};

    # Requires array ref or hash ref

    if ( ref $Options eq 'HASH' ) {    #if you want manually to create hash with Options
        $filledOptions = $Options;

    } elsif ( ref $Options eq 'ARRAY' ) {    # if Options are given via ARGV
        $filledOptions = _makeOptionsFromArray( @{ $Options } );
    } else {
        confess "Error: the object requires argv array ref or hash ref with options";
    }
    # Default move extension for tmp files
    my $date_time = strftime '%Y-%m-%d_%H-%m', gmtime();
    $filledOptions->{ MoveExt } = '.tmp~';
    $self = bless {}, $self;
    $self->{ Options } = $filledOptions;
    $self->{ SeparatorList } = [ '~', ',', '\t' ];
    $self->{ QuotingList } = [ "'", "\"" ];
    $self->{ DefaultErrorFile } = 'qa_errors.txt';
    $self->{ DefaultOutputFile } = "qa_result_$date_time.txt";

    $self->_checkOptions();

    $self->execute_find();

    return $self;
}

##################################
sub _makeOptionsFromArray {
##################################
    my @Options_array = @_;
    my $Options       = {};

    if ($Options_array[0] and $Options_array[0] !~ /^--?/ ){ #prevent user mistake
        confess "Error: Wrong argv. First \@ARGV argumet must start with single or double dash -|-- false arg[$Options_array[0]";
    }

    GetOptionsFromArray(
        \@Options_array,
        "dir|d=s@"    => \$Options->{ Dir },          ### Set dir for search files there 
        "o=s"         => \$Options->{ Output },       ### Output file Future dev
        "grep|g=s@"   => \$Options->{ Grep },         ### Grep for some files regex
        "rgrep|gv=s@" => \$Options->{ RGrep },        ### reverse grep for files
        "help|h"      => \$Options->{ Help },         ### Print Help
        "grep_in_path"=> \$Options->{ GrepPath },     ### Grep options will use whole path
        "separator|sep=s"=> \$Options->{ Separator }, ### Define separator for files
        "do_not_die" => \$Options->{ DoNotDie },      ### Define separator for files
        "quote=s"=> \$Options->{ Quote },             ### Define Quoting of the files you will check 
        "head=i"=> \$Options->{ Head },               ### Define how many lines to take from files for qa
        "line_num=i"=> \$Options->{ OutputLinesForType }, ### Define how many lines to take from files for qa
        "include_dirs" => \$Options->{ IncludeDir },

    ) or confess( "Err: command line arguments are wrong\n" );

    if ( $Options->{ Help } ) {
        say "\tHelp Options:For help use perldoc module_dir/SeenAndDestroy.pm";
        exit 0;
    }

    return $Options;
}
############################
sub _addDirSlash {
############################
    my $self = shift;
    my $dir = shift;
    if ( $dir !~ /\/$/ ) { 
        $dir = $dir . '/' ;
        }   
    return $dir;
}
############################
sub _checkIfExist {
############################
    my $self = shift;
    my $to_check = shift;
    confess "Error: requered param to check if exists" unless $to_check;
    # if no second param default
    my $its_file_to_check = shift;

    if ($its_file_to_check) {
        if ( -f $to_check ) {
          return 1;
        }
        return 0;
    } else {
        if ( -d $to_check ) {
          return 1; 
        }
        return 0;
    }
}

##################################
sub _checkOptions {
##################################
    my $self    = shift;
    my $Options = $self->Options();

    #replace confess 
    sub confess {
        my $to_say = shift;

        if ($Options->{ DoNotDie } ) {
            say $to_say;
        } else {
            Carp::confess ($to_say);
        }
    }

    if ( $Options->{ Dir } and ref $Options->{ Dir } eq 'ARRAY' ) {

        for my $i ( 0 .. $#{ $Options->{ Dir } } ) {
            my $dir = $Options->{ Dir }->[ $i ];
            # check options dirs are they real
            confess "Error: dir[$dir] does not exists" unless $self->_checkIfExist($dir);
            $dir = $self->_addDirSlash($dir);
            $Options->{ Dir }->[ $i ] = $dir;
            
        }

    } else {

        # default behavior for dir Option
        if ( defined $Options->{ Dir } ) {    # if user calls new() with Hash_ref and miss that $Options is array
            my $dir = $Options->{ Dir };
            $Options->{ Dir } = [];
            confess "Error: dir[$dir] does not exists" unless $self->_checkIfExist($dir);
            $dir = $self->_addDirSlash($dir);
            push @{ $Options->{ Dir } }, $dir;
        } else {
            push @{ $Options->{ Dir } }, getcwd();
            carp "\n\tWarning:No dirs given as argument so it will use " . getcwd();
        }
    }

    if ( not defined $Options->{OutputLinesForType} ) {
        $Options->{OutputLinesForType} = 2;  
    }


    if ( not defined $Options->{Head} ) {
        $Options->{Head} = 20;
    } 

   # default Output file 
    if ( not defined $Options->{Output} ) {
            $Options->{Output} =   $self->_addDirSlash( getcwd() ) . $self->{DefaultOutputFile};
    } 

    unless ( $self->_checkIfExist($Options->{Output}, 'checkFile') ) {
        make_path( dirname($Options->{Output}) ); #or confess "Cannot create file [". dirname $Options->{Output} . "] std_err[$!]";
    }

    return $self;

}

################################
sub write_report {
################################
    my $self = shift;
    my $Options = $self->Options();
    my @lines = @_;

    open(my $fh, '>>', $Options->{Output}) or confess "Error: cannot write in file[$Options->{Output}] std_err[$!]";

    for my $line (@lines) {
        print $fh "$line\n";
    }

    close $fh;
}
################################
sub _emptyDir {
################################
    my $self = shift;
    my $dir = shift || confess "Error: missing argument, must be dir_name";
    confess "Error: the desired dir[$dir] to become empty, does not exists" unless -d $dir;
    my $emptyOptions = {};
    $emptyOptions->{ Dir }       = $dir;
    my $newFinder = SeekAndDestroy->new( $emptyOptions );
    my @rm_files = $newFinder->get_result();

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
        return $self->{ Options };
    }
}

##################################
sub execute_find {
##################################
    my $self    = shift;
    my $Options = $self->Options();
    
    find( \&wanted, @{ $Options->{ Dir } }, );

    #File::Find starts this foreach file
    sub wanted {
         confess "Error: file[$File::Find::dir/$_] does not exists" unless -e $_;

        if ( -d $_ ) {#Directory
            unless ($Options->{ IncludeDir }) {
                return
            }
        } else { 
            if ( $_ =~ /$0(?:\.swp)?/ ) { #if file is script itself
                return;
            }
        }

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
    }

    $self->_sort_result();
}

#############################
sub _sort_result {
#############################
    my $self = shift;
    my @result = $self->get_result();
    my $Options = $self->Options();

    if ($#result > 1 ) {
        my @sorted_files = sort { $a cmp $b } @result;
        $Options->{Found} = \@sorted_files;
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
sub qa {
#############################
    my $self   = shift;
    my $Options = $self->Options();
    my @files = $self->get_result();
    my $file_separator;
    my $file_quote;
    my $report = {};

    for my $file (@files) {

        my @head_lines;
        my $seen_types = {};

        # Head -20 if some these are not defined Separator or Quote
        # Guessing separators part if not given
        unless ($Options->{Separator} or $Options->{Quote} ) {

            my $head_code = sub {
                my $line = shift;
                push @head_lines, $line;
            };

            $self->read({ file=>$file, stop_on => $Options->{Head}, code=>$head_code} );
        }

        if ($Options->{Separator} ) {
            $file_separator = $Options->{Separator};
        } else {
            $file_separator = $self->_guess(\@head_lines, 'separator');
        }

        if ($Options->{Quote} ) {
            $file_quote = $Options->{Quote};
        } else {
            $file_quote = $self->_guess(\@head_lines, 'quote');
        }

        # Actual QA

        $report->{CheckedFiles}++;
        #sub is actually foreach line
        $self->write_report( ('###' x 40) . "\n<$file>");

        my $qa_code = sub {
            my $line = shift;
            $report->{CheckedLines}++;
            my $line_num = shift;
            my @occurrence = split /$file_separator/, $line;
            my $sep_occur = $#occurrence;
            confess "Error: no occurence for separator[$file_separator] in file[$file] in line\n[$line]\nline num[$line_num]" unless $sep_occur > 0;
            my $current_line_type = shift @occurrence;

        unless ($seen_types->{$current_line_type} ) {
                $self->write_report ( '=====' x 20 . "\nEvent Type:$current_line_type\nFileCount:$report->{CheckedFiles}\nLineNum:$line_num");
            }
            
            # if current line type was seen more than OutputLinesForType(desired number) don't write to the report 
            if ($seen_types->{$current_line_type} and $seen_types->{$current_line_type}->{counter} <= $Options->{OutputLinesForType} ) {
                $self->write_report ("<$line>");
            }

            $seen_types->{$current_line_type}->{counter}++;

            #if same type as last, and different separator occurs number  from last one - its somethings wrong
            if ($line_num > 1 and $seen_types->{$current_line_type}->{last_occur} and $sep_occur != $seen_types->{$current_line_type}->{last_occur} ) {
                $report->{$file}->{$current_line_type}->{$line_num} = "Sep met[$sep_occur] but last_seen for type [$seen_types->{$current_line_type}->{last_occur}]";
                $report->{WrongLines}++;
            }

            $seen_types->{$current_line_type}->{last_occur} = $sep_occur;
        };
        
         $self->read({ file=>$file, code=>$qa_code} );
    }

    say Dumper $report;

}

########################
sub _guess {
########################
# This method guesses both separator and quoting depends ot what param is given
# Takes \@head_lines, $what_to_guess_sep_or_quoting
    my $self = shift;
    my $head = shift;
    confess "Error: expected argument must be array ref" unless ref $head eq 'ARRAY';
    my $to_Guess = shift;
    my $result = {};

    if ( defined $to_Guess and $to_Guess !~ /separator|quote/i ){
        confess "Error: mandatory parameter is missing or wrong options must be [separator|quote]";
    }

    my $checkList;

    if ( $to_Guess =~ /sep/i ){
        $checkList = $self->{SeparatorList};
    } else {
        $checkList = $self->{QuotingList};
    }

    for my $line (@{$head}) {
        for my $sep_or_quoting (@{$checkList}) {
            my @occurance = split /$sep_or_quoting/, $line;

            $result->{$sep_or_quoting} = $#occurance;
        }
        # split on every element of list
    }


    my $higher_occured = 0;
    my $result_symbol;

    for my $sep_quoting_char ( keys %{$result} ){

        my $occured_number = $result->{$sep_quoting_char};

            if ($occured_number >  $higher_occured ) {
                $higher_occured = $occured_number;
                $result_symbol = $sep_quoting_char;
            }
        }
    
    return $result_symbol;
}


##########################
sub read {
##########################
    my $self = shift;
    my $config = shift || confess "Error: missing manda params";
    confess "Error: param must be hash ref" unless ref $config eq 'HASH';
    my $file = $config->{file};
    confess "File param must be given like hash ref key" unless $file;
    my $lines_to_read = $config->{stop_on};
    my $code = $config->{code};

    my $Options = $self->Options();
    my $fh;

    if ($file =~ /.gz$/) {
        open( $fh, "gunzip -c $file |") or confess "Error open pipe to file[$file]";
    } else {
        open( $fh, '<', $file) or confess "Error:Cannot open [$file] for reading: [$!]";
    }

    my @data;
    my $row_counter;

    while (defined (my $line = <$fh>)) {
        $line =~ s/\R$//;
        $row_counter++;
        if ($code) {
            $line = $code->($line, $row_counter);
        }

        if ($lines_to_read and $lines_to_read > 0 ) {
            last if $row_counter >= $lines_to_read;
        }
    }

#    close $fh or confess "Error: Cannot close [$file]: [$!]";

    return @data;
}

################################
# POD
################################

=head1 Author:

MGrigorov

=head1 Versions Histoty:

0.0.1/2016.12.09 init Development

0.0.2/2017.01.09 new methods Options(), _makeOptionsFromArray,

0.1.0/2017.06.28 Finish Internal Projects 

=head1 

ntation Update:

MGrigorov 2017-07-25 -> Init documentation

MGrigorov 2017-08-11 -> Options described

MGrigorov 2017-09-04 -> Methods described

=head1 General Description:

This module is designed to wrap perl standard File::Find module and to do a QA over Fusion historical report files

Generally the code is separated on two logical parts: finding files via some criteria and read them for QA report
	
    ##### Findind files part  ####

    my $FindAndQA = SeekAndDestroy->new($Options); # Please see options bellow in documentation and see: Internal usage for using options in actual perl

    my @files = $FindAndQA->get_result(); # it will fill @files with founded files for your $Options

    say Dumper \@files; 

    #### QA and actual report part ####

    $FindAndQA->qa(); # This method will perform actual QA and report for founded files 

=head1 Methods:

=over 

=item new()

	#The constructor receive custom options and executes the actual File::Find part	

	my $Options = {
	   Dir => ['/etc', '/home' ],
	   DoNotDie => 1, 
	   Grep => [ 'test' ],
	};

	my $FindAndQA = SeekAndDestroy->new( $Options  );

=item Options()

	This method is designed as setter and getter for Options in hash

	my $currentOptions = $FindAndQA->Options();

	my $Options = { DoNotDie => '1' }; # replace custom options;

=item get_result()
	
	get_result returns found files from your criteria in array

	my $FindAndQA = SeekAndDestroy->new($Options); # Please see options bellow in documentaton and see: Internal usage for using options in actual perl

	my @files = $FindAndQA->get_result(); # it will fill @files with found files for your $Options

	say Dumper \@files;

=item qa()

	This method will perform actual QA step and creates the report for founded files.

    	$FindAndQA->qa();

=item read()

	Method reads file lines and eventually write some data from it into report via write_report() method

	takes hash ref as argument, and available options are the following:
		file=>'/etc/hosts',	 # this is the files
		code => $code_reference, # this param must be code ref as the example below 
		stop_on => '10'          # it will read first 10 lines
	
        my $code_reference = sub {
            my $line = shift; # in our case this will be line from /etc/hosts
            my $line_num = shift; # this is line number 
	    my ($needed_data) = $line =~ /^([^,]+?),/;
	 	# please see write_report() method info
	    $FindAndQA->write_report($needed_data . "\n");
        };

	# As you can see the idea is to read files, take data from them, and finally, write some report or whatever.

        $self->read({ file=>$file, stop_on => '10'}, code=>$code_reference} );

=item write_report()
	
	writes data in report file, which can be set via -o options
	
	Note: see -o options or $Options->{Output} if you create the object options via hash

	$FindAndQA->write_report( "Line in report file\n");

=back

=head1 Options:

=over 

=item dir|d 
	

	dir=/var/log d=/etc/ - In witch directory to search recursively. 

	Note:You can give multiple dir options

	Default: if no dir option it will take cwd and it will search recursivly there 

        Internal usage:  $Options->{Dir} = [ /var/log, /home/test/ ];

        Idea: Maybe it will be good idea to be available option with a level how deep to search for it will be quite easy

           
=item o

	o=/home/my_sky_report.txt - Where to put the final report text file

	Default: it will put the file in cwd named as "qa_result_$date_$time.txt";

        Internal usage: $Options->{Output} 

	Note: you can change default name if you don't like it - in constructor variable $self->{ DefaultOutputFile } = "qa_result_$date_time.txt" 

	Note: if file exists already second start in same time-stamp (same minute) will append the files not replace it


=item grep|g 

	g=cellid g=test grep=something - Grep allows you to filter found files with -dir|d option 

        Internal usage: my $Options->{Grep} = [ 'rest', 'test' ];

	Note: every grep|g options is actually used as regular expression so g='test(:?ing)' reg should work 
	
	Note: you can give multiple grep arguments and  multiple greps will include files independantly 
              For example you if you give g=Lepa g=Zvonko it will find both independetly files with Lepa and Zvonko not file that have both patterns

	Note: if you want your greps to be applied in the file paths as well, you will need -grep_in_path option
	
	Idea: maybe dependent grep will be good idea for option



=item rgrep|gv

	rgrep=dont_include_this gv=and_this - this works like reverse grep so omits regex pattern from your found files

        Internal usage: my $Options->{RGrep} = [ 'rest', 'test' ];

	Note: You can give multiple rgrep|gv options.

	Note: Because works as regex if you give rgrep=. this match to everything so it will omit all found files in the given dirs

	Note: if you want your reverse greps to be applied in the file paths as well, you will need -grep_in_path option


=item grep_in_path 

	-grep_in_path - works like flag, when it's turned on allows options grep|g and rgrep|gv to applied regex to the whole path

	Internal usage: my $Options->{GrepPath} = 1;

	Note: Please, take a look at grep|g and rgrep|gv options


=item do_not_die 
	
	-do_not_die - works as flag, and when it's turned on replaces confess function with say useful to finish your report regarding the problems


=item separator|sep

	-separator|sep=',' - allow you to give separator for your something separated files, (format mostly used for the Fusion hitorical reports) 

	Default: If NO separator option given the module will try to guess the separator ( see head option, it's related )

	Internal usage: my $Options->{ Separator } = ',';

	Note: The module will search only in default list with separators $self->{ SeparatorList } = [ '~', ',', '\t' ] you can change it if you want

	Note: The module will work faster if you give that option, not to guess it

 
=item quote

	-quote='"' - allows you to give the quoting for your read historical reports files 

	Default: If NO quote options given the module will try to guess it (see head option, it's related )

	Internal usage: my $Options->{ Quote } = '\"';

	Note: The module will search only in default list with quotes $self->{ QuotingList } = [ "'", "\"" ];

	Note; The module will work faster if you give that option, not to guess it


=item head 
	
	head=10 - this option won't be useful probably, this is actually related with guessing functionallity.It will take 10 lines for guessing separator or quote
	
	Default: for guessing takes first 20 lines foreach file

	Internal usage: my $Options->{Head} = 20;

	Idea: Maybe it will be good to change the default to 10 instead 20

		
=item line_num

	line_num=5 - the final QA report will print 5 lines for each data type

	Default: Two lines for each data type
	
        Internal usage:  my $Options->{ OutputLinesForType } = 5


=back


=head1 Examples:

    perl read.pl -include_dirs -g=script -g=cellid -grep_in_path  

	# this will find files that are in current dir because there is no -dir option, i
        # It will search for script and cellid keyword in files , 
        # -grep_in_path with this greps are working on the fillpaths otherwise greps are applied only for the basename of the files


=cut 

1;
