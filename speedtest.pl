#!/usr/bin/perl

use strict;
use warnings;
use Proc::Daemon;
use Net::Int::Stats;
use Net::Ifconfig::Wrapper;

Proc::Daemon::Init;

off();

my $continue = 1;
$SIG{TERM} = sub { 
  $continue = 0;
  off();
};

$SIG{__DIE__} = sub {
  red();
};

# Set up GPIO
system "echo 66  > /sys/class/gpio/export";
system "echo 67  > /sys/class/gpio/export";
system "echo out > /sys/class/gpio/gpio66/direction";
system "echo out > /sys/class/gpio/gpio67/direction";
sleep 5;

sub green {
  system "echo 1 > /sys/class/gpio/gpio66/value";
  system "echo 0 > /sys/class/gpio/gpio67/value";
}
sub red {
  system "echo 0 > /sys/class/gpio/gpio66/value";
  system "echo 1 > /sys/class/gpio/gpio67/value";
}
sub orange {
  system "echo 1 > /sys/class/gpio/gpio66/value";
  system "echo 1 > /sys/class/gpio/gpio67/value";
}
sub off {
  system "echo 0 > /sys/class/gpio/gpio66/value";
  system "echo 0 > /sys/class/gpio/gpio67/value";
}
sub stats {
  my $Iface   = "wlan0";
  my $get_Iface_data = Net::Int::Stats->new();
  my $rx_bytes  = $get_Iface_data->value($Iface, 'rx_bytes');
  my $tx_bytes  = $get_Iface_data->value($Iface, 'tx_bytes');
  logmsg("RX $rx_bytes");
  logmsg("TX $tx_bytes");
}

# Assume we're good until we figure out otherwise
green();

# Our log file
open our $LOG, ">>", "/var/log/speedtest.log" or die;
sub logmsg {
  my $msg = shift;
  my $time = localtime;
  print $LOG "$time: [I] $msg\n";  
}

logmsg("ENTRY");
logmsg("START");
stats();
my $networkDownCount = 0;
while ($continue) {

   my $output = `./speedtest-cli --simple`;

   if ($output =~ /Could not retrieve speedtest/) {
     orange();
     $networkDownCount++;
     logmsg("NETWORK UNAVAILABLE = $networkDownCount");
     sleep 20;
     if ($networkDownCount == 10) {
       logmsg("STOP");
       stats();
       logmsg("EXIT");
       die;
     }
   }

   #Output looks like this
   #Ping: 17.586 ms
   #Download: 13.57 Mbit/s
   #Upload: 18.92 Mbit/s

   my @lines = split(/\n/, $output);

   foreach my $line (@lines) {
     if ($line =~ /Download:\s+([0-9\.]+)(.*)$/) {
       logmsg("Download Speed: $1 $2");
       green();
       stats();
       $networkDownCount = 0;
     }
   }

}

