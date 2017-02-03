#!/usr/bin/perl -w
use 5.10.0;
use strict;
use Data::Dumper;
use Carp;
use File::Path qw(make_path remove_tree);
use Getopt::Long;
use File::Copy;
use IO::File;
use CTAH::Event_Export_Config qw( get_cfg_opts config_file );

#External params #said #dir 
#MGrigorov 20170130 version 0.0
#TODO:
#Create POD/help 
#Rewrite to create eve dir structure for every said cause there 
#
my $Opt = {};

unless (@ARGV) {
    confess "Error: wrong arguments, needed at least one";
    }

GetOptions (
        "said=s" => \$Opt->{said},   # numeric
        "dir=s"   => \$Opt->{dir},   # string
        "h|help"  => \$Opt->{help},  # flag
        "force|f" => \$Opt->{force}, # flag
        )
or confess ("Error: external arguments are wrong\n");

say Dumper $Opt;
if ($Opt->{help} ){
    say "example:\n\tperl make_export_paths.pl --said=2093073962 --dir=2093073962\n";
    exit 0;
}

@{$Opt->{saids}} = split( /,/,delete $Opt->{said} );

unless ($Opt->{dir}) {
    $Opt->{dir} = $ENV{HOME} . '/eve/';
} else {
    $Opt->{dir} = $ENV{HOME} . "/$Opt->{dir}/" unless $Opt->{dir} =~ /$ENV{HOME}/i;
    $Opt->{dir} .=  "/eve/" unless $Opt->{dir} =~ /eve\/?$/i;

}

if ( -d $Opt->{dir} ) {
    carp "Warn: the dir[$Opt->{dir}] already exists";
} else {
    make_path ($Opt->{dir}) or confess "Error dir[$Opt->{dir}] cannot be created std_err[$!]";
    carp "Warn: the dir[$Opt->{dir}] is created";
}


my @paths = qw ( conf tmp done scripts results extra data );

for my $path (@paths) {
    if ( not -d $Opt->{dir} . $path ) {
        make_path ($Opt->{dir} . $path) or confess "Error: cannot create path[$Opt->{dir}$path] std_err[$!]";
    }
}

####################################

for my $said (@{$Opt->{saids}} ) {
    confess "Error: invalid said[$said] must be intiger" unless $said =~ /^\d+$/;
    my $said_conf_path = "/eve/conf/$said";
    confess "Error: invalid said[$said] does not exist in $said_conf_path" unless -f $said_conf_path;

    #copy files if not there, if asnwer is yes, dont ask if force flag 
    if ($Opt->{force} || if_exists_ask($said_conf_path) ) {
        copy($said_conf_path, $Opt->{dir} . 'conf/') or confess "Error: copy failed: [ std_err[$!]";
        }

    my $custom_scripts_configs = getConfParams($said , [ 'event', 'loader', 'sub' ] );

    for my $script (values %{$custom_scripts_configs} ) {

            #copy files if not there, if asnwer is yes, dont ask if force flag 
            if ( $Opt->{force} || if_exists_ask($Opt->{dir} . "scripts/$script") ) {
                    copy ("/eve/scripts/$script", $Opt->{dir} . 'scripts/' )
                        or confess "Error: cannot copy [/eve/scripts/$script] to [$Opt->{dir}scripts/] err[$!]";
                    chmod 0755, $Opt->{dir} . "scripts/$script" 
                        or confess "Error cannot chmod file[$Opt->{dir}script/$script] to 755 permitions err[$!]";
                }
    }

    say Dumper $custom_scripts_configs;
    chmod 0666, $Opt->{dir} . 'conf/' . $said or confess "Error cannot chmod file[$Opt->{dir}conf/$said] to 666 permitions err[$!]";
    genConf($said, $Opt->{dir} . 'extra/' . $said . '.conf');

}

say "Success for options:";
say Dumper $Opt;
#################################
sub getConfParams {
#################################
    my $said = shift or confess "Error: said is manda arg";
    my $fields = shift;

    my $config = get_cfg_opts($said);

    if ($fields){
        my $result = {};
        confess "Error: if second argument passed , it must be array ref" unless ref $fields eq 'ARRAY';
        confess "Error: array with requested fields is empty" unless $#{$fields} > 0;

        for my $request_field ( @{$fields} ) {

                if (exists $config->{$request_field} ) {
                        $result->{$request_field} = $config->{$request_field}; 
                } else {
                    carp "Warn: requested field[$request_field] does not exist in config for said[$said]";
                }
        }
        return $result;
    } else {
        return $config;
    }

}
#################################
sub genConf {
#################################
    my $said = shift or confess "Error:said is manda arg";
    my $out_file = shift or confess "Error: dir is manda arg";
    my $config_body = <<"END_CONF";
\$SAID    = q{$said};
\$cheetah = q{mgrigorov};
\$debug   = 2;
\$cdb     = 1;
#####
\$test_path = qq{/historical/testexports/\$cheetah/};
1;
END_CONF
     
#    say Dumper $config_body;
    my $fh = IO::File->new();

    if ($fh->open("> $out_file")) {
       print $fh $config_body;
       $fh->close;
    }

}
###################################
sub if_exists_ask {
###################################
    my $file = shift or confess "Error: file path is manda request";
    if (-f $file ) {
        carp "\nWarning file[$file] exists";
        say "\tDo you want to replace it? Y/N:";
        my $answer = <STDIN>;
        chomp $answer;

            while ($answer !~ /^y$|^n$/i ) {
                say "\tDo you want to replace it? Y/N:";
                $answer = <STDIN>;
            }

        if ($answer =~ /y/i ){
            return 1;
        } else {
            return undef;
        }
    } else {
        return 1;
    }

}

1;
