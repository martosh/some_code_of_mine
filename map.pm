package Fins::map;

use warnings;
use strict;
use 5.10.1;
use lib qw( /home/martosh/scripts/Mmod/ /home/admin_la/mgrigorov/Mmod /proj/inbox/dataproc/lib);
use Spreadsheet::ParseExcel;
require ExportingTools;
use Carp;
use Encode;
use Data::Dumper;
use YAML::Dumper;
use List::MoreUtils qw( uniq );
use Exporter 'import';
our @EXPORT_OK = qw(read_map_excel_file );
use mtools qw(d);
use Sort::Naturally;
require Digger::hash;
#
#created by MGRIGOROV 06.11.2014
# This script is mess, but ... 
# ver 0.0.6  from 18.02.2015 # Fixed all header values taken from excel if inc_row => 'solo'
# ver 0.0.7  from 24.03.2015 # Small text fixes
# ver 0.0.8  from 30.03.2015 # Fix QA checks die unles file -f 
# ver 0.0.9  from 31.03.2015 # Don't include header if nested hash
# ver 0.0.10 from 04.03.2016 # Add specific sheetname;
# ver 0.0.11 from 05.05.2016 # Include cleaning function 

#my $mapa_de_nits = read_map_excel_file ( { File=>$companies_list_excel,  inc_rows=>'solo', Values=>["NOMBRE_COMPANIA"]});
#my $mapa_de_nits = read_map_excel_file ( { File=>$companies_list_excel,  Key=>'^RUC$', Values=>["NOMBRE_COMPANIA", "EXPEDIENTE"], return_nested=>1,});
#my $mapa_de_nits = read_map_excel_file ( { File=>$companies_list_excel,  Key=>'^RUC$', Values=>["NOMBRE_COMPANIA", "EXPEDIENTE"], });

