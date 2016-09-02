package Fins::profToolsOOP;
use warnings;
use strict;
use 5.10.1;
use Carp;
use YAML;
use lib qw(/proj/inbox/dataproc/lib /home/martosh/scripts/Mmod /proj/home/admin_la/mgrigorov/Mmod);
use mtools qw(d);
use File::Basename;
use Data::Dumper;

###########################################################
 # OOP MODULE ALTERNATIVE FOR profTools.pm
###########################################################

############# JUST FOR REMAINDING YOU ######################################################################
# Naming conventions:
#    Variables
#        Variables' names are clear and meaningful
#        $ALL_CAPS_HERE constants only (beware clashes with perl vars!);
#        $Some_Caps_Here package-wide global/static.
#        $no_caps_here function scope my() or local() variables with singular  mnemonic variable name.
#    Arrays and Hashes
#        @company_names;
#        %accounts_to_codes;
#        my() or local() arrays and hashes with mnemonic plural names
#    Functions/Methods
#        Names need to be mnemonic in camel case without delimiter between words
#        Placing one underscore for private and two for protected method mnemonic names
#        First word of method name need to be a verb describing the action of method.
#        &exportToEntities()  – public method
#        &_mapAccount() – private method
#        &__getStatus   – protected
#    References  - Place ‘r_’ or maybe ‘ref_’ at the start of the name
#    Package wide variables are Mixed_Case_With_Underscore

#############################################################################################################
####################################
# Versions:
####################################
  my $version = {
	 '0.0.0[2015-10-19]'=>"Developing and documentation",
	 '0.0.1[2015-10-19]'=>"Missing functionality if section has more than one element: add internal method _checkArguments",
	 '0.0.2[2015-10-27]'=>"Missing functionality deleteItems",
	 '0.0.3[2015-11-16]'=>"Review all methods, remove useless ones, fix data structure bug",
	 '0.0.4[2015-12-11]'=>"Fixed small bugs in constructor new()",
	 '0.0.5[2016-02-22]'=>"Added OptionsInterface with methods: getOptions, setOptions, delOptions, _createOptionsList, _getOptionsList, _applyOptions (Added option 'skip_empty_strings')",
	};

####################################
# METHODS:
####################################

##########################
# NEW (Constructure);


# Examples:
# my $entity = Fins::profTools::OOP->new(); # just create empty object
# my $entity = Fins::profTools::OOP->new($entity); # give exist entity 
# my $entity = Fins::profTools::OOP->new("/home/111111id.yaml"); # give path to existing yaml file entity

sub new {
    my $self   = shift;
    my $entity = shift;

   $self = bless { Entity => {} }, $self;
   $self->_createSectionsList(); # create list of sections and add to obj
   $self->_createOptionsList(); #create avalable options for user 
#  $self->setOptions('skip_empty_strings');

    if ($entity) {
        if ( -f $entity ) {    #if entity is path
		$self->readYaml($entity);
		return $self;
        } else {
            confess "Err: the argument given here must be hash ref" unless ref $entity eq 'HASH';

            $self->{Entity} = $entity;
            return $self;
        }
    }
	return $self;
}
####################################
# OPTIONS METHODS
####################################


###################################
# getOptions Method
   # my $skip = $self->getOptions('Option_name');

     # return true/false 
sub getOptions {
    my $self        = shift;
    my $user_option = shift or confess "Err: option expected here!";
    my $Available_Options     = $self->_getOptionsList(); 

      if ( $Available_Options->{$user_option} ) {

        if ( $self->{Options}->{$user_option} ) {
            return $self->{Options}->{$user_option};
        } else {
            return undef;
        }
    } else {
        say "List of available Options:";
        say Dumper $Available_Options;
        confess "Err wrong user option[$user_option]";
    }
}

####################################
# setOptions 
     # $entity->setOptions('skip_empty_strings');
sub setOptions {
    my $self        = shift;
    my $user_option = shift or confess "Err: option expected here!";
    my $Available_Options     = $self->_getOptionsList();

    if ( $Available_Options->{$user_option} ) {
            return $self->{Options}->{$user_option} = '1';
    } else {
        say "List of available Options:";
        say Dumper $Available_Options;
        confess "Err wrong user option[$user_option]";
    }
}
###################################
# delOptions 
     # $entity->setOptions('skip_empty_strings');
