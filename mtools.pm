package mtools;

use warnings;
no warnings 'utf8';
use strict;
use 5.10.1;
use Carp;
use Data::Dumper;
use File::Basename;
use File::Path qw(make_path remove_tree);
use File::Slurp;
use Exporter 'import'; 
use List::MoreUtils qw( uniq );
use HTML::Entities;
our @EXPORT_OK = qw(d match_from_filename toTitleCaseM ls_dir script_time duplicate_check uniqr splitFork english_text english_text_old removeDuplicateLines readDumpInHash fileToString);
#say "#Exporter from mtools test";
#say Dumper @EXPORT_OK;

#seek DATA, 0, 0; #move DATA back to package
#our @EXPORT_OK = map { /\s*sub\s+([^\s\{\(]+)/ ? $1 : () } <DATA>;

# This module implements a few small methods that tend to be useful
# 

# IDEAS:
	# @array = ( 1 2 3 4 55 5555 );
	# return me diffs with /^.{5}/ 
		# map with regex and seen++ 

=head1 NAME

mtools - some independent tools used by MGrigorov for different purposes 

=head1 DESCRIPTION

 
This module exports the following functions:
C<d> C<match_from_filename>  C<toTitleCaseM> C<ls_dir> C<script_time> C<duplicate_check>  C<uniqr> C<splitFork> C<english_text> C<english_text_old> C<removeDuplicateLines>

=over

=item *
 
=cut
############################################################
# MGrigovor's debug function
############################################################

############################################################
# Usage: NOTE that if more than one argument given, if first defined argument and non referenced arguments will acts as debug text
				# It will be good if you want to debug @ % or Object to give them in this function as reference with '\' Example: d ('asdasd', \@array, \%hash);

sub d {
# TODO: Try to use Log4Perl if need with -log
# ver 0.0.2  2015.06.09 Creation 
# ver 0.0.3  2015.06.22 Add Another pause in end 
# ver 0.0.4  2015.07.07 add output file with -f 
# ver 0.0.5  2015.07.31 correct dump in file -f 
# ver 0.0.6  2016.01.26 fix if $/ is changed (bug) 

	my $debugText = shift;
	my $options = {};
	my $oneArg = 0;
	my $def_separator;
	if (  not defined $/ or $/ !~ /\n/ ) {
		$def_separator = $/;	
		$/ = "\n";
	}

	unless (@_){ #if only one argument
		$oneArg = 1; 
	}

	if (ref $debugText or $oneArg == 1) {
	    unshift @_, $debugText;     
	    $debugText = 'Debuging..';	    
	} else {
	     $debugText = 'Debuging..' if not defined $debugText;
	}
	
	if ($debugText =~ /-s-?(\d+\.?\d*)?/) {
		if ($1){ $options->{s} = $1; } else { $options->{s} = '1.4' }; 
	}

	if ($debugText =~ /-fd?-(.*)/) {
		if ($1){ 
			$options->{f} = $1;
		} else {
			 $options->{f} = '/tmp/ddump.log'
		} 
		$options->{dump} = 1  if $debugText =~ /-fd-/;
	}

	my $notRefFlag; 
	while (@_) {
		my $toShow = shift;
		$toShow = 'warning----UNDEFINED----' unless defined $toShow;		

		unless (ref $toShow) {
		 	$notRefFlag ++;
		}

		if ($options->{f} ){	# This may be done in one line just $fh = <STDIN>;	
			say "\n\t\tDUMPED IN FILE [$options->{f}]->>[$debugText]<<-";
		        open(my $fh, ">>", "$options->{f}") or confess "D:Cannot open >> file[$options->{f}]:Err[$!]";

			if ( $options->{dump} ) {	
				say $fh Data::Dumper->Dump( [$toShow], [qw(*dump)]); 
			} else {
				say $fh Dumper $toShow;
			}

			close $fh;
			next;
		}
		
		say "\n\t\tSTART-DEBUG->>[$debugText]<<-";

		if ( $options->{s}) {
			sleep $options->{s};
		} else {
			<STDIN>;
		}

		if ($notRefFlag) {
			say $toShow;
		} else {
			say Dumper $toShow;
		}

		say "\n\t\t>>END[$debugText]<<\n";
		unless ($options->{s} or $options->{f} ) {
		<STDIN>;
		}

		undef $notRefFlag;
	}	

	$/ = $def_separator if $def_separator;
	
}