sub read_map_excel_file {

	my $conf = shift;
	confess "\nError: missing config params " unless ref $conf eq 'HASH';
	confess "\nError: Can't open filename[$conf->{File}]" unless -f $conf->{File};

        unless ( defined $conf->{Key} ) {
            confess "\nError: Key column regex is manda" unless defined $conf->{inc_rows} and $conf->{inc_rows} =~ /^solo$/i or defined $conf->{return_nested};
        }

	if ( defined $conf->{Columns_Regex} ) { # workaround for changing config key for Values
		$conf->{Values} = $conf->{Columns_Regex};
	} 

        unless ( defined $conf->{Values} and ref $conf->{Values} eq 'ARRAY' ) {
            confess "\nError: Value column is manda and must be array ref even with one element!";
        }
	
        confess "\nError: File is Manda" unless defined $conf->{File};
        my ( $search_row, $sep_tag );
        my @coords;

        # DEFAULT search_row is 0
        if ( defined $conf->{Search_Row} ) {
            $search_row = $conf->{Search_Row};
        } else {
            $search_row = 0;
        }

        if ( defined $conf->{clean} ) {
	    confess "Error: clean param takes code(function) reference!", unless ref $conf->{clean} eq 'CODE';
        } 

	## DEFAULT SEP TAG
        if ( defined $conf->{sep_tag} ) {
            $sep_tag = $conf->{sep_tag};
        } else {

            if ( $#{ $conf->{Values} } == 0 ) {
                $sep_tag = ''; # Bug values regex may be one but may match on more than one 
            } else {
                $sep_tag = '@';
            }
        }

	my $hash;

	my $data = {};
	$data = ParseUtils::readExcelContent({ 'FILE_PATH' => $conf->{File}}); ## read excel in hash
	confess "Error: Can't read file[$conf->{File}] Probably is not excel\n" unless (keys %{$data});

	# Stretch the excel data 

############## TAKE COORDINATES ###########################
 	my $sheetname_counter;

SHEET: for my $sheetname ( keys %{$data} ) {    #cycle sheets

    #If customer wants to specify the sheetname
    if ( $conf->{Sheetname} ) {
	if ( $sheetname eq $conf->{Sheetname} ) {
	#if ( $sheetname =~ /$conf->{Sheetname}/i ) {
	 	carp "Warning: Found desired sheetname[$conf->{Sheetname}]";
		$sheetname_counter++;
	} else {
		next SHEET;
	}
    }

    my $coord_params                     = {};
    my $match_count_values->{$sheetname} = 0;
    my $match_count_keys->{$sheetname}   = 0;
    my $row_max                          = $#{ $data->{$sheetname} };

    my $col = -1;
    $coord_params = {
        row_start => $search_row,
        last_row  => $#{ $data->{$sheetname} },
        sheetname   => $sheetname,
        values_cols => [],
    };

  COL: for my $value ( @{ $data->{$sheetname}->[$search_row] } ) {
        $col++;

        next COL unless $value;

      CUST_VAL: for my $custom_val_name ( @{ $conf->{Values} } ) {    #desired columns regexes

            #	d ( "map dug take coordinates value- foreach values in data " ,$custom_val_name );

            if ( defined $conf->{inc_rows} and $conf->{inc_rows} =~ /^solo$/i ) {    # dont search for keys if you desired to inclode keys solo as keys
                $coord_params->{key} = "INCLUDE_ROWS_only_rows";

                if ( $conf->{Values} ) {
                    push @{ $coord_params->{values_cols} }, $col if $value =~ /$custom_val_name/;
                } else {
                    push @{ $coord_params->{values_cols} }, $col;
                }

                @{ $coord_params->{values_cols} } = uniq @{ $coord_params->{values_cols} };
                $coord_params->{column} = $col;
            } else {

                next CUST_VAL unless ( $value =~ /$conf->{Key}/ or $value =~ /$custom_val_name/ );

                if ( $value =~ /$conf->{Key}/ and $value =~ /$custom_val_name/ ) {
                    carp "Cell[$value] on col[$col] match for both regex key[$conf->{Key}] and [@{$conf->{Values}}]\n";
                }

                if ( $value =~ /$conf->{Key}/ ) {
                    # d ("match_key_column", "value[$value] col[$col] row[$search_row] sheet[$sheetname]" );
                    $coord_params->{key}    = $value;
                    $coord_params->{column} = $col;
                    $match_count_keys->{$sheetname}++;
                }
            }

            if ( $value =~ /$custom_val_name/ ) {
                #d ( "Map::read_excel-[$value]", $custom_val_name );
                $match_count_values->{$sheetname}++;
                push @{ $coord_params->{values_cols} }, $col;
                #d ( "In VALUE regex dump coordinates", $coord_params );
            }
        } #End of CUST_VAL
    }  # End of COL;

    #d ( "Fins::map counters", "sheetname[$sheetname] k[$match_count_keys->{$sheetname}] v[$match_count_values->{$sheetname}]" );
    unless ( defined $conf->{inc_rows} and $conf->{inc_rows} =~ /^solo$/i ) {    #fix bug if decide to use rows as a keys in hash
        next SHEET unless $match_count_keys->{$sheetname} > 0;
    }

    #confess ("\nError: I don't found any colums mached with regex[@{$conf->{Values}}] at row[$search_row], file[$conf->{File}]") unless defined $match_count_values;
    next SHEET unless $match_count_values->{$sheetname} > 0;
    push @coords, $coord_params;
}    # end cycle sheets

#        d ("Fins::map::coordinates", @coords );
 	
###########  END TAKE COORDINATES #######################

if ($conf->{Sheetname} ) {
	confess "Error: no sheetname found for this name[$conf->{Sheetname}]" unless $sheetname_counter;
}

if ($#coords > 0) {
	confess "Fins::map_WARNING: we have more than one sheet found with your configuration, this function still works with better with one sheet( so please use Sheetname param to specify one!)\n" unless $conf->{Sheetname};
	}

my $nest_hash = {};
# Cycle Coordinate array
COORD: for my $coord_params (@coords) {    #cycle coords

    #		d ( "Coord_params", $coord_params);
    my $sheetname = $coord_params->{sheetname};
    my $row_start = $coord_params->{row_start};
    my $row_last  = $coord_params->{last_row};
    my $column    = $coord_params->{column};

    my $row_counter = 0;
  ROW: for my $row ( $row_start .. $row_last ) {    # foreach row

        $row_counter++;
        next ROW if $row_counter eq 1;
        my $key = $data->{$sheetname}->[$row]->[$column];

        unless ( $conf->{inc_rows} and $conf->{inc_rows} =~ /^solo$/i ) {
            next ROW unless $key;                   #This will skip if there is no value for desired output hash  keys
        }
        #d ( "coord-key", $key );
        my $value;
        my $column_name;

      CUST_COL: for my $values_cols ( @{ $coord_params->{values_cols} } ) {    # take all values from config

            $column_name = $data->{$sheetname}->[$row_start]->[$values_cols];
            # d ( "Coords cycle values_cols", $values_cols);
            my $value_nest = $data->{$sheetname}->[$row]->[$values_cols];

	    if ( $conf->{clean} ) {
			$value_nest = $conf->{clean}($value_nest);
            }
	    	

            if ( defined $data->{$sheetname}->[$row]->[$values_cols] ) {
                my $new_value = $data->{$sheetname}->[$row]->[$values_cols];
		# Cleaning if there is given function
	    	if ( $conf->{clean} ) {
			$new_value = $conf->{clean}($new_value);
        	}

                next CUST_COL unless defined $new_value;
                $value .= "$new_value$sep_tag";
			#d "cleaning", "[$value]";
            }


            if ( defined $conf->{return_nested} ) {

                if ( $conf->{inc_rows} ) {

                    if ( $conf->{inc_rows} eq 'solo' ) {
                        $key = $row;
                        $nest_hash->{$key}->{$column_name} = $value_nest;
                    } else {
                        $nest_hash->{"<$row>$key"}->{$column_name} = $value_nest;
                        $nest_hash->{"<$row>$key"}->{row} = $row;
                    }

                } else {
                    $nest_hash->{"$key"}->{$column_name} = $value_nest;
                }
            }
        }

        unless ( $conf->{return_nested} ) {

            if ( defined $conf->{inc_rows} ) {

                if ( $conf->{inc_rows} =~ /^solo$/i ) {
                    $key = $row;
                } else {
                    $key = "<$row>$key" if $conf->{inc_rows} eq 'Y';
                }
                $hash->{$key} = $value;

            } else {
                $hash->{$key} = $value;
            }
        } #End of Unless

    } #End of foreach ROW

}
	
        undef $data;

        if ( $conf->{return_nested} ) {
            return $nest_hash;
        } else {
            return $hash;
        }

}



