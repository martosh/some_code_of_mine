#!/usr/bin/perl -w
use strict;
use 5.10.1;
use Data::Dumper;
use lib qw( /home/martosh/scripts/Mmod /home/admin_la/mgrigorov/Mmod /proj/inbox/dataproc/lib );
use ExportingTools;
use YAML;
use Carp;
use Fins::map qw(read_map_excel_file);
use mtools qw(d);

my $file = '/proj/inbox/dataprov/is-oef/bin/IS_OEFINDUFORECASTDATA/config/Mapping.xlsx';

  my $mapping = read_map_excel_file ( {
 
                                 File=>$file, # MANDA 
                                 
                                 Sheetname=>'all_countries', # OPTIONAL
                                 # Please note that it will be mandatory if excel has more than one sheets
 
                                 #Search_Row=>'3', # OPTIONAL (default 0) Takes: number 
                                 # Search_Row=> determines in witch row number you want to look for hash key, and values
 
                                 #Key=>'^RUC$', # MANDA unless inc_rows='solo' or return_nested=>1, Takes string act like regex 
                                 # Key - is actually some regex pattern that will reprecent your keys in retuned hash 
                                 # For example ^RUC$ will take the column from excel that has 'RUC' as value
                                 
                                 #inc_rows=>'Y', #| inc_rows=>solo, # OPTIONAL
                                 #inc_rows=>Y, #Iclude rows Yes will add the excel rows number in the hash keys 
                                 inc_rows=>'solo', #Iclude rows solo will add only the excel rows for hash keys
 
                                 #Values=>[".*", ], # MANDA at least one, takes strings of cells with you want (acts like regex)
                                 Columns_Regex=>['country_name', 'country_code2', 'country_code3' ], # MANDA at least one, takes strings of cells with you want (acts like regex)
                                 # Columns_Regex=> takes array ref with regex patterns that will reprecent your hash values
                                 # For example - this will take NOBRE.. and EXPED.. columns from SearchRow  (same as Key=> but for values)
                                 
                                 #sep_tag=>"<>", #OPTIONAL (default '@') Useful unless return_nested=>1 , Takes string
                                 # sep_tag=> determines separator if you has multiple Values for hash values 
                                 # Example some hash record: 2662344=>Company LANY S.A<>EXPEDIENTE code 44226A<>
 
                                 return_nested=>1, # OPTIONAL (default off) Flag option
                                 # return_nested=> will return nested hash 
                                 # For example:  $key = { 
                                 #                         NOMBRE_COMPANIA =>'Company LANY S.A',
                                 #                         EXPEDIENTE => 'EXPEDIENTE code 44226A',
                                 #                        }
				 clean => sub { my $value = shift; $value =~ s/^\s*|\s*$//g; return $value; }#d "value", $value
                                 } );

d "show result", $mapping;