#########################
 # map array and uniq
#########################

=item *
I<uniqr>

		 Map some array and return uniq values of mapped array 
			Example : my @array = ( 1.. 100 );
				my $return = uniqr ( \@array, '(^.{1})' );
				This will return array eq to ( 1 .. 9 );
		
=cut

sub uniqr {
	# Version 0.0.1 2015.04.27 
	my $array = shift || confess "Error: you need to give some array as argument";
	my $regex = shift || confess "Error: you need to give some regex as argument";
	confess "The first argument must be array ref" unless ref $array eq 'ARRAY';

	my $valid_regex = eval { qr/$regex/ };
	confess "Died:- invalid regex: $@" if $@;
	confess "\nDied: Your regex does not have catching brackets\n" unless $regex =~ /\(.*?\)/;
	my $resultArray = [];
	my $counter = 0;
	
	for my $e ( @{$array} ) {
		if ( $e =~ /$regex/ ) {
			push @{$resultArray}, $1;
			$counter ++;
		} else {
			push @{$resultArray}, $e;
		}
	}

	carp "No one element was matched to your regex [$regex]" unless $counter > 0; 
	my @Array = uniq(@{$resultArray}); 
	return \@Array;
	
}

###########################
# remove duplicate lines from file
###########################

=item * I<removeDuplicateLines>
		
	This method reads file and remove duplicated names from it are print it again
			Example :
	   			 removeDuplicateLines( $Csv_File_Path, $fixed_file ); # src_path, result_dst_path; 
				 removeDuplicateLines( $some_file ) # this will create $some_file . '.dupfix' named fixed file
		
=cut
sub removeDuplicateLines {
    # Version 0.0.1 2015.10.28

    my $src_path = shift || confess "Err: some csv file path expected";
    my $dst_path = shift;
    unless ($dst_path) { $dst_path = "$src_path.dupfix" }

    my $dst_dir = dirname($dst_path);
    unless ( -d $dst_dir ) {    # create it
        make_path($dst_path);
    }

    if ( -f $src_path ) {
        my @lines = read_file($src_path);
        @lines = uniq(@lines);
        open( my $FH, ">:encoding(UTF-8)", $dst_path ) or confess "Err:cannot open fh > [$dst_path][$!]";

        for my $line (@lines) {
            local $/;
            print {$FH} $line;
        }
        close $FH;
    } else {
        confess "Err: src path is not valid[$src_path]";
    }

}
########################
# English text
########################

