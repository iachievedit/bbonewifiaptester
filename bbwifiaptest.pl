#!/usr/bin/perl
#
# Copyright (c) 2015 iAchieved.it LLC
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

use strict;
use warnings;
use Getopt::Long;
use Proc::Daemon;
use Net::Int::Stats;
use Net::Ifconfig::Wrapper;
use Cwd;

# Parse arguments
our $logfile    = "/var/log/bbwifiaptest.log";
our $speedtest  = "/usr/local/bin/speedtest-cli";
our $wirelessif = "wlan0";
our $no_daemon  = 0;
our $log_console = 0;

GetOptions("logfile=s" => \$logfile,
           "speedtest=s" => \$speedtest,
           "wirelessif=s" => \$wirelessif,
           "no-daemon"       => \$no_daemon,
           "log-console"     => \$log_console);

Proc::Daemon::Init unless $no_daemon;

my $continue = 1;
$SIG{TERM} = sub { 
  $continue = 0;
  led_off();
};

$SIG{__DIE__} = sub {
  led_red();
};

# Set up GPIO
system "(echo 66  > /sys/class/gpio/export) >/dev/null 2>&1";
system "(echo 67  > /sys/class/gpio/export) >/dev/null 2>&1";
system "echo out > /sys/class/gpio/gpio66/direction";
system "echo out > /sys/class/gpio/gpio67/direction";
sleep 1;

led_off();

sub led_green {
  system "echo 1 > /sys/class/gpio/gpio66/value";
  system "echo 0 > /sys/class/gpio/gpio67/value";
}
sub led_red {
  system "echo 0 > /sys/class/gpio/gpio66/value";
  system "echo 1 > /sys/class/gpio/gpio67/value";
}
sub led_orange {
  system "echo 1 > /sys/class/gpio/gpio66/value";
  system "echo 1 > /sys/class/gpio/gpio67/value";
}
sub led_off {
  system "echo 0 > /sys/class/gpio/gpio66/value";
  system "echo 0 > /sys/class/gpio/gpio67/value";
}
sub stats {
  my $Iface   = $wirelessif;
  my $get_Iface_data = Net::Int::Stats->new();
  my $rx_bytes  = $get_Iface_data->value($Iface, 'rx_bytes');
  my $tx_bytes  = $get_Iface_data->value($Iface, 'tx_bytes');
  logmsg("$wirelessif RX $rx_bytes");
  logmsg("$wirelessif TX $tx_bytes");
}

# Assume we're good until we figure out otherwise
led_green();

# Our log file
open our $LOG, ">>", $logfile or die;
sub logmsg {
  my $msg = shift;
  my $time = localtime;
  print $LOG "$time: [I] $msg\n";  
  print "$time: [I] $msg\n" if $log_console;
}

logmsg("ENTRY");
logmsg("START");

# First test, make sure we can find speedtest
if (! -e $speedtest) {
  # If we can't find speedtest-cli look in current directory for --no-daemon
  # case
  if ($no_daemon) {
    my $dir = getcwd;
    if (! -e "${dir}/speedtest-cli") {
      logmsg("ERROR:  speedtest-cli not at $speedtest or $dir/speedtest-cli");
      logmsg("EXIT");
      die;
    }
    $speedtest = "${dir}/speedtest-cli";
    logmsg("Using speedtest-cli at ${speedtest}");
  } else {
    logmsg("ERROR:  $speedtest not found");
    logmsg("EXIT");
    die;
  }
}

stats();
my $networkDownCount = 0;
while ($continue) {

   my $output = `${speedtest} --simple`;

   if ($output =~ /Could not retrieve speedtest/) {
     led_orange();
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
       led_green();
       stats();
       $networkDownCount = 0;
     }
   }

}