sub delOptions {
    my $self        = shift;
    my $user_option = shift or confess "Err: option expected here!";
    my $Available_Options     = $self->_getOptionsList();

    if ( $Available_Options->{$user_option} ) {
            delete $self->{Options}->{$user_option};
    } else {
        say "List of available Options:";
        say Dumper $Available_Options;
        confess "Err wrong user option[$user_option]";
    }
}
####################################
# my $field_value = $self->_applyOptions( <field_value> );
# Returns 'next@' or regular value 
# 
sub _applyOptions {
	my $self = shift;
	my $field_value = shift;
	
	if ($self->getOptions('skip_empty_strings') ) {
		if ( not defined $field_value or $field_value eq '' ){
			$field_value = 'next@';
		} 
	}
	
	return $field_value;	
}
####################################
#my $list = $self->_getOptionsList();
# returns hash with all available options

sub _getOptionsList {
	my $self = shift;
	return $self->{OptionsList};
}
####################################
# Create list with all available Options
   # Options for now are:
	#'skip_empty_strings' this option forbids you to create via set method empty strings example:
		# my $CityCode = '';
		# $entity->set( 'ADDRESS', { 'AddressType' => 'H', 'City' => $data->{City}, 'CityCode' => $CityCode , 'Url' => $url,  Phones => $phones },  );
		# The result for entity will be empty
sub _createOptionsList {
    my $self = shift;
    my $Options = { 'skip_empty_strings' => '1', };
    $self->{OptionsList} = $Options;
    return $self->{OptionsList};

}
 
########################
# SET/GET ENTITY
# DES:
	# Set/get data structure for alternative profile update
# Examples:
	# my $obj = Fins::profToolsOOP->new();
	# my $data = $obj->Entity(); # Acts like get
	# $obj->Entity($some_entity_data); #Acts like set

sub Entity {
    my $self = shift;
    my $result = undef;

    if (@_) {    # ACT like SET
        my $entity = shift;

        if ( ref($entity) eq 'HASH' ) { 
            $self->{Entity} = $entity;
            return $self->{Entity};
        } else {
            confess "Err: hash ref expected as arg";
        }

    } else {
        # ACT LIKE GET
#	d" show me self-ntt", $self->{Entity};
	$result = {%{$self->{Entity}}};
        return $result;
    }
}

#######################
# DEL 
#######################
# Wrapped get 
sub del {
    my $self = shift;
    my $section_name = shift || confess "Err: you must give section name as first argument ";
    my $method_name = 'del';
    return $self->get( $section_name, @_ , 'delete');

}

#######################
# GET (Accessors)
###################### 
# $entity->get( $Section, { $field_name=>1 }|[ $field_name ]|all, $dataType, $array_num);
# EXAMPLE: 
	# my $readed_data_ExecutiveName =  $entity->get ( 'EXECUTIVE', { 'ExecutiveName'=>'1' }, ReadedData  );
	# my $company_id =  $entity->get ( 'META', { 'ExternalCompanyID'=> '1' }  );
	# my $CountryCode =  $entity->get ( 'META', [ 'ExternalCompanyID','CountryCode' ]  ); # return ExternalId and ContyCode
	# my $all_address =  $entity->get ( 'ADDRESS', 'all' ); # gets all data for ADDRESS section
	# my $all_address =  $entity->get ( 'ADDRESS' ); #same as above
	# my $all_address =  $entity->get ( 'ADDRESS', 'all', 'RULES' ); #get all data for RULES
	# my $all_address =  $entity->get ( 'ADDRESS', { Action=>'' }, 'RULES', 1 ); #get Action field from ADDRESS->RULES->[1] 
	# my $all_Executives = 	
 
