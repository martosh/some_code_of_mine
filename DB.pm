package Energy::DB; 
#needed to be modified on order to be used in other cases
use strict;
use warnings;
use Data::Dumper;
use 5.10.1;
use Carp;
use lib qw( /home/martosh/scripts/Mmod/ /home/admin_la/mgrigorov/Mmod );
use ExportingTools;
use mtools qw(d); 
use Fins::map qw(read_map_excel_file); 
use Unidecode;
use utf8;
use Sort::Naturally;
use DBI;

#use List::MoreUtils qw(uniq);
#use Benchmark;
#use Memory::Usage;
#use Test::Memory::Cycle;
#my $mu = Memory::Usage->new();

# Author MGrigorov;

###########################################################################
#####                       DEVELOPERS NOTE                          ######
###########################################################################


##############################################################################
################      FUTURE DESCRIPTION AND IDEAS       #####################
##############################################################################
# my $ReportOfMapping = $Energy->report( $report_type ); 
# my $series_id = $Energy->getSeriesID('$mapID + CC_ID + pub_code );


###### ACCESSORS #####
# my $dbi = $Energy->DBI();
# my @Colums = $Energy->getColumNamesFromTable( 'table_name1', 'table_name2' ); ???? Im not sure about this

####### Other methods ####
# my $seriesID = checkInGlobalMapping( $Mnem . $CC );
# my $seriesID = getGlobalMappingSeriesID( '12312312');

# my $seriesID = checkEmisDBSeriesID(   );

## ALGORITHM FOR CREATING NEW TABLES AND SERIES;

# We have DP INFO
# Check In GlobalMappingFor some Series ID by PrivateKey
# If there are no Series in GlobalMap Create New one
	# if there is Created Table in EMIS 
	# else Create one with some series


#################################################################################
# Constructure
#################################################################################
# Please see the pod for method info 
sub new {
	my $self = shift;
	my $params = shift || confess "Error: must give some params here!";
	confess "Error: the params must be hash ref" unless ref $params eq 'HASH';

	unless ($params->{user} and $params->{db_address} and $params->{pub_code} ) {
		confess "Error: some manda params are missing [password, user, db_address, pub_code]";
	}

	#Default password is empty string 
	unless ($params->{password} ){
		$params->{password} = '';
        }	
	# $params->{db_config} is not manda and must contain hash ref;
	unless ( $params->{db_config} ) {
		$params->{db_config} = { PrintError=>1, RaiseError=>0 };
	}
	##db_address=>'dbi:mysql:database=testing;host=10.33.0.170', user=>'nondmp_u', password=>'some_pass', pub_code=>$pub 
	my $dbh = DBI->connect( $params->{db_address} , $params->{user}, $params->{password}, $params->{db_config});
	$self = bless { DBI=> $dbh, pubCode=>$params->{pub_code} }, $self;
	$self->initMappingDB();
	$self->initReportingDB();
	$self->initCountriesDB(); 

	return $self;
}

#################################################################################
  # fillMapFromExcel 
#################################################################################
# Please see the pod down for method info 
#
sub fillMapFromExcel {
    my $self          = shift;
    my $config        = shift || confess "Error: hash ref config is required as argument";
    my $excel_content = $self->_readExcelFile($config);
    confess "Error 'table' param is a must" unless $config->{table};
    confess "Error createColumns is mandatory param - must be array ref" unless $config->{createColumns};
    confess "Error createColumns must be array ref" unless ref $config->{createColumns} eq 'ARRAY';
    #	d  "excel", $excel_content;
    my $dbh          = $self->DBI();
    my @columns      = @{ $config->{createColumns} };
    my $column_names = join ',', @columns;
    my $columns_hash = {};
    my $counter      = 1;
    my @values       = map { $columns_hash->{$_} = $counter++; '?' } @columns;
    my $values       = join ',', @values;
    my $action;
	if ( $config->{action} ) {
		$action = uc $config->{action};
		confess "Error: action must be insert or replace" unless $action =~ /^insert$|^replace$/i;
	} else {
		# default action
		$action = 'REPLACE';
	}
#INSERT INTO countries  ( country_code3 ) VALUES ('BGR') ON DUPLICATE KEY UPDATE country_code3='BGN' #UPPER(asdasd), UPPER( asdasda,)
    my $sth = $dbh->prepare("$action INTO " . $config->{'table'} . " ( $column_names ) VALUES ($values);") or confess "Error can't create Incert statement handler[$DBI::errstr]";

    for my $row ( sort { ncmp( $a, $b ) } keys %{$excel_content} ) {

        for my $column_name ( keys %{ $excel_content->{$row} } ) {
            my $value = $excel_content->{$row}->{$column_name};
            $self->clean( \$value );

            if ( $columns_hash->{$column_name} ) {

                #d "map_num ", $columns_hash->{$column_name};
                #d "row[$row] column[$column_name] ", $value;
                $sth->bind_param( $columns_hash->{$column_name}, $value );
            }

        }

        $sth->execute() or confess "Error: cannot execute statement_handle [$DBI::errstr]";
    }

}

