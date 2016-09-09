package Fins::load;

use warnings;
#no warnings 'unintialized';
use strict;
use 5.10.1;

use lib qw( /home/martosh/scripts/Mmod/ /home/admin_la/mgrigorov/Mmod /proj/inbox/dataproc/lib);
use Spreadsheet::ParseExcel;
use File::Copy;
use File::Basename;
use Carp;
use Encode;
use Data::Dumper;
use YAML::Dumper;
use List::MoreUtils qw( uniq );
use Exporter 'import';
use mtools qw(d deb openlog);
use Digger::hash;
use Sort::Naturally;
use Cwd;
#use Getopt::Long;
use Getopt::Long qw(GetOptionsFromArray);
use ExportingTools;
Getopt::Long::Configure qw(ignorecase_always permute);
use POSIX qw(strftime);
#our @EXPORT_OK = qw(search_in_xls_files gen_output_files);
our @EXPORT = qw(search_in_xls_files generate_output_files FinsArgvOptions PackAndSend );
#use Data::Dumper::Concise;
#use Data::Alias qw( alias );
#say Dumper \%INC;
#created by MGRIGOROV 01.10.2014 

#############################################################################
##                      DEBUG FINCTIONALITY                                ##
#############################################################################

sub FinsArgvOptions{

	#ver 0.0.5 from 25032015 - Fix Reentername
	#ver 0.0.6 from 27032015 - Add feed-<$somename> in optional reentername
	#ver 0.0.7 from 30032015 - fix reentername bug --feed with high prio and filebase $0 if calls from cron 
	#ver 0.0.8 from 19062015 - fix -o option bug (add / if you forgot) and add -z Options Available for user also add feed= in help  

        my $arrayref = shift || confess "\nDie::FinsOptions empty array\n";
	confess "\nDie:This argument for FinsArgvOption must be array ref\n" unless ref $arrayref eq "ARRAY";
        my $conf = {};
	my @array = @$arrayref;

        chomp foreach @array;

# 	say Dumper @array;

	# Help option does not require reentername
	my $no_files_flag;

	for (@array) {
		&print_help if $_ =~ /^--?h$|^--?help$/i;
		$no_files_flag++ if $_ =~ /^nofiles?$|^NOARGV$/i;
	}
	
	#reentername check

	unless ($no_files_flag) {
	        confess "\nERROR::Not enogh arguments. Minimum arguments are 2. See $0 -h for more info." if ($#array < 1);
	}

	my $name = fileparse($0);
	$name =~ s/\.pl$//i;
	my $debug_reenter = $array[0];
#	deb ( "debug reenter-p-", $debug_reenter);

	if ( $array[0] =~ /EPS|reenter|reentername|^-?-?feed\=(.+)|$name/i ) {

		if (defined $1 ) {
			shift @array;
			$conf->{'reenter'} = $1;		 
		} else {  
	        $conf->{'reenter'} = shift @array; 
		}
	} else {
		confess "ERROR: Bad reentername[$conf->{'reenter'}] from [$debug_reenter].\n Please note that reentername must be similar to $0 otherwise use -feed option\n";
	}


        $conf->{_Status} = GetOptionsFromArray( \@array,
                        's|send-data|send' => \$conf->{Send},   # Sends data with ftp
                        't|test:i' => \$conf->{Test}, 	        # Pack only <num> companies (5 default);
                        'c|clean' => \$conf->{Clean},           # Clean after work, please note that clean will rm zip files only is send is ON
#                       'r|return' => \$conf->{Return},         # If ssh called return output not yet useful
                        'o|out|output-dir=s' => \$conf->{Out},	# Output dir 
                        'l|lookin=s' => \$conf->{SrcDir},	# Source directory for packages 
                        'p|packnum=i' => \$conf->{PackNum},     # Number of files in zip(feeds)
                        'z|zip' => \$conf->{Zip},     		# This option will give .zip extention instead of .send
                        'sleep=i' => \$conf->{Sleep},	        # Sleep number of seconds before send files;
                        'e|extention=s' => \$conf->{Extention},# Determine what extentions list to pack ;
			'fu|ftp-user=s' => \$conf->{ftp_user}, # Define Ftp user to send pack
			'fp|ftp-pass=s' => \$conf->{ftp_pass}, # Define Ftp pass to send pack
#                        'h|help' => \$conf->{Help},           # Print Help 
                        );

	if ( $no_files_flag) {
		$conf->{Files} = "no_files";
	} else {
		my @files_with_path;
		for my $file (@array ) {
			my($filename, $file_dir) = fileparse ($file);

		        if ($file_dir =~ /^\.\/$/ ) { # add path if not added in files
        		        $file_dir = getcwd();
		                $file_dir .= '/';
		        }
			push @files_with_path, "$file_dir$filename";
	
		}
		$conf->{Files} = \@files_with_path; 
	}

	

#	say Dumper $conf;
	if ( defined $conf->{Out}) { 
		confess "\nDie wrong argiments:The o|out option[$conf->{Out}] must be writable directory" unless -d -w $conf->{Out};

	}

	if ( defined $conf->{SrcDir}) { 
		confess "\nDie wrong argiments:The l|lookin option[$conf->{SrcDir}] must be valid directory" unless -d  $conf->{SrcDir};

	}

	sub print_help {

		say "Script $0 USAGE:\n";
		say "\t$0 <REENTERNAME> <file1> <file2> <option> (Note that \$reentername is MANDA)\n";
		say "\tOPTIONS -t|test=<num> Zips <num> companies(default 5)";
		say "\t\tnofiles|noargv\tStart the script without any ARGV files (Note without dashes)";
		say "\t\t<reentername> how to name the feed but if you want specific name is better to use -feed=<\$somename> instead of <REENTERNAME>";
		say "\t\t-s|send\t\tSends zip files to DMP";
		say "\t\t-c|clean\tRemove files, please note that clean will rm zip(feed) only if send is ON(-s) otherwise -c cleans only files";
#		say "\t\t-r|return\tNot yet usefull in deve";
		say "\t\t-o|out=<some_dir>\tDefine output directiry for output zipfiles(default INBOX_PATH . data/)";
		say "\t\t-l|lookin=<some_dir>\tDefine directory path for your yaml|txt file (default DATA_PATH)";
		say "\t\t-p|packnum=<num>\tDetermine how many files it will be in to the feeds #200 default";
		say "\t\t\t\t\tPlease, note that packnum option is ignored if -t is ON";
		say "\t\t-z|zip\tThis option will give you '.zip' extention instead of '.send' extention";
		say "\t\t-sleep=<num_seconds>\tDetermines how many seconds to wait before sending next package to DMP -Defalt 120 sec";
		say "\t\t-e|extentions=<ext1,ext2,..>\tDetermines what file extentions will be pack (defaults are both txt and yaml) NOTE:coma sep string";
		say "\n\t\tNOTE THAT: In order to specify some feedname you can substitude <REENTERNAME> with -feed=\$someFeedName as First option";
			
		exit 0;
	}

        # DO SOME CHECKS;
        # confess($!) unless &checkOptions($conf);
        confess "Error: Options failed: wrong option probably!" unless $conf->{_Status};

        confess "\nDie:Wrong usage! Missing data Files" unless $conf->{'Files'};

	unless ( $conf->{Files} eq 'no_files') {

        for my $file (@{$conf->{Files}}) {
                my $file_without_path =fileparse($file);

                if ( -e $file) {
#       copy("$file","$data_dir$file_without_path") or confess "Die:CANNOT MOVE file[$file] to [$data_dir$file_withouut_path][$!]\n";
#       push @files_for_clean, "$data_dir$file_without_path";
                } else {
                        confess ("DIE:The argument file [$file] does not exists, NOTE ,that for proper work, filenames must NOT contain spaces");
                }
        }

	}

	if (defined $conf->{Test}) {
        $conf->{Test} = 5 if $conf->{Test} == 0; # default zip companies number
	}
#                say Dumper $conf;

        return $conf;
}

#####################################################################################
# FINAL PACK AND SEND 
####################################################################################

sub PackAndSend {

	# Version 0.0.3 2015.03.27 Ommit DATA_PATH check as manda and warn if no INBOX_PATH or Out
	# Version 0.0.4 2015.09.17 Use PosixTime instead of system `date +%F`; 
	my $Options = shift; #TAKE ARGV OPTIONS
	confess "Wrong argument[$Options] must be hash ref" unless ref $Options eq 'HASH';
#	confess "Wrong argument[$Options] must be has \$Options->{DATA_PATH} please add it manually" unless $Options->{DATA_PATH};
	my $output_dir;

	if ( $Options->{INBOX_PATH} ) {
	        $output_dir = $Options->{INBOX_PATH} . "data/" #INBOX_PATH' => '/proj/inbox/dataprov/pe-sunasa/'
		} else {
		if (defined $Options->{Out} ) {
			confess "\nDie wrong Out argument:The o|out option[$Options->{Out}] must be writable directory" unless -d -w $Options->{Out};
			$output_dir = "$Options->{Out}/";
			$output_dir =~ s/\/\/+/\//g;
		} else {
			confess "\nERROR: There is no output dir defined (missing Options INBOX_PATH or Out(-o))";
		} 
	}

	my $date =  strftime("%Y-%m-%d", gmtime);       
	my $time =  strftime ("%H-%M-%S", gmtime);
#	my $date = `date +%F`;
#	my $time = `date +%R`;
#	$time =~ s/:/-/g;

#	chomp ( $date, $time);

	my $pack_number; 
	if (defined $Options->{PackNum}) {
		$pack_number = $Options->{PackNum}; # it will send Custom argument number of files in zip to DMP
	} else {
		$pack_number = 200; # it will send 200 company files in the zip
	}

	my $sleep_seconds;
	if (defined $Options->{Sleep}) {
		$sleep_seconds = $Options->{Sleep}; # Custom time wait before each send zip to DMP 
	} else {
		$sleep_seconds = 60; # Default sleep 
	}

	my @extention;
	 if (defined $Options->{Extention}){
		my $extentions = $Options->{Extention};
		confess "Err: Option 'Extention' must be string, extentions separated with comas ex[txt,pdf]" if ref $extentions;
		@extention = split ',', $extentions;
		} else {
		@extention = qw(txt yaml);
		}


	# Default SrcDir # where are your profiles or fins files 
	if ( not defined $Options->{SrcDir} ) {
				if ($Options->{DATA_PATH} ){
					$Options->{SrcDir} = $Options->{DATA_PATH};
				} else {
				      confess "\nERROR:The \$Options->{DATA_PATH} is missing";
				}
			} else {
			$Options->{SrcDir} =~ s/$/\// unless $Options->{SrcDir} =~ /\/$/; #add '/' to path's end 
			} 

		carp "\nBEFORE PACK:I will search for extentions[@extention] in dir[$Options->{SrcDir}]\n\n";

	my $packets_acontent = ParseUtils::prepare_feed_packets ( {
			file_types_to_send => \@extention,
			in_path => $Options->{SrcDir},
			files_count_in_package =>(defined $Options->{Test} )? $pack_number = $Options->{Test}: $pack_number
			} );


	my $flag;

	foreach my $packet_number ( sort {$a <=> $b } keys %{$packets_acontent} ){
		$flag++;
		
		my $packet_name;

		if ($Options->{Zip} ) {
			$packet_name = $output_dir.$packet_number."_$date-$time-" . $Options->{reenter} . ".zip" ;
			$packet_name =~ s/\.zip\.zip/\.zip/g;
		}else{ 
			$packet_name = $output_dir.$packet_number."_$date-$time-" . $Options->{reenter} . ".send" ;
		}
#    say YAML::Dump($packets_acontent->{$packet_number} ) ;
		my $zip = ArchiveUtils::zip_files($packets_acontent->{$packet_number} , $packet_name );
		my @outfiles= @{$packets_acontent->{$packet_number}};

		if ($zip == 1) { 
			         print "\tZiping files in [$packet_name]-[\n\n";
			         say "\t\t$_" foreach @outfiles; 
				 say "\t\t]";
		        } else {
				confess ("Die:CANNOT zip outfiles[@outfiles], into zip[$packet_name]\n");
			}

#		d "Options", $Options;
		if($Options->{Send}){
			confess "\nERROR:Missing send Options ftp-user and ftp-pass" unless  $Options->{ftp_user} and $Options->{ftp_pass};
			SendUtils::send_files_by_ftp( [$packet_name] , $Options->{ftp_user} , $Options->{ftp_pass} );
			sleep $sleep_seconds;

			if (defined $Options->{Clean}) {
				unlink $packet_name or confess "Error:Cannot unlink pack[$packet_name]err[$!]";
			}
		}

		if (defined $Options->{Clean}) {
#			confess "DIED:Missing \$Options->{OutFiles} in Options hash, please use \$Options->{OutFiles} = &generate_output_files if use Fins::load" unless $Options->{OutFiles};
#			unlink @{$Options->{OutFiles}} if ref $Options->{OutFiles} eq 'ARRAY';
#			say Dumper \@outfiles;
			unlink @outfiles;
			}

		last if $Options->{Test};
	} #END FOREACH

	unless (defined $flag) {
		say Dumper $Options;
		confess "Err: CANNOT DO THE PACKING STAGE, can't find any files for options above.\n Please Note that files for packing use to be in DATA_PATH DIR, you may use -l option to lookup in specific dir\n"  

	}

}



=head1 Author:

MGrigorov

=head1 Version:

0.0.2

=head1 Documentation by:

MGrigorov 2014-11-27

=head1 Description:

Defines arguments template with getOption::long

=cut;


1;