sub english_text {
       my $text = shift || return '';
       ### all LATIN 1,2
#        $text = 'UTILIDAD (PÉRDIDA) OPERATIVA';
#d "start text", $text;
       my @char = split '', $text;

          for (@char){
#		d "start", $_;
		   tr/À/A/;
		   tr/Á/A/;
		   tr/Â/A/;
		   tr/Ã/A/;
		   tr/Ä/A/;
		   tr/Å/A/;
		   tr/Æ/A/;
		   tr/Ç/C/;
		   tr/È/E/;
		   tr/É/E/;
		   tr/Ê/E/;
		   tr/Ë/E/;
		   tr/Ì/I/;
		   tr/Í/I/;
		   tr/Î/I/;
		   tr/Ï/I/;
		   tr/Ð/D/;
		   tr/Ñ/N/;
		   tr/Ò/O/;
		   tr/Ó/O/;
		   tr/Ô/O/;
		   tr/Õ/O/;
		   tr/Ö/O/;
		   tr/Ø/O/;
		   tr/Ù/U/;
		   tr/Ú/U/;
		   tr/Û/U/;
		   tr/Ü/U/;
		   tr/Ý/Y/;
		   tr/Þ/Y/;
		   tr/ß/Y/;
		   tr/Š/S/;
		   tr/Ť/T/;
		   tr/Ž/Z/;
		   tr/Ľ/L/;
		   tr/Č/C/;
		   tr/Ě/E/;
		   tr/Ď/D/;
		   tr/Ň/N/;
		   tr/Ř/R/;
		   tr/Ů/U/;
		   tr/Ĺ/L/;
		   tr/Ł/L/;
		   tr/Ą/A/;
		   tr/Ż/Z/;
		   tr/Ę/E/;
		   tr/Ć/C/;
		   tr/Ń/N/;
		   tr/Ś/S/;
		   tr/Ź/Z/;
		   tr/Ă/A/;
		   tr/Ş/S/;
		   tr/Ţ/T/;
		   tr/Đ/D/;
		   tr/Ő/O/;
		   tr/Ű/U/;
		   tr/à/a/;
		   tr/á/a/;
		   tr/â/a/;
		   tr/ã/a/;
		   tr/ä/a/;
		   tr/å/a/;
		   tr/æ/a/;
		   tr/ç/c/;
		   tr/è/e/;
		   tr/é/e/;
		   tr/ê/e/;
		   tr/ë/e/;
		   tr/ì/i/;
		   tr/í/i/;
		   tr/î/i/;
		   tr/ï/i/;
		   tr/ð/d/;
		   tr/ñ/n/;
		   tr/ò/o/;
		   tr/ó/o/;
		   tr/ô/o/;
		   tr/õ/o/;
		   tr/ö/o/;
		   tr/ø/o/;
		   tr/ù/u/;
		   tr/ú/u/;
		   tr/û/u/;
		   tr/ü/u/;
		   tr/ý/y/;
		   tr/þ/y/;
		   tr/ÿ/y/;
		   tr/š/s/;
		   tr/ť/t/;
		   tr/ž/z/;
		   tr/ľ/l/;
		   tr/č/c/;
		   tr/ě/e/;
		   tr/ď/d/;
		   tr/ň/n/;
		   tr/ř/r/;
		   tr/ů/u/;
		   tr/ĺ/l/;
		   tr/ł/l/;
		   tr/ą/a/;
		   tr/ż/z/;
		   tr/ę/e/;
		   tr/ć/c/;
		   tr/ń/n/;
		   tr/ś/s/;
		   tr/ź/z/;
		   tr/ă/a/;
		   tr/ş/s/;
		   tr/ţ/t/;
		   tr/đ/d/;
		   tr/ő/o/;
		   tr/ű/u/;
#		d "end", $_;

	}
	

#d "end text", join '', @char;
#       d \@char;   
	
       return join '', @char;
}


##############################################
 # compare two digits number by number
##############################################

# still alfa version
# must be add custom compare sighn <|>
# test what happens if end of some of the strings

sub compare {
        my $string = shift;
        my $string2 = shift;

        my @chars = split('', $string);
        my @chars2 = split('', $string2);

#       say "string[$string], string[$string2]";

CHAR:   for my $char1 (@chars) {
                my $char2 = shift @chars2;
                if ($char1 < $char2) {
                        return $string;
                }
                next CHAR if $char1 == $char2;
                return $string2;
        }
}

#############################################################
#MATCH FROM FILENAME BY PATTERN
#############################################################

=item *
I<match_from_filename>

		 Used for taking some text from filename

                 my $filename="/home/gosho/test123123.txt";
                 my ($matched, $basename, $only_path) = match_from_filename ($filename, '(\d+)');
                 Result: 123123, test123123.txt, /home/gosho/

		 my $matched = match_from_filename($filename, '(.*)' );
		 Result: test123123.txt
		
		 my $file = match_from_filename ( $filename );
		 Result: test123123.txt


=cut

    sub match_from_filename {
	# Version 0.0.1 added wantarray 
	# Version 0.0.2 added defailt pattern/regex .* #2015.07.07
	#Takes something from filename 
	#EXample if push  filename /home/gosho/test123123.txt as argument with '(\d+)' as second argument it will return $1, $filename $path;
        my $file = shift; 
#	my $pattern; 
	my $pattern = shift;
	$pattern = '(.*)' unless $pattern;
        my ($filename, $path)=fileparse($file);
	confess "\nmatch_from_filename:Died: Your regex does not have catching brackets\n" unless $pattern =~ /\(.*?\)/;

        if ( $filename =~ /$pattern/ ) {
	        if (wantarray) {
 	                return $1, $filename, $path;
	        } else {
	            return $1;
	        }
        } else {
            confess "ERROR:regex pattern[$pattern] is probably wrong and does not match in any files[$file]";
        }
    }