##################################################################################
   # fillGlobalMap
##################################################################################
# Please see pod documentation at the end of the code 

sub fillGlobalMap {
	my $self = shift;
	my $cfg  = shift;
	$cfg->{pub_code} = $self->pubCode();
	confess "Error: pubCode is missing please set the pub code via pubCode() method, see info in pod" if not defined $cfg->{pub_code};
	#manda_keys
	if ( ! $cfg->{map_id} ) {
		confess "Error: missing manda param - 'map_id' from Pub_Local_DB";
	} elsif (! $cfg->{action} ) {
		confess "Error: missing manda param - 'action' as description of what was done";
        } elsif (! $cfg->{series_id} ) {
		confess "Error: missing manda param - 'series_id' for witch seriesID are made changes";
        } elsif (! $cfg->{country_id} ) {
		confess "Error: missing manda param - 'country_id' for witch coutries we made changes";
	} elsif (! $cfg->{frequency} ) {
		confess "Error: missing manda param - 'frequency' for frequency_id we made changes";
	}	
#	 d "cfg ", $cfg;
	my $result = $self->fillDB( $cfg , 'series_mapping', );

}


##################################################################################
   # fillGlobalMap
##################################################################################
# For function description, please see the pod

sub fillDB {
	my $self = shift;
	my $dataToLoad = shift;
	my $table = shift;
	my $action = shift;

	my $dbh  = $self->DBI();

	if ( ref $dataToLoad ne 'HASH' ) {
		confess "Error: requred dataToLoad reference as parameted \$dataToLoad->{column_name} = \$set_value";
	}

	if (not defined $table) {
		confess "Error: table param is mandatory fillDB(\$dataToLoad, \$table)";
	}

	if ( not $action ) {
		 $action = 'REPLACE';
	}

	my @column_names = keys %{$dataToLoad};
	my @values_to_set = values %{$dataToLoad};
	my ($set_in_columns, $set_values );

	for my $i ( 0 .. $#column_names ) {
		$set_in_columns .=  $column_names[$i] . ", ";
		$set_values .=  "'" . $values_to_set[$i] . "', ";
	}
	$set_values =~ s/,\s*$//;
	$set_in_columns =~ s/,\s*$//; 
	my $sql = "$action INTO $table ( $set_in_columns ) VALUES ( $set_values )";
#	d "Show me Sql", $sql;

	my $return = $dbh->do($sql) or confess "Error can't create Incert statement for sql[$sql] handler[$DBI::errstr]";
	return $return;
}

#################################################################################
  # initMappingDB DB that stores mapping info
#################################################################################
# For function description see the pod document down
sub initMappingDB {
	my $self = shift;
	my $dbh = $self->DBI();
	my $pubCode = $self->pubCode();
	confess "Error: pubCode is missing please set the pub code via pubCode() method, see info in pod" unless $pubCode;
	# CREATE TABLES
	my $createMappingSQL = <<"END_SQL";
CREATE TABLE if not exists mapping_$pubCode (
		map_id       INTEGER PRIMARY KEY AUTO_INCREMENT,
		Mnem  VARCHAR(20) NOT NULL,
		Descn VARCHAR(100) NOT NULL,
		Scope INTEGER NULL,
		NAICSCode VARCHAR(20) NULL,
		Exclude BOOLEAN NULL
)
END_SQL
	$dbh->do($createMappingSQL) or confess "Error: can't create table 'mapping' err[$DBI::errstr]"; 
}
##################################################################################
  # initReportBase(); #DB that stores reports 