sub get {
    my $self         = shift;
    my $section_name = shift || confess "Err: you must give section name as first argument ";
    my $method_name  = 'get';

    my $r_params = $self->_checkArguments( $method_name, $section_name, @_ );

    #    my $SectionType     = $r_params->{SectionType};
    my $ItemsType       = $r_params->{ItemsType};
    my $array_num       = $r_params->{ArrayNum};
    my $r_target_fields = $r_params->{TargetFields};
    my $delete          = $r_params->{Delete};
    $section_name = $r_params->{SectionName};    # fixed section name after _checkArg..

    $method_name = 'del' if $delete;

    #   d "Get show me arg", $r_params;

    my $result;
    my $entt = $self->Entity();

    if ( $section_name =~ /^META$/i ) {          # META is with different structure
        return $self->_getMeta( $method_name, $r_target_fields );
    }

    # if all, if targetFields, if $arrayNum

    if ( $r_target_fields !~ /^\s*all\s*$/i ) {    # IF target fields
        $result = {};
        for my $field_to_get ( keys %{$r_target_fields} ) {
            $result->{$field_to_get} = $self->_getRequestedFields( $section_name, $method_name, $field_to_get, $ItemsType, $array_num );
        }

        return $result;

    } else {                                       # If 'all' fields are requested, and NO FIELDS Get/Del all

        if ( defined $array_num and $array_num =~ /^\d{1,2}$/ ) {    # all and array number ,Example: if you want to get all fields from 4-th element
            if ( exists $entt->{$section_name}->{$ItemsType}->[$array_num] ) {

                return delete $entt->{$section_name}->{$ItemsType}->[$array_num] if $delete;
                return $entt->{$section_name}->{$ItemsType}->[$array_num];
            } else {
                return undef;
            }
        }

        if ( exists $entt->{$section_name}->{$ItemsType} ) {
            return delete $entt->{$section_name}->{$ItemsType} if $delete;
            return $entt->{$section_name}->{$ItemsType};
        } else {
            return undef;
        }
    }
}


#####################
# SET ( Accessor )
# DESC:
	# This method adds values and fields into entity structure 
	# $entity->set ( 
# Examples:

# $entity->set( 'META', { 'ExternalCompanyId' => $external_id, 'CountryCode' => 'BR' } );
# $entity->set( $Section_Name, {$FieldName => $FieldValue} );
# $entity->set( 'EXECUTIVE', { 'ExecutiveName' => $ExecutiveName, 'Position' => $ExecutivePosition, ExecutiveNameEng=>$ExecutiveName });
# $entity->set( 'EXECUTIVE', { 'ExecutiveName' => $ExecutiveName, 'Position' => $ExecutivePosition, ExecutiveNameEng=>$ExecutiveName }, ReadedData);
# $entity->set( 'EXECUTIVE', { 'ExecutiveName' => $ExecutiveName, 'Position' => $ExecutivePosition, ExecutiveNameEng=>$ExecutiveName }, ReadedData , 2);
	#  ItemsType (addNewItems|ReadedData|RULES) # Default is addNewItems

sub set {
    my $self = shift;
#    d " set \@_ ", \@_;
    my $section_name    = shift || confess "Err: you must give section name as argument";
    my $r_fields_to_set = shift || confess "Err: you must give hash ref as second arg here!";
    my $method_name     = 'set';

    my $r_params = $self->_checkArguments( $method_name, $section_name, $r_fields_to_set, @_ );
   # d " set arguments after _checkARGS", $r_params;
    my $ItemsType = $r_params->{ItemsType};


    my $array_num = $r_params->{ArrayNum};
    $section_name    = $r_params->{SectionName};    # fixed section name after _checkArg..
    $r_fields_to_set = $r_params->{TargetFields};


    if ( $section_name =~ /^META$/i ) {             # Meta is with different structure
        return $self->_setMeta($r_fields_to_set);
    }

    my $entt = $self->Entity();

    my $field_data = {};                            #load filed_names here

    for my $field_name ( keys %{$r_fields_to_set} ) {
        my $field_value = $r_fields_to_set->{$field_name};

	 $field_value = $self->_applyOptions( $field_value ); #applyOptions
	if ($field_value eq 'next@') {
	 #d " You are trying to add empty field for field_name[$field_name]", $field_value;
	 next 
	}

        if ( defined $array_num and $array_num =~ /^\d{1,2}$/ ) {
            $entt->{$section_name}->{$ItemsType}->[$array_num]->{$field_name} = $field_value;
        } else {                                    # DEFAULT Behavior with no array num
            $field_data->{$field_name} = $field_value;
        }

    }

    if ( keys %{$field_data} ) {
        push @{ $entt->{$section_name}->{$ItemsType} }, $field_data;
    }

    $self->Entity($entt);
    return $self->lastElement( $section_name, $ItemsType );

}

#####################################################
# What is the last element of section and sectionType
#####################################################
sub lastElement {
	my $self = shift;
	my $section_name = shift || confess "Err:requiered section_name as manda arg";
	my $ItemsType = shift; 
	if (not defined $ItemsType) {
		$ItemsType = 'addNewItems';
	}

	my $entt = $self->Entity();
	my $number = $#{$entt->{$section_name}->{$ItemsType}};
	return $number;
}



########################

########################
# check Arguments
# This is internal method with is designed to determine what is the type of your arguments