#######################################################################################################
# TODO NOTE: 

=head1 Author:

MGrigorov

=head1 Version:

0.0.10 from 04.03.2016 # Add specific sheetname see coments in the code for version description

=head1 Documentation by:

MGrigorov 2014-12-04 v0.1
MGrigorov 2016-05-06 v0.2

=head1 Main Description:

Main module purpose - some mapping tools for parsing excel file, read and modify mappings

Exports function "read_map_excel_file".

=head1 Functions Description:

=head3 read_map_excel_file Function

This function is designed to work with excel files that contains some mapping exported for example from CMT or else.

It can work return nested hash or strath

=over 

=item *
	Explaining:

	my $mapping = read_map_excel_file ( {

				File=>$companies_list_excel_file, # MANDA 
				# takes string of excel file path to parse
				
				Sheetname=>'SomeSheetName', # OPTIONAL
				# Please note that it will be mandatory if excel has more than one sheets

				Search_Row=>'3', # OPTIONAL (default 0) Takes: number 
				# determines in witch row number you want to look for hash key, and values

				Key=>'^RUC$', # MANDA unless inc_rows='solo' or return_nested=>1, Takes string act like regex 
				# regex pattern that will reprecent your keys in retuned hash 
				# For example ^RUC$ will take the column from excel that has 'RUC' and put it in hash keys 
				
				inc_rows=>Y, | inc_rows=>solo, # OPTIONAL
				#inc_rows=>Y, #Include rows Yes will add the excel rows number in the hash keys 
				#inc_rows=>'solo', #Include rows solo will add only the excel rows for hash keys

				Columns_Regex=>["NOMBRE_COMPANIA", "^EXPEDIENTE"], # MANDA at least one, takes strings of cells with you want (acts like regex)
				# this takes array ref with regex patterns that will reprecent your hash values
				# The example above will take NOBRE.. and EXPED.. columns from SearchRow  (same as Key=> but for values)
				
				sep_tag=>"<>", #OPTIONAL (default '@') Useful unless return_nested=>1 , Takes string
				# sep_tag=> determines separator if you has multiple Values for hash values 
				# Example some hash record: 2662344=>Company LANY S.A<>EXPEDIENTE code 44226A<>

				return_nested=>1, # OPTIONAL (default off) Flag option
				# return_nested=> will return nested hash 
				# For example:  $key = { 
				#			  NOMBRE_COMPANIA =>'Company LANY S.A',
				#			  EXPEDIENTE => 'EXPEDIENTE code 44226A',
				#			 }
				clean => sub { my $cell = shift; $cell =~ s/^\s*|\s*$; return $cell }, 
				# takes function reference as arg witch is designed to clean cells values 
				} );