############################################################
# Check normal hash or array refs for duplication 
############################################################

=item * 
I<duplicate_check>

		 This functions checks array or hash for duplication (if hash checks values couse keys are uniq by default).Returns array ref or hash ref;

                           EXAMPLE:
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
                                  };

                           my $duplicated = duplicate_check({
                               hash=>$hash,  #.......#MANDA Input structure for duplicate checks #This may be array=>$a_ref or hash=$hash, both of input structures will work  
                               dup_regex=>'(^.{1})', #OPT   Regex to map hash values or array elements(depond of input) example above will check first symbols for duplications
                               dup_clean=>sub { my $v = shift;  $v =~ s/\s*//; return $v; }, # OPT This is function to process evert element here you may add/del spaces or else
		                #      return_hash = 1 # OPT: return hash as output default is array. This will work only if your inpur structure for duplication is hash
                                                   });

			# In this example all values in input hash will be processed trough dup_regex and custom function. 
            # so dup_regex will take only first characters for comparasion and custom function will delete spaces befor duplication check; 
                           say Dumper $duplicated;  returns ['11=>2', '1=>2', '56=>', '71=>', '9=>'] #

=cut 

sub duplicate_check {
	# version 0.0.3 from 25.11.2014
	# version 0.0.4 from 02.04.2015 return undef if no dups
	# version 0.0.5 from 27.04.2016 return hash instead of strings in array Must be rewritten
	# version 0.0.6 from 04.05.2016 fix return hash undef in regex 
    # version 0.0.7 from 18.11.2016 remove one of return array ref witch is useless fix hash_return option and some additional checks
	# this function map (array with regex)argv and after that check for duplication
        
        # CALLING WAY EXAMPLE  my $duplicated = duplicate_check({ hash=>$hash, regex=>"$config->{dup_regex}", dup_clean=>sub {  });
 
	my $cfg = shift;
#	d "mtools::duplicate_check cfg", $cfg;
	my %count; my @out; my $regex; my @array; my $hash; my @duplicated; my @duplicated_a; my $dup_clean;

	if (defined $cfg->{dup_clean} and ref $cfg->{dup_clean} eq "CODE" ){
		$dup_clean = $cfg->{dup_clean};
		} else {
		$dup_clean = sub { return $_[0];};
		}	

	if ($cfg->{dup_regex} ) {
		$regex = $cfg->{dup_regex};
		my $valid_regex = eval { qr/$regex/ };
		confess "Died:- invalid regex: $@" if $@;
		confess "\nDuplicate_check:Died: Your regex does not have catching brackets\n" unless $regex =~ /\(.*?\)/;
		
	} else {
		$regex = '(.*)';
	}


	if (defined $cfg->{array})  {
        confess "Error: array param requires array ref", unless ref $cfg->{array} eq 'ARRAY';
        confess "Error: it is poitless to requere hash result as output in case that the input is array ref" if $cfg->{return_hash};
		@array = @{$cfg->{array}};
	}

	if (defined $cfg->{hash}) {
        confess "Error: 'hash' param requires hash ref", unless ref $cfg->{hash} eq 'HASH';
        confess "Error: there is input 'array' param given as well as 'hash' param in config" if defined $cfg->{array}; 
		$hash = $cfg->{hash};
		@array = values %{$hash}; 
	}

	@out = map { /$regex/ } @array;

		for (@out) {
			$_ = $dup_clean->($_);
#			say $_;
			}

	for (@out) { #Check for DUP 
		push @duplicated_a, $_ if $count{$_}++;
	}

	if ($cfg->{array}) {
		return undef unless @duplicated_a;
		return \@duplicated_a;
		}

	for my $dup (@duplicated_a) { #to tell the keys from start hash (if you choose to use hash ref as input) of duplicated values must do same regex/cleaning
		for my $key (keys %{$hash}) {
			my $value = $hash->{$key};

			if ( $value =~ /$regex/ ) { #default (.*)
				my $matched = $1;
				$matched = $dup_clean->($matched);
				push @duplicated, "$key=>$matched" if $matched eq $dup;
			}
		}
	}

	@duplicated = uniq (@duplicated); #workaround duplication of duplicated :)
	@duplicated = sort (@duplicated); 

	my $result = \@duplicated;
	my $hash_result = {};
	return undef unless @duplicated;

	if ( $cfg->{return_hash} ) { #workaround must be rewritten

		foreach my $dup_value (@duplicated ) {
		 my ($key, $hash_value) = $dup_value =~ /^(.*?)=>(.*)/is; 

		 if (defined $key) {
			unless ($hash_value) {
				$hash_value = '';
			}
			$hash_result->{$key} = $hash_value;
		 } 

		}
		#d "hash_result", $hash_result;	
		$result = $hash_result;
	}
	
	return $result;
}



################################################################################
# Takes one hash and distributo on parts USELESS FOR NOW  
################################################################################
sub round_robin_split {
	my $hash = shift || confess "Died there is no given data to be distributed";
	confess "Died - the given data must be hash ref" unless ref $hash eq 'HASH';
	my $end_number = shift || confess "Died, there is no number to split to";
	$end_number ++;
	confess "Died, the second param must be number" unless $end_number =~ /^\d+$/;
	my $result = {};

	my $num = 1;
DATA:		for my $key ( keys %{$hash} ) {
			$result->{$num}->{$key} = $hash->{$key};
			$num ++;
			$num = 1 if $num eq $end_number; # start again 
		}
	return $result;
}

################################################################################
# Combination of split some list on parts and fork it.
################################################################################

=item * I<splitFork>

		Takes some hash split it on parts and fork each part in separate process

		splitFork ( { 
				list=>$hash,    # MANDA \% to split 
				num=>20 , 	# MANDA $(\d+) on how many parts you want to split the hash
				sub=>$sub 	# MANDA \& Your code with given part of the hash 
				});
		my $sub = sub {
	        my $list = shift;
		for my $url ( keys %{$list} ){ `wget $record` }; # if we have list of urls
        	};

=cut

sub splitFork {
	# version 0.0.0 from 27.05.2015
	# Maybe it will be better the parrent to wait child to finish and to print ps -aux  
	my $config = shift || confess "Error: there is no given configuration";
	confess "Error: the given config must be hash ref" unless ref $config eq 'HASH';
	$config->{num} || confess "Error: you should give num=>'<someNumber>' in conifig hash";
	my $end_number = $config->{num};
	confess "Error: 'num' argument takes only numbers as value" unless $end_number =~ /^\d+$/;
	confess "Error: missing list=>'%\$' to be distributed" unless defined $config->{list};
	confess "Error: list=> param must take hash ref" unless ref $config->{list} eq 'HASH';
	my $hash = $config->{list};
	$end_number ++;
	my $result = {};
	my @pids;
	my $num = 1;

DATA:		for my $key ( keys %{$hash} ) { #round robin 
			$result->{$num}->{$key} = $hash->{$key};
			$num ++;
			$num = 1 if $num eq $end_number; # start again from first part(guy)
		}

#		die Dumper $result;

		if ( $config->{sub} and ref $config->{sub} eq 'CODE' ) {
			my $sub = $config->{sub};
			for my $part ( keys %{$result} ) {
#				my $returned = &$sub( {num=>$part, list=>$result->{$part} });

				my $pid = fork();
				confess  "Died:Could not fork\n" if not defined $pid;

				if ( $pid == 0 ) {
					my $returned = &$sub( $result->{$part} );
					exit;
				} else {
					push @pids, $pid;
				}

			}

					say "\nWARNING\n\nPids are (@pids)\n\nkill -9 @pids\n\n"; 
		} else {
		 	carp "\nWarning: you probably have missed sub=>\$& argument in splitFork config\n";
		 	carp "\nWarning: It will be considered as desired effect. Only split mode: ON\n";
			return $result;
		}
		

}
#############################################################
# Make First Char of word Title
##############################################################

=item *
I<toTitleCaseM>
		Takes some string and make it to Uc First

		Example : my $nvalue = toTitleCaseM("Test rest");
		          say $nvalue ; # return "Test Rest" Not well tested at all

=cut

sub toTitleCaseM {
  #Takes text and return it to 'First Title Case' ; Ver 0.1;
  my $text = shift || return !cluck('$data is empty.');
   $text = join '', map { ucfirst lc } split /(\s+)/, $text;
   $text = join '', map { ucfirst  } split /(\.)/, $text; #Ucfirst before '.'
   
   return $text;
}

##############################################################
#OPEN DIR AND TAKE DATAFILES;
###############################################################
#ACTION SUBS
=item *

I<ls_dir>

		Take for arguments some_data_directory (ex. /inbox/bo-brb/data/), and regex pattern (ex \.txt$) for file extent ion
		if you want to reverse grep use third argument 1;
		Return file_paths in normal array
		
		EXAMPLE:
		      my @files = ls_dir ( "/home/test/", '\.txt$');
		       This will return all files with txt extention from /home/test
		
		      my @files = ls_dir ( "/home/test/", '\.txt$', 1);
		        This will return me all files except txt;

=cut

sub ls_dir {

    # Vesion 0.3 FIX OPENLOG ERR
    # Vesion 0.4 Regex check added 2015.11.23
    # Future Version "Include recursive dirs, include filtering line in find  
    my $data_dir = shift || confess "Err:ls_dir died:Must be used with some directory as argument\n";
    my $pattern = shift;
    $pattern = ".*" unless $pattern;

    my $regex = eval { qr/$pattern/ }; 
    confess "Err:invalid regex[$pattern] $@" if $@;

    if ( $data_dir !~ /\/$/ ) { $data_dir = "$data_dir/"; };    #add / at the end if forgoten

    my ( $reverse_flag, @files );

    if (@_) {
        $reverse_flag = shift;
    } else {
        $reverse_flag = 0;
    }
    my $open_f;
    opendir( my $DIR, $data_dir ) || $open_f++;

    if ($open_f) {
        confess "ls_dir-Err:can't readdir [$data_dir]:[$!]";
    }
    my @all_files;
    my @dir_names = readdir $DIR;

    for (@dir_names) {
	    push @all_files, $_ unless $_ =~/^.$|^..$/;
    }

    closedir $DIR;

    if ( $reverse_flag == 1 ) {
        carp "Warn:ls_dir method - reverse mode ON";
        @files = grep( !/$pattern/i, @all_files );
    } else {
        @files = grep( /$pattern/i,  @all_files );
    }

    #add the whole path
    if (@files) {
        @files = map { $data_dir . $_ } @files;
    }

    return @files;
}


#############################################
# Reading Dump file in hash
#############################################

=item *
I<script_time>

		use mtools (readDumpInHash);
		my $ExecutiveMapping = readDumpInHash( 'someDumpfile.dump');	

=cut

sub readDumpInHash {
	my $file = shift;
	my $text_ref = {};

	if ( -f $file ) {
		$text_ref = do $file;
	} else{
		confess "Error: dump file[$file] does not exists";
	}

	return $text_ref;
}

#############################################
# Reading file in string
#############################################

=item *
I<script_time>

		use mtools (fileToString);
		my $html_Body = fileToString( 'some_file.html');	

=cut

sub fileToString {
        my $file_path = shift or confess "Error: file_path argument is required, but missing";
        open my $fh, '<:encoding(UTF-8)', $file_path or confess "Error:Can't open '$file_path' for reading: std_err[$!]";
        my $file_body;

        if ( ! -f $file_path ) {
                confess "Error: file[$file_path] does not exists";
        }

        while (my $row = <$fh>) {
          $file_body .=  $row;
        }

        return $file_body;
}

###########################################################
  # Prints script time
###########################################################

=item *
I<script_time>

		use mtools (script_time);
		This will print you how many times it takes to the script to finish

=cut

 sub script_time {
	#show how much time the script was working
	#V0.0.3 04.03.2015
	END { 
		unless ($::timeless) {
			print "\n\n\tEND_BLOCK:The script[$0] ran for ", time() - $^T, " seconds\n\n";
			}
		}
}

1;
__DATA__

=back

=head1 AUTHOR

MGrigorov

=cut


=head1 