sub _checkArguments {
	my $self = shift;
	my $from_method = shift || confess  "Err: missing from method, set|get string expected"; # MANDA argument from where it comes
	confess "Err: wrong from_method[$from_method]" unless $from_method =~ /^set$|^get$/;
#	d "_checkArguments in beginning params", \@_ ;
	my $section_name = shift || confess "Err: missing expected section name as arg"; # MANDA argument SectionName
	$section_name = $self->_checkSection($section_name);
#	d "Show me section name", $section_name;
	my $r_params->{SectionName} = $section_name;

	my @arguments = @_;

	if (@arguments) {
		for my $arg (@arguments ) {
			next unless defined $arg;
			my $ref = ref $arg;
#			d " show me arg", $arg;
			if ( $arg =~ /^\s*delete\s*$/i ) {
				$r_params->{Delete} = 1;
				next;
			}		

			if ( $arg =~ /^addNewItems$|^ReadedData$|^RULES$/i ) {
				$arg = 'addNewItems' if $arg =~ /^addNewItems$/i; 
				$arg = 'ReadedData' if $arg =~ /^ReadedData$/i; 
				$arg = 'RULES' if $arg =~ /^RULES$/i; 
				$r_params->{ItemsType} = $arg;
				next;		   
			}

			if ( $arg =~ /^\d{1,2}$/ ) {
				$r_params->{ArrayNum} = $arg;
				next;		   
			}

			if ( $arg =~ /^all$/i ) {
				$r_params->{TargetFields} = $arg;
				next;		   
			}
			
			if ( $ref =~ /hash|array/i ) {# why get and set only
        			$r_params->{TargetFields} = $self->_array_to_hash($arg);
			}
		}	
	}

	# DEFAIL BEHAVIOR
		# If no ArrayNum arg, view
	unless (exists $r_params->{TargetFields} ) {
		$r_params->{TargetFields} = 'all'; 
	}
	
	unless (exists $r_params->{ItemsType} ) {
		$r_params->{ItemsType} = 'addNewItems'; # default if missing 
	}

	if (  not exists $r_params->{ArrayNum} ) {
#		carp "Warn: missing specifig arrayNum for [$from_method] section[$r_params->{SectionName}], so default behavior"; 	
		$r_params->{ArrayNum} = undef; #default if missing
	}

	return $r_params;

}

#####################
# Get RUles
# It is wrapped method for rules you can use simpe get as well 

#Examples:
#       my $rule = $entity->getRule( 'ADDRESS', 'all ); #Gets all rules for ADDRESS
#	my $rule = $entity->getRule( 'ADDRESS' );  #Same as above
#       my $rule = $entity->getRule( 'ADDRESS', 'all', 0); #Gets all fields for rule 0 in ADDRESS
#       my $rule = $entity->getRule( 'ADDRESS', { Action=>''}  , 1); #Gets Action field for rule 1 from ADDRESS
#       my $rule = $entity->getRule( 'EXECUTIVES', 'all' , 1); #Gets all fields for rule 1 EXECUTIVES

sub getRule {
    my $self            = shift;
    my $section_name    = shift || confess "Err: you must give section name as first argument ";
    my $ItemsType = 'RULES';

    return $self->get( $section_name, @_, $ItemsType );
}

######################
# delRule

sub delRule {
	my $self = shift;
        my $section_name    = shift || confess "Err: you must give section name as first argument ";
	$self->getRule( $section_name , @_ , 'delete' );
}

#####################
# Set RUles

#Examples: 
# my $rule = '0';
# $entity->setRule( 'ADDRESS', { Action => 'edit', LogicalString =>'AddressType', AddressType=> qr/^H$/ , functionName=> 'editHeadquoter' , data => {} }, $rule );
# The line above wlll add rule 0 in ADDRESS section 
 
sub setRule {
    my $self = shift;
#	d " setRule \@_ ", \@_;
    my $section_name    = shift || confess "Err: you must give section name as first argument ";
    my $r_fields_to_get = shift || confess "Err: you must give Some fields to be set";
#    my $rule_num = shift;
	
#	if ( $rule_num) {
#		confess "Err: rule num[$rule_num] must be number from 0-99", unless $rule_num =~ /^\d{1,2}$/;
#	} 
	return $self->set($section_name, $r_fields_to_get, 'RULES', @_);
}

###################################################
 # Internal Methods
###################################################

