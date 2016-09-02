#!/usr/bin/perl
use strict;
use warnings;

use Win32::Process;
use 5.10.1;
use Data::Dumper;
use File::Basename;
use File::Path;
use Carp;

# Author MGrigorov 
# VERSION 0.0.1 => 2015.09.01 #Create
# Goal - monitor windows word process and kill unnecessary ones

$0 = fileparse($0);
say "Script [$0](me) Initiated with pid [$$]";
openlog("Script [$0] Initiated with pid [$$]");

# CONFIG:
my $cfg = {};
$cfg->{sleep_seconds}       = '3';
$cfg->{cpu_timeout_seconds} = '15';
$cfg->{program_to_kill}     = 'WINWORD.exe';
$cfg->{logdir}              = 'C:\Users\Administrator\Desktop\killerLog\\';
#create lodgdir if must.

unless ( -d $cfg->{logdir} ){
     mkpath([$cfg->{logdir}],1,0755);
}

# Format log file
my $date = `echo %DATE%`;
$date =~ s/\s//g;
$date =~ s/\//_/g;
chomp $date;


my $logfile = $cfg->{logdir} . $0 . '_' . $date . '.log.txt';
openlog( "Starded with Config:" . Dumper $cfg);

# Kill similar scripts if exits

my $self_pid_check = `tasklist /nh /v /fo csv`;
chomp($self_pid_check);

my @self_pid_check = split /\n/, $self_pid_check;

say "Search for other processes trigered $0";

for my $process_to_check (@self_pid_check) {
    my @fields = split /,/, $process_to_check;
    @fields = map { s/"//g; s/'//g; $_ } @fields;

    #	say Dumper \@fields;
    my $pid          = $fields[1];
    my $init_program = $fields[0];
    my $win_title    = $fields[-1];

    #        next if $init_program =~ /vim|cmd/i; #ignore vim or manual started

    if ( $init_program =~ /perl\.exe/i and $win_title =~ /taskeng\.exe|N\/A/ ) {

        #		say "compare my pid [$$] with found pid[$pid]";

        if ( $pid ne $$ ) {
            say "Found same script[$0] triggered by [$init_program], so I will kill pid[$pid]";
            my $kill_result = Win32::Process::KillProcess( $pid, 1 );

            if ( $kill_result == 1 ) {
                say "Found process was killed[$pid]";
                openlog("Found similar proces like himself and pid[$pid] killed!");
            }

            #say "Result[$result]
        }
    }
}

say "Start checking for program[$cfg->{program_to_kill}]";

while (1) {
    sleep $cfg->{sleep_seconds};

    my $pid_list = `tasklist /nh /v /fi "IMAGENAME eq $cfg->{program_to_kill}" /fo csv`;

    #my $pid_list = `tasklist /nh /v /fi "STATUS eq running" /fo csv`;
    chomp $pid_list;

    next if $pid_list =~ /No tasks are running which match/i;

    my @pids = split /\n/, $pid_list;
    say Dumper \@pids;

    #"Image Name","PID","Session Name","Session#","Mem Usage","Status","User Name","CPU Time","Window Title"

    for my $pid_line (@pids) {    #'"csrss.exe","380","Console","1","7,016 K","Running","NT AUTHORITY\\SYSTEM","0:00:18","N/A"',
        my @fields = split /,/, $pid_line;
        @fields = map { s/"//g; s/'//g; $_ } @fields;
        say Dumper \@fields;
        my $pid          = $fields[1];
        my $pid_cpu_time = $fields[8];
        my $program_name = $fields[0];

        if ( $pid_cpu_time =~ /\d+:\d+:(\d+)/ ) {
            my $cpu_seconds = $1;

            if ( $cpu_seconds >= $cfg->{cpu_timeout_seconds} ) {

                my $bload = check_load();
                say "INFO: Before kill availableMEM[$bload->{mem}] cpu\%load[$bload->{cpu}]";
                openlog("INFO: Before kill availableMEM[$bload->{mem}] cpu%load[$bload->{cpu}]");

                my $result = Win32::Process::KillProcess( $pid, 1 );

                if ( $result == 1 ) {
                    say "Program[$program_name] Pid[$pid] killed by[$0] cause cpuTime more than[$cfg->{cpu_timeout_seconds}] sec";
                    openlog( "Program[$program_name] with Pid[$pid] killed by[$0] cause cpuTime more than[$cfg->{cpu_timeout_seconds}] sec"
                    );
                } else {
                    openlog("Error: can't kill[$pid] for program[$program_name]");
                }

                my $load = check_load();
                say "INFO: after kill availableMEM[$load->{mem}] cpu%load[$load->{cpu}]";
                openlog("INFO: after kill availableMEM[$load->{mem}] cpu%load[$load->{cpu}]");
            }
        }

        openlog("MONITOR PID: pid[$pid] with cpu_time[$pid_cpu_time]");
        say "MONITOR PID: pid[$pid] with cpu_time[$pid_cpu_time]";
    }
}

#################### CHECK SYSTME LOAD ########
sub check_load {
    my $result       = {};
    my $memory_usage = `systeminfo |find "Available Physical Memory"`;
    my $cpu_load     = `wmic cpu get loadpercentage`;
    chomp( $memory_usage, $cpu_load );

    $memory_usage =~ s/[^\:]+?:\s*//;
    $result->{mem} = $memory_usage;

    $cpu_load =~ s/\D//g;
    $result->{cpu} = $cpu_load;

    #say "After kill CPU_LOAD[$cpu_load] MOM[$memory_usage]";
    return $result;
}

#################### OPENLOG ##################

sub openlog {

    my $logrec = shift;

    my $date = `echo %DATE%`;
    my $time = `echo %TIME%`;
    chomp( $date, $time );
    $date =~ s/\s//g;
    $time =~ s/\s//g;

    #	 die "DEBUG date[$date] time[$time]\n";

    if ( defined $logfile ) {
        open my $LOG, ">>", $logfile or croak "Die:Cannot open [$logfile]\n";
        print $LOG "\n[$date|$time] LOGING_from[$0]:\n$logrec\n\n";
        close $LOG;
    } else {
 #      carp "openlog: You should declare \$logfile variable in the script[$0] to log";
    }
    return;

}

1;

