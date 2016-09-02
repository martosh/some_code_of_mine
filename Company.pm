package Fins::Company; 

use strict;
use warnings;
use Data::Dumper;
use 5.10.1;
use Carp;
use Sort::Naturally;
use List::MoreUtils qw(uniq);
use lib qw( /home/martosh/scripts/Mmod/ /home/admin_la/mgrigorov/Mmod );
use mtools qw(d deb );

################################
# VERSION 0.0.3 from 20.02.2015
################################

# Constructure
sub new {
	my ($self, $file, $sheet, $company, $data, $septag) = @_;

	 $self = bless {
		'File' => $file,
		'Sheet' => $sheet,
		'Company'=> $company,
		'Data'=>$data,
		'OutFilename'=> "$company.txt",
		'Septag' => $septag,
	}, $self;

	return $self;
}

#####################
# Company Accessor RW
sub Company {
	my $self = shift;
	if (@_) {
		$self->{Company} = shift;
	}
	return $self->{Company};
}


####################
# Sheet Accessor RW
sub Sheet {
	my $self = shift;
	if (@_) {
		$self->{Sheet} = shift;
	}
	return $self->{Sheet};
}

####################
# File Accesor RW
sub File {
	my $self = shift;
	if (@_) {
		$self->{File} = shift;
	}
	return $self->{File};
}

#################################
# Output Filename Accessor RW

sub OutFilename {
	my $self = shift;
	if (@_) {
		$self->{OutFilename} = shift;
	}
	return $self->{OutFilename};
}

#################################
# Change|Replace|Create acc_code with new one 

# $o->mapAccCode ($target_accCode, $newAccCode, $newAccValue(optional), -f(optional if you want to create if does not exists) )  Write
sub mapAccCode {
	
	my $self = shift;
	my ( $target_acc_code, $new_acc_code, $new_acc_value) = @_;
	confess "Died:mapAccCode must take targetAccCode and newAccCode for arg" unless $target_acc_code and $new_acc_code;
	say "target[$target_acc_code] new_code[$new_acc_code]"; 
	my $sep_tag = $self->{Septag};
        my $Data = $self->{Data};
		
ROW:	for my $row ( sort { ncmp($a, $b) } keys %{$Data} ) {
		my $value = $Data->{$row};
	        my ($acc_value) = $value =~ /(.*?)$sep_tag/i; my ($acc_code) = $value =~ /$sep_tag(.*?)$/i;
		if ( $target_acc_code eq $acc_code ) {
			if (defined $new_acc_value){
			$Data->{$row} = $new_acc_value.$sep_tag.$new_acc_code;
			return 1;
			}
#			deb ( "mapAccCode in if eq old to new-p-", "new[$new_acc_code],acc_val[$acc_value]");
			$Data->{$row} = $acc_value.$sep_tag.$new_acc_code;
			return 1;
		}	
	}

	for (@_) {
	      if ($_ =~ /^-?-?force$|^-?-?f$/i ) {		
		      $self->newAccCode($new_acc_code, $new_acc_value);
		      return 1;
		}
	}
	
	carp "The desired accCode was not found[$target_acc_code]";
	return undef;

} 