###########################
# Get Rule CHeck #Internal
# 
# Some checks performed when you want to get Fields with more than one element []

sub _getRequestedFields {    # PLEASE NOTE This is in foreach;
    my ( $self, $section_name, $from_method, $field_to_get, $ItemsType, $array_num ) = @_;
    my $delete;
    my $entt = $self->Entity();
    my $result;

    if ( $from_method =~ /^\s*del/i ) {
        $delete = 1;
    }

    if ( $array_num and $array_num =~ /^\d{1,2}$/ ) {

        if ( exists $entt->{$section_name}->{$ItemsType}->[$array_num]->{$field_to_get} ) {

            if ($delete) {    # if delete flag
                $result->{$field_to_get} = delete $entt->{$section_name}->{$ItemsType}->[$array_num]->{$field_to_get};
            } else {
                $result->{$field_to_get} = $entt->{$section_name}->{$ItemsType}->[$array_num]->{$field_to_get};
            }

        } else {
            $result = undef;
        }
    } else {    # DEFAULT BEGAVIOR of get/del if $array_num is missing (Cycle all);
        my $last = $self->lastElement( $section_name, $ItemsType );
        carp "Warn: arrayNum missing default will cycle from [0 .. $last] for [$from_method]";

        #        d $last;

        for my $array_num ( 0 .. $last ) {

            if ( exists $entt->{$section_name}->{$ItemsType}->[$array_num]->{$field_to_get} ) {

                if ($delete) {    # if delete flag

                    #                    $result->{$field_to_get}->[$array_num] = delete $entt->{$section_name}->{$ItemsType}->[$array_num]->{$field_to_get};
                    $result->{$array_num} = delete $entt->{$section_name}->{$ItemsType}->[$array_num]->{$field_to_get};
                } else {

                    #                    $result->{$field_to_get} = $entt->{$section_name}->{$ItemsType}->[$array_num]->{$field_to_get};
                    $result->{$array_num} = $entt->{$section_name}->{$ItemsType}->[$array_num]->{$field_to_get};
                }
            } else {
                $result = undef;
            }
        }
    }

    return $result;
}

########################
# Array ref to Hash ref
# DES:
	# IF we gave the desired fileds as array transform it to hash to unify the code after this method 
        # We can give arguments as array and hash here comes this method for help
	# Takes some values and if array ref remap it to hash ref;

sub _array_to_hash {
    my $self            = shift;
    my $r_fields_to_get = shift || confess "Err: array ref expected as argument";
    my $ref             = ref $r_fields_to_get;

    if ( $ref =~ /array/i ) {    # if array ->array_to_hash
        my $r_fields_to_hash = {};    # if you give array - it will make this on hash ref
        map { $r_fields_to_hash->{$_} = '' } @{$r_fields_to_get};
        return $r_fields_to_hash;
    }

    return $r_fields_to_get;

}

##########################
 # Internal Accessors
##########################
# GET META #InternalMethod
# Des:
	# Meta data has specific structure that's why I use specific method

sub _getMeta {
    my $self            = shift;
    my $from_method     = shift || confess "Err: missing argument from method ";
    my $r_fields_to_get = shift || confess "Err:You must give META fields to get all 'all' string as arg";

    my $delete;
    if ( $from_method =~ /del/ ) {
        $delete = 1;
    }

    my $entt   = $self->Entity();
    my $result = {};

    if ( $r_fields_to_get =~ /^\s*all\s*$/i ) {

        if ( exists $entt->{META} ) {
            return $entt->{META};
        } else {
            return undef;
        }

    } else {

        $r_fields_to_get = $self->_array_to_hash($r_fields_to_get);

        if ( ref $r_fields_to_get =~ /hash/ ) {    # if hash given
            for my $field_name ( keys %{$r_fields_to_get} ) {
                if ( exists $entt->{META}->{$field_name} ) {
                    $result->{$field_name} = $entt->{META}->{$field_name} unless $delete;
                    $result->{$field_name} = delete $entt->{META}->{$field_name} if $delete;
                }
            }
        } else {                                   #if array given
            for my $field_name ( @{$r_fields_to_get} ) {
                if ( exists $entt->{META}->{$field_name} ) {
                    $result->{$field_name} = $entt->{META}->{$field_name} unless $delete;
                    $result->{$field_name} = delete $entt->{META}->{$field_name} if $delete;
                }
            }

        }

        if ( keys %{$result} ) {
            return $result;
        } else {
            return undef;
        }

    }
}