##################################################################################
# For function description see the pod document down
sub initReportingDB {
	my $self = shift;
	my $dbh = $self->DBI();
	# CREATE TABLES
	my $createReportsSQL = <<'END_SQL';
CREATE TABLE if not exists series_mapping (
		country_id INTEGER NOT NULL,
		map_id    INTEGER NOT NULL,
		update_date  TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
		series_id INTEGER(20) NOT NULL,
		frequency INTEGER NOT NULL,
		action VARCHAR(200) NOT NULL,
		pub_code  VARCHAR(30) NOT NULL,
		PRIMARY KEY (pub_code, map_id, country_id, frequency)
)
END_SQL
 	# Create PrimaryKEY 
	$dbh->do($createReportsSQL) or confess "Error: can't create table 'mapping' err[$DBI::errstr]"; 

}
##################################################################################

##################################################################################
# For function description see the pod document down
# 
sub initCountriesDB {
	my $self = shift;
	my $dbh = $self->DBI();
	# CREATE TABLES
	my $createCountriesSQL = <<'END_SQL';
CREATE TABLE if not exists countries (
		country_code3 VARCHAR(3) NULL,
		country_code2 VARCHAR(2) NULL ,
		cc_id INTEGER(20) AUTO_INCREMENT, 
		country_name  VARCHAR(60) NOT NULL,
		pub_code VARCHAR(30) NOT NULL,
		excluded BOOLEAN NULL, 
		PRIMARY KEY (cc_id, pub_code, country_name)
)
END_SQL
	$dbh->do($createCountriesSQL) or confess "Error: can't create table 'countries' err[$DBI::errstr]"; 

}
#################################################################################
# cleaning
#################################################################################
# For function description see the pod document down
sub clean {
	my $self = shift;
	my $value = shift;
	return unless defined $$value; 
	confess "Error: string reference required" unless ref $value eq 'SCALAR';
	$$value =~ s/&amp;/&/g;
	$$value =~ s/\"//g;
	$$value =~ s/\s\s*/ /g;
	$$value =~ s/^\s//;
	$$value =~ s/\s$//;
}
#################################################################################
  # ACCESSOR->DBI;
#################################################################################
######################
# For function description see the pod document down
sub DBI {
	my $self = shift;
	if (@_) {
		my $object = shift;

		if ( ref($object) eq __PACKAGE__  ) {
			$self->{DBI} = $object;
		} else {
			confess "Error: Not a object [$object]"; 
		}
	}
	return $self->{DBI};
}

#####################################################################
  # ACCESSOR->SELECT();
#####################################################################
# For function description see the pod document down

