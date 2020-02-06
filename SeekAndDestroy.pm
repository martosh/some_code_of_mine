###############################################################
package SeekAndDestroy;
###############################################################
use strict;
use Data::Dumper;
use 5.10.0;
use Carp;
use Cwd;
use File::Find;
no warnings 'File::Find';
use File::Path qw(make_path );
use Getopt::Long qw(GetOptionsFromArray);
Getopt::Long::Configure qw(ignorecase_always permute);
use File::Basename;
use POSIX 'strftime';
use File::Find::Rule;

#TODO
# Test GrepInPath or post grep cause it's missing grep on whole path 
# Add pattern for files !!!
#It's good to have a funcion where to have a object of File::Find::Rule type and add more rules

##################################
sub new {
##################################
    my $self = shift;
    my $Options       = shift;
    my $filledOptions = {};

    # Requires array ref or hash ref

    if ( ref $Options eq 'HASH' ) {    #if you want manually to create hash with Options
        $filledOptions = $Options;

    } elsif ( ref $Options eq 'ARRAY' ) {    # if Options are given via ARGV
        $filledOptions = _makeOptionsFromArray( @{ $Options } );
    } else {
#        confess "Error: the object requires argv array ref or hash ref with options";
    }
    # Default move extension for tmp files
    
    $self = bless {}, $self;

    $self->{ Options } = $filledOptions;

    $self->_checkOptions();

#    for my $dir (@{$filledOptions->{Dir}} ) {
        $self->execute_find();
#    }

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
        "head=i"=> \$Options->{ Head },               ### Define how many lines to take from files for qa
        "level|l=i@"=> \$Options->{ Level },               ### Level of deepnes
        "only_dirs|dirs_only" => \$Options->{ OnlyDir },
        "files_only|only_files"   => \$Options->{ OnlyFiles },
        "find_option" => \$Options->{FindOption}, ### Future developement add the options from File::Find::Rule 

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
    #say Dumper $Options;

    if ( $Options->{ Dir } and ref $Options->{ Dir } eq 'ARRAY' ) {
        
        for my $i ( 0 .. $#{ $Options->{ Dir } } ) {
            my $dir = $Options->{ Dir }->[ $i ];
            # check options dirs are they real
            confess "Error: dir[$dir] does not exists or it's not a dir!" unless $self->_checkIfExist($dir);
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

    if ( not defined $Options->{Head} ) {
        $Options->{Head} = 20;
    } 

    if ( defined $Options->{Level} ) {
           #check only two level arguments and next if undef 
           for my $index ( 0 .. 1 ) {
               next unless defined $Options->{Level}->[$index];
               confess "Error: Option Level must be from -9 to 9" unless $Options->{Level}->[$index] =~ /[1-9]/; 
#                    my $level = shift @{$Options->{Level}};

                    if ($Options->{Level}->[$index] > 0 ) {
                        $Options->{MaxDepth} = $Options->{Level}->[$index]; 
                    } else {
                        ($Options->{MinDepth} ) =   $Options->{Level}->[$index] =~ /(\d)/;
                    }
               
           }
    }
    
    return $self;

}

################################
sub write_in {
################################
    # This method was designed for qa but it can be useful here as well
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


#################################
sub execute_find {
##################################
    my $self    = shift;

    my $Options = $self->Options();
    my @files; 

        my $rule =  File::Find::Rule->new;

       if (defined $Options->{ OnlyDir }) {
            $rule->directory();
       }


       if (defined $Options->{ OnlyFiles }) {
            $rule->file();
       }

#
       $rule->not( $rule->new->name(qr/$0(?:\.swp)?/ ) );
       $rule->readable();

         if (defined $Options->{MaxDepth} ) {
                        $rule->maxdepth($Options->{MaxDepth});
         }

         if (defined $Options->{MinDepth} ) {
             $rule->mindepth($Options->{MinDepth});
         }

        if ( $Options->{ Grep } and ref $Options->{ Grep } eq 'ARRAY' ) {
              
            for my $grep ( @{ $Options->{ Grep } } ) {
                $rule->name( qr/$grep/ );
            }

            # Independent greps ??? currently we can use it with '|' for example test|rest 
        } 

        if ( $Options->{ RGrep } and ref $Options->{ RGrep } eq 'ARRAY' ) {
            for my $rgrep ( @{ $Options->{ RGrep } } ) {
               say"rgrep[$rgrep]";
                $rule->not( $rule->new->name( qr/$rgrep/)  );
            }
        }

        @files = $rule->in( @{$Options->{Dir}} );
        # not tested just an idea 
        if ($Options->{grepPath} ) {
            @files = grep /$Options->{grepPath}/, @files;
        }

        $self->{Found} = \@files;
        $self->_sort_result();
}
#############################
sub _sort_result {
#############################
    my $self = shift;
    my @result = $self->get_result();

    if ($#result > 1 ) {
        my @sorted_files = sort { $a cmp $b } @result;
        $self->{Found} = \@sorted_files;
    }

}

#############################
sub get_result {
#############################
    my $self    = shift;

    if ( $self->{ Found } ) {
        return @{ $self->{ Found } };
    } else {
        return undef;
    }
}

#############################
# Get files is same as get_result 
#############################
sub get_files {
    my $self = shift;
    $self->get_result();
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


=head1 General Description:

This module is designed to wrap perl standard File::Find module

Generally the code is separated on two logical parts: finding files via some criteria and read them for QA report
	
    ##### Findind files part  ####

    my $FindAndQA = SeekAndDestroy->new($Options); # Please see options bellow in documentation and see: Internal usage for using options in actual perl

    my @files = $FindAndQA->get_result(); # it will fill @files with founded files for your $Options

    say Dumper \@files; 

=head1 Methods:

=over 

=item new()

	#The constructor receive custom options and executes the actual File::Find part	

	my $Options = {
	   Dir => ['/etc', '/home' ],
	   Grep => [ 'test' ],
	};


=item Options()

	This method is designed as setter and getter for Options in hash

	my $currentOptions = $FindAndQA->Options();

	my $Options = { DoNotDie => '1' }; # replace custom options;

=item get_result()
	
	get_result returns found files from your criteria in array

	my $FindAndQA = SeekAndDestroy->new($Options); # Please see options bellow in documentaton and see: Internal usage for using options in actual perl

	my @files = $FindAndQA->get_result(); # it will fill @files with found files for your $Options

	say Dumper \@files;

=item read()

	Method reads file lines and eventually write some data from it into report via write_report() method

	takes hash ref as argument, and available options are the following:
		file=>'/etc/hosts',	 # this is the files
		code => $code_reference, # this param must be code ref as the example below 
		stop_on => '10'          # it will read first 10 lines and no more
	
        my $code_reference = sub {
            my $line = shift; # in our case this will be line from /etc/hosts
            my $line_num = shift; # this is line number 
	    my ($needed_data) = $line =~ /^([^,]+?),/;
	 	# please see write_report() method info
	    $FindAndQA->write_report($needed_data . "\n");
        };

	# As you can see the idea is to read files, take data from them, and finally, write some report or whatever.

        $self->read({ file=>$file, stop_on => '10'}, code=>$code_reference} );

=back

=head1 Options:

=over 

=item dir|d 
	

	dir=/var/log d=/etc/ - In witch directory to search recursively. 

	Note:You can give multiple dir options

	Default: if no dir option it will take cwd and it will search recursivly there 

        Internal usage:  $Options->{Dir} = [ /var/log, /home/test/ ];

        Idea: Maybe it will be good idea to be available option with a level how deep to search for it will be quite easy


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


=item head 
	
	head=10 - this option won't be useful probably, this is actually related with guessing functionallity.It will take 10 lines for guessing separator or quote
	
	Default: for guessing takes first 20 lines foreach file

	Internal usage: my $Options->{Head} = 20;

	Idea: Maybe it will be good to change the default to 10 instead 20


=back


=head1 Examples:


=cut 

1;