########################
# SET META #Internal method
# Des:
	# Meta data has specific structure that's why I use specific set method

sub _setMeta {
	my $self = shift;
	my $r_meta = shift || confess "Err: you must give some values to set in hash ref";
	confess "Err: the arg it's not hash ref.It must be hash ref" if ref $r_meta !~ /hash/i;

	my $entt = $self->Entity();

	for my $field_name ( keys %{$r_meta} ) {
		my $field_value = $r_meta->{$field_name};
#		d " field_valie[$field_value]", $field_name;
		#check_fields method
		$entt->{META}->{$field_name} = $field_value;						
	}
	
	$self->Entity( $entt );
}


###########################
# _get @#SectionType List

sub _createSectionsList {
    my $self           = shift;
    my $r_sectionsType = {
        'COMPANY_SERVICE'      => 'many',
        'COMP_OWNERS_VIEW'     => 'many',
        'RELATED_COMP_VIEW'    => 'many',
        'PUB_COMPANY_CHECKSUM' => 'many',
        'EXECUTIVE'            => 'many',
        'BANKS'                => 'many',
        'COMPANY_NAICS'        => 'many',
        'ADDRESS'              => 'many',
        'REGISTERED_CAPITAL'   => 'many',
        'EMPLOYEES_NUMBER'     => 'many',
        'FINANCIAL_AUDITOR'    => 'many',
        'ANALYSIS'             => 'many',
        'FACE_VALUE'           => 'many',
        'FREE_FLOAT'           => 'many',
        'IMPORT_EXPORT'        => 'many',
        'COMPANY_RATING'       => 'many',
        'DIVIDENDS'            => 'many',
        'OUTSTANDING_SHARES'   => 'many',
        'EXTERNAL_COMPANY_ID'  => 'many',
        'COMPANY_UPDATES'      => 'many',
        'BASICS'               => 'one',
        'BUSINESS_ACTIVITY'    => 'one',
        'META'                 => 'one',

    };
    $self->{SectionsTypeList} = $r_sectionsType;
    return $self;
}

###########################
# get Sections Type List

sub _getSectionList {
    my $self = shift;
    return $self->{SectionsTypeList};
}

##########################
# _checks section name from section name

sub _checkSection {
    my $self = shift;
    my $section_to_check = shift || confess "Err: section name expected as arg , no arguments found";

    $section_to_check =~ s/\s//g;
    $section_to_check = uc $section_to_check;
    my $r_sectionsType = $self->_getSectionList();

    if ( exists $r_sectionsType->{$section_to_check} ) {
        return $section_to_check;
#       return 1 #$r_sectionsType->{$section_to_check};
    } else {
        confess "Err: the given section name[$section_to_check] is incorrect";
    }

}

##########################
# _checkSections
# future dev

####################################################
# OTher methods
####################################################

#######################
#DESC:
# Pring Yaml in dst path
#Examples:
       # my $ourput_path = '/home/test/output_data/gosho.yaml';
#      # $entity->printYaml( $output_path ); 

sub printYaml {
	my $self = shift;
	my $entity_path = shift || confess "Err:There are no dir path given as arg\n";
	my $Entity = $self->Entity(); 
#	d   "print yaml entity PATH", $entity_path;
	my ( $filename, $dir_path)  = fileparse( $entity_path);
#	d   "print yaml basename", "$dir_path, $filename";
	confess "Err:The file path [$dir_path] is not directory!" unless (-d $dir_path ) ;

	if( open(my $ENTITY_FILE , ">:encoding(UTF-8)", $entity_path) ) {
		print $ENTITY_FILE YAML::Dump($Entity);
		close $ENTITY_FILE;
		return 1;
	}else{
		confess 'Err:Can not open file: '.$entity_path;
	}
}

#########################
# Desc:
	# read Yaml from yaml file path
# EXAMPLE:
	#my $yaml   = '/inbox/ec-supercias/data/SUPCOMSILVER/20141125181732683921_SUPCOMPSILVER/profile-1790013561001.yaml';
	#my $entity = Fins::profToolsOOP->new($yaml);

sub readYaml {
    my $self = shift;
    my $file = shift || confess "Err: requre filepath as arg here";
    confess "The given path file[$file] does not exists" if ( not -f $file );
    my $entity;
    my $eval = eval { $entity = YAML::LoadFile($file); };

    if ($eval) {
	$self->Entity($entity);
        return $self; 
    } else {
        say "YAML_ERR-[$@]";
        confess "Err:There is an error in YAML::LoadFile method: on file[$file]\n";
        #        say $@;
    }
}

