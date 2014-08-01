#!/usr/bin/perl
# Simple script that helped me to quickly regression test ipset mark &
# markmask while I developed it.
#
# Takes no arguments.

use strict;
use warnings;
use Test::More tests => 2;

my $send_packets = 25; 
my $pkt_marks = int(0xffffffff);

# Start fresh
system("iptables -F");
system("iptables -X");
system("iptables -Z");
system("ipset destroy");

system("ipset create mytest ipmarkhash counters hashsize 5012 markmask 0xde");
system("iptables -N pktmark");
system("iptables -A pktmark -j MARK --set-mark 0");
system("iptables -N add");
system("iptables -A add -j SET --add-set mytest src,src");
system("iptables -A OUTPUT -j pktmark");
system("iptables -A OUTPUT -m set ! --match-set mytest src,src -j add");

for (1..$send_packets) {
	my $mark = int rand $pkt_marks;
	system("iptables -R pktmark 1 -j MARK --set-mark $mark");
	system("ping -c 1 8.8.8.8 1> /dev/null");
}

my ($pktcounter, $entries) = 0;
my @res = split /\n/, `ipset list mytest`;

foreach my $line (@res) {
	my ($pkt) = $line =~ /^\d+\.\d+\.\d+\.\d+,0x\S+\ packets\ (\d+)\ bytes\ \d+/ix;
	next if (!$pkt);
	$pktcounter += $pkt;
	$entries += 1;
}

is( $pktcounter, $send_packets, 'all packets were counted' );

cmp_ok($entries, '<=', $pkt_marks, 'there are no more then allowed entries');