sub select {
	# VERSION 0.0
	my $self = shift;
	my $config = shift or confess "Error: require hash ref as param";
	confess "Error: param must be hash ref" unless ref $config eq 'HASH';
	my $sql = $config->{sql} or confess "Error: 'sql' select required as string";
	confess "Error: sql[$sql] statement must have select word at beginning", unless $sql =~ /^\s*select/i; 
	my $separator;

	if ( $config->{separator} ) {
	       $separator = $config->{'separator'};
	} else {
	       #default separator; 	
	       $separator = '->';
	}

	confess "Error: 'keys' param is mandatory, must be array ref with columns returned in hash" unless $config->{'keys'};
	confess "Error: 'keys' param given here must be array ref" unless ref $config->{'keys'} eq 'ARRAY';
	confess "Error: 'keys' array must have at least one element" unless scalar @{$config->{'keys'}} > 0; 	

	my @values;
#	d "conf", $config; 
	if ($config->{'values'} ) {
		confess "Error: values must be array ref " unless ref $config->{'values'} eq 'ARRAY';
		@values = @{$config->{'values'}};
	} 

	my $dbh = $self->DBI();
	my $sth = $dbh->prepare($sql) or confess "Error: can't create statement sql[$sql] err[$DBI::errstr]";
	$sth->execute();
	my $result = {}; 

	while (  my $hash_ref = $sth->fetchrow_hashref ) { #cycle sql response 
		my $result_keys;

		for my $request_keys_cols ( @{$config->{'keys'}} ) {
			if (exists $hash_ref->{$request_keys_cols} ){
				$result_keys .= delete($hash_ref->{$request_keys_cols}) . $separator;
			} else {	
				confess "Error: column[$request_keys_cols] not found check the sql[$sql]";
			}	  	
		}

		$result_keys =~ s/$separator$//;

		unless (@values) {
			@values = keys %{$hash_ref};	
		}

		if (@values) {	
			if (scalar @values > 1 ) { #if requested value is more than one

				foreach my $requested_value ( @values ){
					confess "Error: value not found [$requested_value] does not exists for sql[$sql] or set to be a keys" unless exists $hash_ref->{$requested_value};
					$result->{$result_keys}->{$requested_value} = $hash_ref->{$requested_value};
				}

			} else { # if requested values are only one 
				$result->{$result_keys} = $hash_ref->{ $values[0] };
			}

		} else { # if want only keys
			$result->{$result_keys}++;
		}
	}
	return $result;  
}
#################################################################################
  # ACCESSOR->pubCode;
#################################################################################
# For function description see the pod document down

sub pubCode {
	my $self = shift;
	if (@_) {
		$self->{pubCode} = shift;
	}
	return $self->{pubCode};
}
#################################################################################
 #INITIAL READING OF CMT EXCEL FILE
#################################################################################
# For function description see the pod document down
#
sub _readExcelFile {
	my $self = shift;
	
	my $config = shift || confess "Error: the config hash ref is manda as argument";
	confess "Error: hash ref required here" unless ref $config eq 'HASH';
	#d " confing", $config;

	if ( $config->{file} ) {
		confess "Error: the file[$config->{file}] does not exists" unless -f $config->{file};
	} else {
		confess "Error: file param in hash ref is manda";
	}

	my $columns = [];

	if ($config->{columns} and ref $config->{columns} eq 'ARRAY' ) {
	   $columns = $config->{columns};
	} else {
	  $columns = [ '.*'];
	}

	my $excel = read_map_excel_file({
                File=>$config->{file},
		Sheetname=>$config->{sheetname}, 
                Values=>$columns,          # MANDA-Dretermine witch columns will be taken for values in hash
                inc_rows=>'solo',          # Option: Include rows in keys if 'Y'; or 'solo will add only the rows as a key;
                return_nested=>1,          # Return complex hash stucture
		clean=>$config->{clean},   # Cleaning 
                });

	return $excel;
}

#################################################################################
# DOCUMENTATION
#################################################################################

=head1 Author:

MGrigorov

=head1 Version:

0.0.0

=head1 Documentation by:

MGrigorov 2016-08-26

=head1 Description:

=over

=item * Overall Info

The idea was to have a common mapping database for all energy publications.
     Advantages:
	-to have similar mapping format
        -methods to put xls/xlsx files directly in the mapping DB
        -easy selecting after any process to see what was loaded
     Disadvantages:
	-the developer has no freedom for mapping formats and developing own methods
        -this is beta version probably there are many things that are not well predicted
	-the developer need to know sql basics and tables structures
     Prior knowledge:
        - SQL basics
        - PerlOOP basics
        - Series.pm and SeriesLookup.pm docs (Energy API) note that docs are outdated BBodnaruk is responsible for the API

=item * Database Description 


 ----------------------------------------------------------------------------------------------------
 Tables_in_oxford_energy        | Short Description                                  | PrimaryKey
 -----------------------------------------------------------------------------------------------------
 countries                      | mapping for CoutryCode2 to CountryCode3 AR-ARG     | cc_id autoincrement
 -----------------------------------------------------------------------------------------------------
 mapping_IS_OEFINDUFORECASTDATA | has uniq pub code mapping - MnemCodes for the case | map_id auto_increment
                                | for any pub you will need to create such table     | 
 -----------------------------------------------------------------------------------------------------
 series_mapping                 | this contains global energy series_id mapping here |  Combination from:
                                | we store the series_ids when we use the energy api | cc_id + map_id + frequency + pub_code
 -----------------------------------------------------------------------------------------------------