############################
# EXAMPLE YAML STRUCTURE
#############################
 #$entt->{ADDRESS}->{RULES}->[0]->{Action} = edit;
#ADDRESS: 
#  RULES: 
#    - Action: edit 
#      AddressType: !!perl/regexp (?^:^H$) 
#      LogicalString: AddressType 
#      data: 
#        AddressText: 'Octavio Chacon 4-17 y Cornelio Vintimilla, Edificio Azende Corporacion, Parque Industrial' 
#        AddressTextEng: 'Octavio Chacon 4-17 y Cornelio Vintimilla, Building  Azende Corporacion, Parque Industrial' 
#        AddressType: H 
#        CityCode: 16713 
#        CountryCode: EC 
#        Faxes: +593-7-280-7600 
#        Phones: +593-7-280-6333 
#      functionName: editHeadquoter 
#    - Action: edit 
#      Faxes: !!perl/regexp (?^:^\+593-\d-$) 
#      LogicalString: Faxes 
#      functionName: deleteBadFaxes 
#BASICS:
#  addNewItems: 
#    - LegalForm: EC-0003 
#      OpperationalStatus: O 
#COMPANY_NAICS: 
#  RULES: 
#    - Action: delete 
#      LogicalString: MainActivity 
#      MainActivity: !!perl/regexp (?^:^Y$) 
#  addNewItems: 
#    - MainActivity: Y 
#      NaicsCode: 445 
#COMPANY_UPDATES: 
#  addNewItems: 
#    - ProfileUpdtDate: 2014-11-25 
#      ProfileUpdtType: WHOLE PROFILE 
#      UpdatedBy: tgatev 
#EXECUTIVE: 
#  addNewItems: 
#    - ExecutiveName: Castanier Jaramillo Juan Diego 
#      ExecutiveNameEng: Castanier Jaramillo Juan Diego 
#      Position: EC-0005 
#META: 
#  CountryCode: EC 
#  ExternalCompanyId: 0190167348001 
#~                                                

=head1 Author:

MGrigorov

=head1 Version:

0.0.5

=head1 Documentation by:

MGrigorov 2016-02-23

=head1 Description:

This module is designed to work with AltenativeProfile YAML Structure (TGatev module for loading profiles) 

=head1 Methods:

=over

=item * new

 Examples:
 my $entity = Fins::profToolsOOP->new(); # just create empty object
 my $entity = Fins::profToolsOOP->new($entity); # give existing entity 
 my $entity = Fins::profToolsOOP->new("/home/111111id.yaml"); # give path to existing yaml file entity

=item * Entity

 Set/get data structure for alternative profile update

 Examples:
	 my $obj = Fins::profToolsOOP->new();
	 my $data = $obj->Entity(); # Acts like get
	 $obj->Entity($some_entity_data); #Acts like set


=item * get
 
 Take data from structure

 $entity->get( $Section, { $field_name=>1 }, $dataType, $element_num);
	       MANDA   , OPTIONAL {}|[]|all, OPTIONAL addNewItems|ReadedData|RULES, OPTIONAL 0-99 
		# DEFAULT $field_name all
		# DEFAULT $dataType addNewItems
		# DEFAULT $element_num all
 Examples: 
	 my $readed_data_ExecutiveName =  $entity->get ( 'EXECUTIVE', { 'ExecutiveName'=>'1' }, ReadedData  );
	 my $company_id =  $entity->get ( 'META', { 'ExternalCompanyID'=> '1' }  );
	 my $CountryCode =  $entity->get ( 'META', [ 'ExternalCompanyID','CountryCode' ]  ); # return ExternalId and ContyCode
	 my $all_address =  $entity->get ( 'ADDRESS', 'all' ); # gets all data for ADDRESS section
	 my $all_address =  $entity->get ( 'ADDRESS' ); #same as above
	 my $all_address =  $entity->get ( 'ADDRESS', 'all', 'RULES' ); #get all data for RULES
	 my $executive =  $entity->get ( 'EXECUTIVE', { ExecutiveName=>'' }, 1 ); #get ExecutiveName value fron EXECUTIVE section number 1 from addNewItems
	 my $executive =  $entity->get ( 'EXECUTIVE', { ExecutiveName=>'' }, ReadedData, 1 ); #get ExecutiveName value fron EXECUTIVE section number 1
	  