################################
# add new acc code;
# $o->addAccCode($new_AccCode, $new_AccValue(Optional));  Write
sub newAccCode {
        my $self = shift;
        my ($new_acc_code) = shift || confess "Died:You must give some acc code to be created";
	my $new_acc_value = shift;  #Optional 
        my $sep_tag = $self->{Septag};
        my $Data = $self->{Data};

	my @rows = sort {ncmp($a, $b) } keys %{$Data};
#	say Dumper \@rows;
	my $newrow = $rows[$#rows];
	$newrow++;
#	deb ( "newAccCode-p-", "row[$newrow]new[$new_acc_value$sep_tag$new_acc_code]");	
	$self->{Data}->{$newrow} = "$new_acc_value$sep_tag$new_acc_code";
#	deb ( "Data-p-", $self->{Data});
	return 1; 
}

################################
# Add to body use same method newAccCode;
sub addToFileBody {
	my $self = shift;
	my $somethingToAdd = shift || confess "Died:You must give me some argument to add it into Output Body File ";
	my $some_else = shift;
	$some_else = '' unless defined $some_else;
	my $result = $self->newAccCode( $somethingToAdd, $some_else);
#	d ( "addToBody", "1[$somethingToAdd] 2[$some_else] result[$result]");
	return 1;
}

##################################
#mass AccCode remap/modify 

#  $o->Cycle($cycle); # if return $hash->{row} eq delete|del it will delete the reccord
#   my $cycle = sub {
#	my $p = shift;
#	say Dumper $p->{value};
#
#	};

sub Cycle {
        my $self = shift;
	my $sub = shift;
	confess "Died CycleMethod needs	       #acc_code acc_val  sub ref" unless ref $sub eq 'CODE';
        my $sep_tag = $self->{Septag};
        my $Data = $self->{Data};

ROW:    for my $row ( sort { ncmp($a, $b) } keys %{$Data} ) {
		 my $value = $Data->{$row};
		 my ($acc_value) = $value =~ /(.*?)$sep_tag/i; my ($acc_code) = $value =~ /$sep_tag(.*)/i;
		 my $comment;
		 if ( $acc_code =~ /\s*#/) {
		 	($comment) = $acc_code =~ /(\s*#.*)/i;	
		 	$acc_code =~ s/(\s*#.*)//i;	
		  }
 
		 my $return = &$sub( {row=>$row, code=>$acc_code, value=>$acc_value, septag=>$sep_tag });

		if ($return->{row} =~ /^delete$|^del$/i) { # delete - user decition
                 	delete $Data->{$row};
			} else {
				if ($comment) {
			        $Data->{$return->{row}} = $return->{value}.$return->{septag}.$return->{code}.$comment;
				} else{
			        $Data->{$return->{row}} = $return->{value}.$return->{septag}.$return->{code};
				}
			}
	}

	return 1;
};


##############################################################
# Clean duplicate lines;

sub cleanDup {
	my $self = shift;
	my $seen = {};
	my $cycle = sub {
               my $p = shift;
#             deb("start params-p-", $p);

	#		 'code' => '10000000',
        #		  'row' => '9',
        # 		 'value' => '18659.25887',
        # 		 'septag' => ' '
		my $key = "$p->{code}$p->{septag}$p->{value}";

                $p->{row} = 'del' if exists $seen->{$key}; 
		$seen->{$key} = 1;
		
#              deb("return params-p-", $p) if $p->{row} eq 'del';
                return $p;

        };

	 $self->Cycle($cycle);
	return 1;

}


#############################
 # Data manipulation methods 
#############################

# $o->AccCode($accCode) Accessor Read/Write get/set 
sub AccCode {
	my $self = shift;
	my $Data = $self->{Data};
	my $sep_tag = $self->{Septag};
	my $targetAccCode = shift ||  confess "You must give me some Acc_code";
		
ROW:	for my $row ( sort { ncmp($a, $b) } keys %{$Data} ) {
		my $value = $Data->{$row};
	        my ($acc_value) = $value =~ /(.*?)$sep_tag/i;     my ($acc_code) = $value =~ /$sep_tag(.*?)$/i; #separate regex on purpuse	
		if ($targetAccCode eq $acc_code ) {
			if (@_) {
			   carp "\nWarning you are making changes on DP's data-AccCode[$targetAccCode]=[$_[0]] instead of[$acc_value]\n";
			   $self->{Data}->{$row} = "$acc_code$sep_tag$_[0]";
			   return 1; 
			}
		   return $acc_value;
		}
	}

	return undef;
	#counter return;
}


#############################################################################
# do some mathematical oprations over the values 

#$obj->DoMath(13001=13100+13103+13102);

sub DoMath{
	my $self = shift;
	my $accountRule = shift || confess "Died you must give me some equation...exaple Е=МС2";
#	my $action = shift;	
	my $total;
	my $new_value = 0;
	if ( $accountRule =~ s/^(.*?)\=//i ) {
		$total = $1;
		} else {
		confess "Dies-invalid equation, please use the exampe '130000=245000+27000+250000' [$accountRule]";
		}
	my $sign;

	# define the sign +|-|/|x
	      if ( my (@signs) = $accountRule =~ /(\+|\-|\/|\*)/g ) {
			my @uniq = uniq(@signs);
			confess "\nDIED:You may use only one type of mathematical operation ex:130000=245+270+234" if scalar @uniq > 1;
			$sign = shift @uniq;
			} else { 
			confess "Died:There is no oprational signs(+|-|*|/) in [$accountRule]";
			}
	
	my @acc_codes = split /\Q$sign\E/, $accountRule;
		for my $acc_code (@acc_codes) {
		    my $GetValue = $self->AccCode($acc_code);

		    if ($GetValue) {
#			say "\nPrepare to do the math... [$new_value] [$sign] get[$GetValue]";
		        $new_value = $new_value / $GetValue if $sign eq '/';
		        $new_value = $new_value + $GetValue if $sign eq '+';
		        $new_value = $new_value - $GetValue if $sign eq '-';
		        $new_value = $new_value * $GetValue if $sign eq '*';
		    }

		}
		       #acc_code acc_val 	
	my $answer = $self->AccCode($total, $new_value);
	
#	deb ( "answer-p-", $answer);
	unless ($answer) { # if does not exists acc_code create it 
	for (@_) { 
		if ($_ =~ /^-?-?force$|^-?-?f$/i ) { # if you decide to create it with -f options		
#			deb ( "in-p-", "new_code[$total],-$new_value");
			$self->newAccCode($total, $new_value);
		        return $new_value;
			}
		}
	}

	return $new_value;
}


#To Do
# DO YAML PRINT
=head1 Author:

MGrigorov

=head1 Version:

0.0.1

=head1 Documentation by:

MGrigorov 2015-02-23

=head1 Description:

Designed to implement OOP methods in Fins::load.pm in function "generate_output_files".
This is actually custom function that allows to user to access the data with some methods.
oop_alternatives=>\&oop_alternatives_form_outputs this is the option that determine that the user wants to use OOP  generate_output_files.
For more info please read Fins::load docs, section - generate_output_files.

=head1 Methods:

=over

=item * Company Accessor Read/Write (Get most used) 
	my $company =  $obj->Company($<optional>); #get
	$obj->Company('you can set company but still we don't need that most of the times');
	return 'REJECTED' if $company =~ /^Impresa S.A some name/ # skip this company;

=item * Sheet Accessor RW
	my $sheet = $obj->Sheet(); # get sheetname if you want to do some checks on specific sheet
	my $mm = $sheet =~ /\d{2}Month/;
	return 'REJECTED' if $sheet =~ /not needed info/;

=item * File Accessor RW
	my $file = $obj->File(); # get excel filename if you want to do some checks on specific filenames
	my ($mm, $yyyy) = $file =~ /(\d{2})\_(\d{4})/;

=item * Output Filename Accessor (Set how will be named your txt|yaml filemane );
	$obj->OutFilename("$mm-$yyyy-$company.txt");  # Defalt will be the "$obj->Company() . 'txt'", only the company_name

=item * AccCode Accessor R
	$obj->AccCode($accCode) Accessor Read/Write get/set 
	my $value111111 = $obj->AccCode('1111111') # this will return value of 111111 or false if does not exists; 

=item * Change|Replace|Create AccCode with new one
        $obj->mapAccCode ($target_accCode, $newAccCode, $newAccValue(optional), -f(optional if you want to create it if does not exists) )
        $obj->mapAccCode ( '1110004', 2220007, '-455 552,446', -f ) # this will change code 1110004 to 2220007 with value -455 552,446 and it will create it if 1110004 does not exists;

=item * Add new AccCode;
	$obj->addAccCode($new_AccCode, $new_AccValue(Optional));  Write
	$obj->addAccCode( 77733377 ) this will create acc code 77733377 with no value;
	$obj->addAccCode( 77733377 , '12345345.123' ) this will create acc code 77733377 with value

=item * Add to body use same method newAccCode;
	$obj->addToFileBody( 'sometext', $obj->Company() ); # this will add "sometext\t$obj->Company()" in you txt

=item * Do some mathematical oprations over the account values 

	$obj->DoMath(13001=13100+13103+13102 '-f'(optional will create the acc_code if missing)); #acc_code 13001 will be eq to 13100+13103+13102 if they exists else will return false;

	Note that you can use '+','-','/','*' but you can use only one mathemathical sign
	$obj->DoMath(123444=400000-555555, -f) 

=item *  Clean duplicate lines;
	$obj->cleanDup(); #this will clean all duplicated lines if you have 111111    1243445.4444 more than one times it will clean it

=item * Mass AccCode remap/modify in cycle


	$obj->Cycle($cycle); # if return $hash->{row} eq delete|del it will delete the reccord

	my $cycle = sub {
		my $params = shift;

		#my $row = $params->{row};
		#my $acc_code = $params->{code};
		#my $acc_value = $params->{value};
		#my $separator = $params->{septag};
	
		$params->{code} =~ s/\.//g # clean all dots in acc_codes
		$params->{value} = sprintf("%.4f", $params->{value}) if $params->{value} =~ /\d+/; 
		$params->{row} = 'delete' if $params->{value} !~ /\d+/;

		say Dumper $params->{value};
		return $params;
	};

=item * Example:

	sub oop_alternatives_form_outputs {

		my $obj = shift;
		
		my $cycle = sub {
			my $params = shift;
			$params->{row} = 'del' if $params->{code} !~ /\d{5}/i; # del all rows if does not contain /d{5}
			$params->{value} = sprintf("%.4f", $params->{value}) if $params->{value} =~ /\d+/; 
			return $params;	
		};
		
		$obj->Cycle($cycle);
		
		my $company = company_clean (  $obj->Company() );
		my $company_code = $name_to_isic->{$company};	
		confess "Not mapped company name[$company] to code" unless $company_code;
		my $file = $obj->File();
		
		my ($yyyy, $mm) = $file =~ /(\d{4})\_(\d{2})/;
		
		for my $regex ( keys %{$name_to_isic} ) {
			if ($company =~ /$regex/ ) {
				$company_code = $name_to_isic->{$regex};
				last;
			}
		}
		
		$obj->addToFileBody('setExternalCompanyId', $company_code);
		$obj->addToFileBody('setFperiodYear', $yyyy);
		$obj->addToFileBody('setFperiodMonth', $mm);
		
		for my $config_key ( keys %{$fins_config} ) {
			$obj->addToFileBody( $config_key, $fins_config->{$config_key});
		}
		
		$company =~s/\s\s*/ /g;	
		$company =~ s/ /\_/g;
		$company =~ s/\.//g;
		$obj->OutFilename("$mm-$yyyy-$company.txt");
		
		return $obj;

	}

=back


=head1 Relations:

B<Fins::load.pm>

=head1 ToDo:

Add actual yaml_print function.
Add deleteCode Method
To fix if false some method to return undef

=head1 Bugs:

Still on testing stage

=cut

1;