=item * Tables Desc:

	tables 'countries':
	--------------------------------------------------------------------
	Field         | Type        | Null | Key | Default | Extra          
	--------------------------------------------------------------------
	country_code3 | varchar(3)  | YES  |     | NULL    |                
	country_code2 | varchar(2)  | YES  |     | NULL    |                
	cc_id         | int(20)     | NO   | PRI | NULL    | auto_increment 
	country_name  | varchar(60) | NO   | PRI | NULL    |                
	pub_code      | varchar(30) | NO   | PRI | NULL    |                
	excluded      | tinyint(1)  | YES  |     | NULL    |                
	--------------------------------------------------------------------
        Row ex. ARG   | AR          |    1 | Argentina | IS_OEFINDUFORECASTDATA | 0 | 
	
	# This tables contains mapping providen by the infospec team 
	# In the 'excluded' countries we have the developed markets, so if excluded 1 then skip
	# Countries table is designed to be global( for more than one energy pub),
	# but maybe can not cover all the cases for countries
	# Please see fillMapFromExcel() description for more info how to fill that table
	# Created with initCountriesDB()

	
	table 'mapping_IS_OEFINDUFORECASTDATA'
	--------------------------------------------------------------------
	Field     | Type         | Null | Key | Default | Extra          
	--------------------------------------------------------------------
	map_id    | int(11)      | NO   | PRI | NULL    | auto_increment 
	Mnem      | varchar(20)  | NO   |     | NULL    |                
	Descn     | varchar(100) | NO   |     | NULL    |                
	Scope     | int(11)      | YES  |     | NULL    |                
	NAICSCode | varchar(20)  | YES  |     | NULL    |                
	Exclude   | tinyint(1)   | YES  |     | NULL    |                
	--------------------------------------------------------------------
	Row ex: 6 |   | QAIR   | Air transport services, Output (value-added index)            | 250303 | 481        |    NULL |

	# The mapping for OxfordEconomics are based on Mnem codes.This info must be given from infospec.team
	# and cause the old mapping has 80 000 lines, we took the idea for db, and filling method from xlsx to sql
	# Again if mnem has Exclude 1 we need to skip that MNEM
	# Please see fillMapFromExcel() description for more info how to fill that table
	# Created with initMappingDB()

	
	tables: 'series_mapping'
	------------------------------------------------------------------------------------------
	Field       | Type         | Null | Key | Default           | Extra                       
	------------------------------------------------------------------------------------------
	country_id  | int(11)      | NO   | PRI | NULL              |                             
	map_id      | int(11)      | NO   | PRI | NULL              |                             
	update_date | timestamp    | NO   |     | CURRENT_TIMESTAMP | on update CURRENT_TIMESTAMP 
	series_id   | int(20)      | NO   |     | NULL              |                             
	action      | varchar(200) | NO   |     | NULL              |                             
	pub_code    | varchar(30)  | NO   | PRI | NULL              |                             
	frequency   | int(11)      | NO   | PRI | 0                 |                             
	------------------------------------------------------------------------------------------

	
	# Global mapping tables. When series_id are created/modified we need to add that info in this table.
	# map_id is the pr.key from mapping_$pub_code table, update_date is auto-generated, series_id is modified id 
	# 'action' should be description for what we have done for certain series_id
	# 'frequency' is friquency_id for the series(see perldoc Series.pm) 
	# In our case we have frequency 1 and 19 annual and quearterly 
	# Please see  fillGlobalMap() method for how to fill this table 
	# Created with initReportingDB()

 
=back

=head1 Methods:

=over