=item *
	Example1:

	Excel file path $naics_file has many header column_names: 'CIIU code'	'CIIU_Description'	'short CIIU code'	'NAICS_code'	'NAICS_description' and more


           my $ciiu2naics = read_map_excel_file ( { File=>$naics_file,  Key=>'^CIIU\s*code$', Values=>['^NAICS\_code', '^CIIU\_Description$', '^NAICS\_description' ], return_nested=>1});

		Dump $ciiu2naics:
		
          'S9603.02' => {
                          'CIIU_Description' => 'se dedica a actividades de alquiler y venta de tumbas, mantenimiento de tumbas y mausoleos.',
                          'NAICS_code' => '812',
                          'NAICS_description' => 'is primarily engaged in personal and laundry services.'
                        },
          'S9609.01' => {
                          'CIIU_Description' => "se dedica a actividades de ba\x{f1}os turcos, saunas y ba\x{f1}os de vapor",
                          'NAICS_code' => '812',
                          'NAICS_description' => 'is primarily engaged in personal and laundry services.'
                        },
          'S9609.04' => {
                          'CIIU_Description' => "se dedica a actividades de relaci\x{f3}n social, como las agencias que se encargan de la contrataci\x{f3}n de acompa\x{f1}antes.",
                          'NAICS_code' => '812',
                          'NAICS_description' => 'is primarily engaged in personal and laundry services.'
                        },

=item * 
	Example2
           my $ciiu2naics = read_map_excel_file ( { File=>$naics_file,  Key=>'^CIIU\s*code$', Values=>['^NAICS\_code', '^CIIU\_Description$', '^NAICS\_description' ], }); #default separator is '@'

	  'S9523.01' => "se dedica a reparaci\x{f3}n y mant... @811@is primarily engaged in repair and maintenance.@",
          'S9523.02' => "se dedica a reparaci\x{f3}n y mant...@811@is primarily engaged in repair and maintenance.@",
          'S9524.01' => "se dedica a retapizado, acabado,.. @811@is primarily engaged in repair and maintenance.@",

            .
 
=back

=head1 ToDo:

multiple sheet working 

=head1 Bugs:

Bug if values regex is one that match on many default separator is missing (in this case use sep_tag);

=head1 Dependencies

Spreadsheet::ParseExcel;

ExportingTools;

=cut

1;

