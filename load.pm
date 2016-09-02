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


####################################################################################
#ACT 1          #SEARCH IN EXCEL FILES BY REGEX PATTERNS IN ROW RANGES
####################################################################################
 sub search_in_xls_files  {

#VESION HISTORY
    # version 0.0.7 from 24.02.2015
    # version 0.0.8 from 25.03.2015 add keep_undef_values;
    # version 0.0.9 from 27.03.2015 fix confess if regex_dismatch and add custom_row_start
    # version 0.0.10 form 29.04.2015 comment old CODE options and remove them from POD fix bug that skips zero values
        my $config = shift;
	
	my $data ={};

        confess "The function argument must be hash ref" unless ref($config) =~ /HASH/;
	my ( $map_search_row_range ,$val_search_row_range, $map_pattern, $val_pattern ); 
        my (@coordinates, $sep_tag  );
#	my $global_counter_match_map_value; 
	my $global_counter_match_acc_value;
# 	   d ( "PRINTED_config-for_Search_in_xls_files", $config);
        my $files = $config->{files} if ref $config->{files} eq 'ARRAY';
        if (defined $config->{val_pattern}){ $val_pattern = $config->{val_pattern}}else{ $val_pattern = '.*'; carp "NOTE that val_pattern regex is empty default '.*'"; }; #default value .*
        if (defined $config->{map_pattern}){ $map_pattern = $config->{map_pattern} }else{ $map_pattern = '.*'; carp "NOTE that map_pattern regex is empty default '.*'";}; #default value .*
	 #NEGATIONS REGEX
	my ( $skip_val_pattern, $skip_map_pattern);
        if (defined $config->{skip_val_pattern}){ $skip_val_pattern = $config->{skip_val_pattern}};
        if (defined $config->{skip_map_pattern}){ $skip_map_pattern = $config->{skip_map_pattern}};

	if (defined $config->{map_search_row_range}) { $map_search_row_range = $config->{map_search_row_range}}else{ $map_search_row_range = '0,10'}; # define default map_pattern for range
	if (defined $config->{values_search_row_range}){ $val_search_row_range = $config->{values_search_row_range} } else {$val_search_row_range = '0,10'};# define default value for range
        if (defined $config->{sep_tag}) { $sep_tag = $config->{sep_tag} } else { $sep_tag = "\t"}; # default sep tag is tab \t 
        my $clean_add_mapping = $config->{clean_add_mapping}; #if $config->{clean_add_mapping};
        my $clean_acc_values = $config->{clean_acc_values}; #if $config->{clean_acc_values};
        my $clean_matched = $config->{clean_matched}; #if $config->{clean_matched};
        my $clean_file_title = $config->{clean_file_title}; #if $config->{clean_file_title};
        my $skip_zero_values = $config->{skip_zero_values}; #
	my $keep_undef_values = $config->{keep_undef_values};
	my $IgnoreMisMatch = $config->{ignore_die_regex_mismatch};
	my $CustomRowStartMapping = $config->{custom_map_row_start};
	 unless ( defined $config->{allow_more_map} and $config->{allow_more_map} =~ /^y$/i ) { #Allow more than one mapping column coordinates default does NOT allow
		$config->{allow_more_map} = 'N';
		}
	my @merge_coordinates = @{$config->{merge_coordinates}} if defined $config->{merge_coordinates};
        confess "DIED: please give me some excel files[@{$files}] they are are Manda!" unless $files;
        confess "DIED:Wrong value range[$val_search_row_range], must be coma separated numbers\n" unless my ($val_custom_row_start, $val_custom_row_end) = $val_search_row_range =~ /(\d+),(\d+)/;
        confess "DIED:Wrong value range[$val_search_row_range] Staring row($val_custom_row_start) must be smaller or eq than ending row($val_custom_row_end)" unless ($val_custom_row_start <= $val_custom_row_end);
        confess "DIED:Wrong mapping range[$map_search_row_range], must be coma separated numbers\n" unless my ($map_custom_row_start, $map_custom_row_end) = $map_search_row_range =~ /(\d+),(\d+)/;
        confess "DIED:Wrong mapping range[$map_search_row_range] Staring row($map_custom_row_start) must be smaller or eq than ending row($map_custom_row_end)" unless ($map_custom_row_start <= $map_custom_row_end);

#take data from file_paths
	my $seen_map = {};
 
	for my $file (@{$files}) { #cycle files
		my $map_counterFile; my $val_counterFile; my $before_skip_val_counter;
#		$data->{$file} = main::readExcelContent({ 'FILE_PATH' => $file}); ## read excel in hash
		$data->{$file} = ParseUtils::readExcelContent({ 'FILE_PATH' => $file}); ## read excel in hash
			confess "Cant read file[$file] Probably is not excel\n" unless (keys %{$data}) ;

#		d( "Whole_excel-", %{$data}); #DEBUG
		for my $sheetname (sort keys %{$data->{$file}}) { #cycle sheets
#			d ("sheetname", $sheetname);

			my $row_max = $#{$data->{$file}->{$sheetname}};
			$seen_map->{$file}->{$sheetname} = 0; #this hash is used to prevent more mapping columns for uniq file and uniq sheetname

			my %seen_col; #to check if column is already seen/exists

                   for my $row (0 .. $row_max ) { #cycle ROWS
			my $col_max =$#{$data->{$file}->{$sheetname}->[$row]};

COLUMN:                for my $col (0 .. $#{$data->{$file}->{$sheetname}->[$row]} ) { #cycle cols

			       my $value = $data->{$file}->{$sheetname}->[$row]->[$col];
			       next COLUMN unless $value;
	
#				d ( "value" , $value );
			       if  (($value =~ /$val_pattern/i ) or ($value =~ /$map_pattern/i)) {
#				d ( "MATCH to rexeses", "value[$value] map_Regex[$map_pattern] val_regex[$val_pattern]");
#				 
			       } else {
#				d ( "DONT MATCH ", "value[$value] map_Regex[$map_pattern] val_regex[$val_pattern]");
				       next COLUMN;
			       }

#                        if (exists $seen_col{$col} ) { say "NEXT!!! The column[$col] on row[$row] is already seen"; next COLUMN };

				#Determine MAPPING(accout_names COLUMNS) values in the custom range 
			       if (($row >= $map_custom_row_start ) && ($row <= $map_custom_row_end)) {
#        	                carp "\t\n WARNING: The cell[$value] in (File[$file]   sheet[$sheetname] row[$row] col[$col])\n\t matches on both regexes for_value[$val_pattern] and map[$map_pattern]" if (($value =~ /$val_pattern/i ) and ($value =~ /$map_pattern/i));
#				       d ( "Matched MAPPING Val regex[$map_pattern] row_range[$map_custom_row_start - $map_custom_row_end]", "--IN--File[$file]::Sheetname[$sheetname]::ROW[$row]::COL[$col]::row_end[$row_max]::col_end[$col_max]\n\tValue[$value]\n");
#                                d ( "Matched MAPPING Val regex[$map_pattern] row_range[$map_custom_row_start - $map_custom_row_end]-p-", "--IN--File[$file]::Sheetname[$sheetname]::ROW[$row]::COL[$col]::row_end[$row_max]::col_end[$col_max]\n\tValue[$value]\n");

				       if ($value =~ /$map_pattern/) {  #Deretmine witch coordinates are for mapping
						$map_counterFile ++;
					       next COLUMN if defined $skip_map_pattern and $value =~ /$skip_map_pattern/; # skip if skip_map_pattern and value matches
						       my %coord_values = (
								       file=>$file,
								       sheetname=>$sheetname,
								       value=>$value,
								       range_row_start=>$map_custom_row_start,
								       range_row_end=>$row_max,
								       range_col_start=>$col,
								       range_col_end=>$col_max,
								       map=>1,
								       );
#                               say "MAP-Matched IN  -File[$file]::Sheet[$sheetname]::Searched_row_range[$map_search_row_range]::ROW[$row]::COL[$col]::row_end[$row_max]::col_end[$col_max]::Val[$value]";
#					       $global_counter_match_map_value++;

					       if ( $seen_map->{$file}->{$sheetname} == 0 ) {
						       push @coordinates, \%coord_values;
#					say Dumper \%coord_values;
						       $seen_map->{$file}->{$sheetname} = 1 if $config->{allow_more_map} eq 'N'; #this hash is used to prevent more mapping columns for uniq file and uniq sheetname
					       }
				       }

			       } #END IF ROWS RANGE FOR MAPPING 

				#Determine Acount_Values in the custom range 
			       if (($row >= $val_custom_row_start ) && ($row <= $val_custom_row_end)) {
				       if ($value =~ /$val_pattern/) {
						$before_skip_val_counter++;
					       next COLUMN if defined $skip_val_pattern and $value =~ /$skip_val_pattern/; # skip if skip_val_pattern 
						$val_counterFile++;

					       $global_counter_match_acc_value++; 
					       my %coord_values = (
							       file=>$file,
							       sheetname=>$sheetname,
							       value=>"$value<$global_counter_match_acc_value>",
							       range_row_start=>$val_custom_row_start,
							       range_row_end=>$row_max,
							       range_col_start=>$col,
							       range_col_end=>$col_max,
							       map=>'0',
							       );

					       if (@merge_coordinates) { # Merge method: Merge cell value from some other cells if necessary 
						       for my $coord (@merge_coordinates) {
#						say Dumper $coord;
							       openlog ("This coordinates does not meet standart requrements ex:/-?\\d{1,2},-?\\d{1,2}/ [$coord]") unless $coord =~ /-?\d{1,2},-?\d{1,2}/;
							       confess "This coordinates does not meet standart requrements ex:/-?\\d{1,2},-?\\d{1,2}/ [$coord]" unless $coord =~ /-?\d{1,2},-?\d{1,2}/;
							       my ($y,$x) = $coord =~ /(-?\d{1,2}),(-?\d{1,2})/;
							       my $new_x = $row - ($x);
							       my $new_y = $col + ($y);
							       my $merged = $data->{$file}->{$sheetname}->[$new_x]->[$new_y];
							       $coord_values{value} = "<$merged>$coord_values{value}";
						       } 				
					       }

					       push @coordinates, \%coord_values;
				       } 
			       }

#			$seen_col{$col} = 1;

		       } #END OF FOR COL CICLE
  		}   undef(%seen_col); #say Dumper{%seen}; say "UNDEF"; #END OF FOR ROW CYCLE

            } # end sheet for 

	   unless ($IgnoreMisMatch) {
	   openlog ("Err:There is no matched cell to mapping regex[$map_pattern] in file[$file]") unless $map_counterFile;
	   openlog ("\nERROR: There is no matched cell to val_regex[$val_pattern] in file[$file] or all skiped- skip_counter[$before_skip_val_counter]") unless $val_counterFile; 

	   confess "\nERROR: There is no matched cell to mapping regex[$map_pattern] in file[$file]" unless $map_counterFile; 
	   confess "\nERROR: There is no matched cell to val_regex[$val_pattern] in file[$file] or all skiped- skip_counter[$before_skip_val_counter]" unless $val_counterFile; 
	   } 

	} #end of files for
 
        my $num = @coordinates;
        print "\nFYI:The number of taken coordinates columns are num[$num]\n";
        openlog( "The number of taken coordinates columns are num[$num]");

        ######################################################################################
        #ACT-1.1        #TAKE VALUES AND MAPPING FROM COORDINATES
        ######################################################################################
	#ACT-1.1.1   MAP COORD

        my $out_hash = {}; my $map_hash = {}; my $stored_map = {}; 

MAP:    for my $i (0 .. $#coordinates ) { #cycle all coordinates 
		my $map = $coordinates[$i]{map};
		my $row = $coordinates[$i]{range_row_start};
		my $row_max = $coordinates[$i]{range_row_end};
		my $col = $coordinates[$i]{range_col_start};
		my $file = $coordinates[$i]{file};
		my $sheetname = $coordinates[$i]{sheetname};

		if ($CustomRowStartMapping) {
		    openlog ( "Err:Invalid row number to start [$CustomRowStartMapping]") unless $CustomRowStartMapping =~ /^\d+$/ and $CustomRowStartMapping > $row_max;
		    confess "\nERROR: Invalid row number to start [$CustomRowStartMapping]" unless $CustomRowStartMapping =~ /^\d+$/ and $CustomRowStartMapping > $row_max;
                    $row = $CustomRowStartMapping; 
		}

#		say Dumper $coordinates[$i];	
		if ($map eq 1){
			#CREATING MAPPING HASH
ROWS:                for my $current_row($row .. $row_max) { #for every row of desired column TAKE MAPPING
			     my $value = $data->{$file}->{$sheetname}->[$current_row]->[$col];
#cleaning function

			     if ($value) {
				     if (defined $stored_map->{$file}->{$sheetname}->{$current_row}) {
					if ( $config->{allow_more_map} =~ /^Y$/i) {
						     $stored_map->{$file}->{$sheetname}->{$current_row} .= "<septag>$value";
							}
					     } else {
       				     $stored_map->{$file}->{$sheetname}->{$current_row} = $value;
				     }
			     }
#			     d ( "Takan value for mapping from File[$file]::Sheet[$sheetname]::Row[$current_row]::Col[$col]-d-4", $value);
			#ADD ALIAS BEFORE CLEANING
		     }
#			say "MAPPING from " . Dumper $coordinates[$i];
#			say Dumper $stored_map;
			#### USE DIGGER FOR DUPLICATION CHECK ####

	openlog ("There is some problem with map_hash, please review you config\n") unless defined $map_hash;
	confess "There is some problem with map_hash, please review you config\n" unless defined $map_hash;

		} # end if map
	}

	# ACTUAL MAPPING 
	if (ref($clean_add_mapping) =~ /CODE/ ) {

#USING NEST HASH TOOLS
		my $modify_mapping = sub {
			my $digger_params = shift;
#					say Dumper $digger_params;
			my @array = @{$digger_params->{keys}};#................# Hash Keys and values
				my @map_array = @{$digger_params->{history}};#............ # History array with keys values;
			my @duplicated;
			if ( $digger_params->{duplicated} ) {
				 @duplicated = @{$digger_params->{duplicated}};#.... # Duplicated values in array;
			} 

		
			my $file  = $array[0];
			my $value = $array[-1];
			my $current_row = $array[-2];
			my $sheetname = $array[-3];

			my $my_params = {
				value=>$value,
				history_array=>\@map_array,
				current_row=>$current_row,
				sheetname=>$sheetname,
				filename=>$file,
				duplicated=>\@duplicated,
			};
			my $before_enter_clean_add_mapping = $value; 
			$value = &$clean_add_mapping($my_params);

			if (( not defined $value) || ( $value eq '') || $value =~ /^REJECTED/i ) {
#						      carp "Skipping value clean_add_mapping [$before_enter_clean_add_mapping]"  if $config->{debug} =~ /^Y$/;
#				deb ( "SKIPPING_Clean_map_acc_code-p-", "val[$value] before[$before_enter_clean_add_mapping]"); 
			}

			$array[-3] = $sheetname;
			$array[-2] = $current_row	;
			$array[-1] = $value;
			$array[0] = $file;
#						die Dumper @array ;
			return @array;
		};

		# DUplicate test for mapping col
		my ($dupp), $map_hash = nest_hash_digger( {input_hash=>$stored_map, sub_modify_values=>$modify_mapping, dup_clean=>$config->{map_duplication_clean}, });
	} else {
		nest_hash_digger( {input_hash=>$stored_map, return=>'array' });
		$map_hash = $stored_map;
	}

	##############################################################
	# ACT 1.1.2. VALUES COORDINATES
	##############################################################
COORD:        for my $i (0 .. $#coordinates ) {
            my $row = $coordinates[$i]{range_row_start};
            my $row_max = $coordinates[$i]{range_row_end};
            my $col = $coordinates[$i]{range_col_start};
            my $col_max = $coordinates[$i]{range_col_end};
            my $file = $coordinates[$i]{file};
            my $sheetname = $coordinates[$i]{sheetname};
            my $matched_value = $coordinates[$i]{value};
            my $map = $coordinates[$i]{map};
#			#DO mached text uniq OLD WAY
#			 $uniq_index++;
#			 $matched_value = "$matched_value<$uniq_index>";
	    
            my $newfile = $file;

ROW:            for my $current_row ($row .. $row_max) { #for every column
			
                     next COORD if $map == 1; 
                    #cleaning phase;
		
#		deb ( "matched_value_from_coordinates-p-", $matched_value);
			no warnings 'uninitialized';
               		 my $value = $data->{$file}->{$sheetname}->[$current_row]->[$col];

#			deb ( "Values BEFORE next unless value - from file[$file] sheet[$sheetname] row[$current_row] col[$col]-p-", $value);
			unless ($keep_undef_values and $keep_undef_values =~ /^Y$/i) {
				next ROW if not defined $value; 
				}

	
			if ( $skip_zero_values and $skip_zero_values =~ /^Y$/i ) { # from config flag 
				next ROW if $value =~ /^0+$/;
			} 

#			say Dumper $map_hash;
#####                    alias    $out_hash->{$newfile}->{$sheetname}->{$matched_value} = $out_hash->{$newfile}->{$sheetname}->{"colunm-$col"}; 
#####                    alias $out_hash->{$newfile}->{$sheetname}->{"column-$col"}->{$current_row} = $out_hash->{$newfile}->{$sheetname}->{$matched_value}->{$current_row};  
                    if (exists $map_hash->{$file}->{$sheetname}->{$current_row}) {
#				deb ( "value-p-", $value );
                    	$out_hash->{$newfile}->{$sheetname}->{$matched_value}->{$current_row} = $value . $sep_tag . "$map_hash->{$file}->{$sheetname}->{$current_row}";
#			say Dumper $out_hash;
####                    alias $out_hash->{$newfile}->{$sheetname}->{"column-$col"}->{$current_row} = $out_hash->{$newfile}->{$sheetname}->{$matched_value}->{$current_row};  
####                    say  ("row $row, col $col, mvaliue[$matched_value]");
			
                     } else {
#		                   $out_hash->{$newfile}->{$sheetname}->{$matched_value}->{$current_row} = $value . $sep_tag . "WARN_MAPPING_NOT_FOUND-File[$file]Sheet[$sheetname]Row[$current_row]";  #NOTE if change NOT_FOUND text must edit line 718/719
###FUTURE ALIASE                   $out_hash->{$newfile}->{$sheetname}->{"column-$col"}->{$current_row} = $value . $sep_tag . "NO_MAPING-File[$file]Sheet[$sheetname]Row[$current_row]";
                    }
                } #end for mapping;

        }

#die say Dumper $out_hash;
#die say Dumper $map_hash;

        return $map_hash, $out_hash;
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