=item * new()
	
 This is the constructor method, witch makes a connection to the energy mapping dataBase
 The method takes hash reference as external argument. 

  db_address=>"dbi:mysql:database=oxford_energy",  # DataBase address	  	              string	manda
  user=>'root', 				   # DataBase user	     	              string	manda
  password=>'', 			           # DataBase password,default('')            string	optional, if emply gives empty string ''
  pub_code=>'SOME_PUB',			           # PubCode, we consider a DB for every pub  string	manda     

 Example: 
 my $example_db_config = { db_address=>"dbi:mysql:database=oxford_energy", user=>'root', password=>'', pub_code=>$pub };
 my $Energy = Energy::DB->new($db_config);


=item * fillMapFromExcel()


 This method Fills sql Database from some excel file
 It takes hash reference as argument, and here are the possible parameters:

 file          =>$_config->{ExcelMap},	# Path of sourse excel file 					manda	string
 sheetname     =>'QuarterlyData',	# Sheetname to parse, must be one sheet, exactly like file's	manda	string
 createColumns =>\@mnemColumns,       	# What excel columns are needed, works as regexes, default(.*)	opt	array_ref
 table         =>"mapping_$pub"	        # The output sql table 						manda	string
 clean         =>	                # cleaning function, with return cleaned result 		opt	sub_ref
 action	       =>insert		        # sql action can be insert or replace, default(replace)         opt	string

 Example: 
 #$Energy->fillMapFromExcel({file=>"test_excel.xlsx", sheetname=>'QuarterlyData', createColumns=>['id_column', 'values'],    table=>"mapping_$pub" });
 #$Energy->fillMapFromExcel({file=>"test_excel.xlsx", sheetname=>'country_map',   createColumns=>\@countryColumns, table=>'countries', clean=>$clean });


=item * fillGlobalMap()


 This method is designed to fill the global mapping table('series_mapping' you can see tables description for more info)
 The method acts like a setter it the DB.It is wrapped method of fillDB(), so please see fillDB() description
 Hash reference is the arguments format here.These are the possible params, witch are all MANDA:

   frequency  => $frequency_id				# this is the frequency_id of the series, and must be number
   map_id     => $map_id, 				# this column is the link key to the pub_code database mapping( see tables description)
   action     => "$table_info for CC[$prod_code]", 	# description of the action that was taken for certain series_id
   series_id  => $series_id , 				# series_id that has been changed/created 
   country_id => $ccID 				# country_id for witch the series_id is related, link to 'countries' tables (see tables description)

  Example:
   $Energy->fillGlobalMap({ frequency=>$frequency, map_id=>$map_id,  action=>"$table_info for CC[$prod_code]",  series_id=>$series_id , country_id=>$ccID } );
   Example line from the DB:
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
     country_id | map_id | update_date         | series_id | action                                                                              | pub_code               | frequency 
    ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
              1 |      1 | 2016-08-18 13:50:06 |   2308430 | Custom table[44766] was updated exists with scope_code[250303] naics[72] for CC[AR] | IS_OEFINDUFORECASTDATA |         1 


=item * fillDB()


 This is actual method for loading a row in some sql table, and it is designed to be internal method mostly
 fillDB() takes several argiments: ($hash_ref_with_data, 'Table_name', 'REPLACE|INSERT' )
 These are the possible arguments, represented in actual order:

 $hash_ref_with_data  # this must be hash ref with column names as keys and sql_values as hash values          manda   hash_ref 
 'series_mapping',    # this must be a name of existing table in our DB, where the data will be loaded         manda   string
 $action 	      # this is the action that will be taken 'REPLASE' or INSERT, default is 'REPLASE'        opt     string

  Example:
 	 my $columns->{series_id} = '123123';
	 my $result = $self->fillDB( $columns , 'series_mapping', );
	 my $result = $self->fillDB( { test_names=>'Ivan'} , 'names', 'INSERT' );

=item * initMappingDB()


 This method is called on the constructor and it's designed to create a mapping_$pub_code (please see tables description for more info)
 For now this method is with hard coded parameters of the pub code table mapping, for future use, please, consider change Mnem code with 'external_code' or else for example (Included in TODO)
 So there is no params required here:  $object-> initMappingDB();


=item * initReportingDB()


 This method is called on the constructor and it's designed to create a 'series_mapping' (please see tables description for more info)