=item * set

 This method adds values and fields into entity structure 
 $entity->set( $Section, { field_name=>$fieldValue }, $dataType, $element_num);
	       MANDA   , MANDA { 'a'=> $b }       ,    OPTIONAL addNewItems|ReadedData|RULES, OPTIONAL 0-99 
		# DEFAULT $dataType	- addNewItems
		# DEFAULT $element_num 	- next element

 The method returns the last array element for updated section used for this:
            my $address_num = $entity->set( 'ADDRESS', { Emails=> 'gosho@abv.bg', Phones =>'+3592-12312312'  } );
            $entity->set( 'ADDRESS', { CountryCode => 'BG' } , $address_num);
	    $entity->set( 'ADDRESS', { AddressType => 'H' }, $address_num );
	    #In that way you can use many lines for loading data for one address 
	    # If you skip the last argument $address_num you will load data in yaml for the next address;

		
 Examples:

 $entity->set( 'META', { 'ExternalCompanyId' => $external_id, 'CountryCode' => 'BR' } );
 $entity->set( $Section_Name, {$FieldName => $FieldValue} );
 $entity->set( 'EXECUTIVE', { 'ExecutiveName' => $ExecutiveName, 'Position' => $ExecutivePosition, ExecutiveNameEng=>$ExecutiveName }, 0 );

=item * del

 This method is actually like get but added 'delete' string as argument so please see get method

=item * getRule

 It is wrapped method for rules you can use simpe get as well 

 Examples:
       my $rule = $entity->getRule( 'ADDRESS', 'all );	#Gets all rules for ADDRESS
       my $rule = $entity->getRule( 'ADDRESS' );	#Same as above
       my $rule = $entity->getRule( 'ADDRESS', 'all', 0); #Gets all fields for rule 0 in ADDRESS
       my $rule = $entity->getRule( 'ADDRESS', { Action=>''}  , 1); #Gets Action field for rule 1 from ADDRESS
       my $rule = $entity->getRule( 'EXECUTIVES', 'all' , 1); #Gets all fields for rule 1 EXECUTIVES

=item * setRule

 Examples: 
  my $rule = '0';
  $entity->setRule( 'ADDRESS', { Action => 'edit', LogicalString =>'AddressType', AddressType=> qr/^H$/ , functionName=> 'editHeadquoter' , data => {} }, $rule );
  The line above wlll add rule 0 in ADDRESS section 

=item * delRule

 Examples: 
  $entity->delRule( 'EXECUTIVE' ) # delete all executives rules 
  $entity->delRule( 'ADDRESS', $rule_num ); # Delete certain rule num
  The line above wlll add rule 0 in ADDRESS section 

=item * printYaml
 
Pring Yaml in dst path
 Examples:
       my $ourput_path = '/home/test/output_data/gosho.yaml';
       $entity->printYaml( $output_path ); 

=item * readYaml

	Read Yaml from yaml file path
 Examples:
	my $yaml   = '/inbox/ec-supercias/data/SUPCOMSILVER/20141125181732683921_SUPCOMPSILVER/profile-1790013561001.yaml';
	my $entity = Fins::profToolsOOP->new($yaml);



=back

=head1 OPTIONS METHODS:

=over

=item * setOptions('skip_empty_strings');

	$entity->setOptions($some_option);
	This will turn on some option

=item * getOptions( $some_options ); 

	my $option_status = $entity->delOptions($some_option);
	This will return true/false if option on/off

=item * delOptions( $some_options ); 

	$entity->delOptions($some_option);
	This will turn off some option

=back

=head1 OPTIONS AVAILABLE:

=over

=item * 'skip_empty_strings'

 	This options will not fill any empty strings in yaml

=back

=head1 Relations:

B<mtools.pm>

=head1 ToDo:
new development:
	A list of fieldNames possible for sections
	Maybe to try to guess the section
	replace Method

new development: find in fields values method (2015.10.29)
	my $result = $entity->find( sectionName => $section_name, fieldName=>$field_name);
	my $result = $entity->find( fieldName   => $field_name);
	my $result = $entity->find( fieldValue  => $field_value);
new development Format:

	Default behavior for formating on some fields
	standard format : Example:
		ExecutiveName = toTitleCase
		CityName = 	toTitleCase
		Url 	 = 	lc

new development QA:
	QA for all fields

=head1 Bugs:

Fix all data in with arrays actually (MAJOR BUG) 2015.10.30

=cut

1;