=item * initCountriesDB()


 This function creates 'countries' tables. For more info see tables description, it's called from the constructor
 The method, probably will need to be rewritten to be more flexible cause in future pub codes will have other requerement for remap countries;


=item * clean()

 Cleaning function, used to remove some useless simbols before loading data in sql
 The method takes string ref;
  Example:
	my $string = '&test aasd ';
	$self->clean( \$string );
	say $string . ' show me result ';


=item * DBI()
	

 This acts like setter/getter for the DBI handler, mostly used for internal uses, but can be given external dbh if needed
 Example:	my $dbh = $self->DBI()


=item * select()


 This method is designed to access the databases via 'select' sql statement and return the query result
 The result hash can be managed how you witch columns should be keys and witch values.See the config below.
 In future when is know witch are most used selects we can wrap methods around this one, for now you need to know sql and tables structire
 External method witch takes hash ref and returns select result. We can use following params in the hash:
 Please don't request same sql columns in result hash keys and result hash values it wont work

'sql'       => "SELECT country_code3, country_code2, excluded from countries", # Execute this sql select
'keys'      => ['country_code3'], 					        # put in the result hash the follow column as keys in the hash, can be requested more than one columns as key.It's manda
'values'    => ['country_code2', 'excluded' ]                                  # put requested columns as values in resultet hash.Not manda if missing it will load all values that are not requested as keys 
'separator' => '@@'								# if requested more than one columns as hash keys there will be used separator to separate them '->' Example2

 Example1:
  my $countryMap = $Energy->select({sql=>"SELECT country_code3, country_code2, excluded from countries", keys=>['country_code3'], values=>['country_code2', 'excluded' ]  });
 Result:
 'UKR' => {
	'country_code2' => 'UA',
	'excluded' => '0'
	},
 'URY' => {
	'country_code2' => 'UY',
	'excluded' => '0'
	},
 'USA' => {
	'country_code2' => undef,
	'excluded' => '1'
	}

 Example2:
  my $countryMap = $Energy->select({sql=>"SELECT country_code3, country_code2, excluded from countries", keys=>['country_code3', 'country_code2'], values=>['excluded' ]  });
 Result:
	'LUX->' => '1',
	'LVA->LV' => '0',
	'MEX->MX' => '0',
	'MLT->' => '1',
	'MYS->MY' => '0',
	'NLD->' => '1',
	'NOR->' => '1',
	'NZL->' => '1',
	'OMN->OM' => '0',
	'OPC->' => '1',
	'PAK->PK' => '0',
	'PHL->PH' => '0',
	'POL->PL' => '0'
	'PRT->' => '1',

 Example3;
  my $countryMap = $Energy->select({sql=>"SELECT country_code3, country_code2, excluded from countries", keys=>['country_code3' ],  });
 Result: 

 'USA' => { 
	'country_code2' => undef,
	'excluded' => '1'
 },
 'VEN' => { 
	'country_code2' => 'VE',
	'excluded' => '0'
 },


=item * pubCode()


This is a method for get/set current pubCode it is used in the new() constructor as manda argument {pub_code=>'asdasd', ...}
 Internal method generally;
 Example: my $pubCode = $self->pubCode(); $self->pubCode('TestPub');


=item * _readExcelFile()


 NOTE that, this is internal object method that wasn't designed to be used outside
 This is wrapped method from Fins::map::read_map_excel_file witch actually reads excel file data in hash ref
 For more info you can see the pod of Fins::map::read_map_excel_file;


=back

=head1 Relations:

B<EMIS::InduStats::Series.pm>
B<EMIS::InduStats::SeriesLookup.pm>
B<Fins::map.pm>
B<mtools.pm>

=head1 ToDo probably in Future:

Add a external mapping code in sub initMappingDB() instead of now hard coded Mnem code, considering the next case

Rewrite  initCountriesDB(), and probably there will be a need to alter that table country_code3 with global name for example 'external_country' and chante the type

=head1 Bugs:

Still on testing stage, work only with one pub 'IS_OEFINDUFORECASTDATA'

=cut

1;
