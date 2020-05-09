#!/usr/bin/perl -w

use strict;
use warnings;
use diagnostics;

my @outarray;
my %outhash;
open (FH, "<", <~/.bash_history>) or die "Can't open history: $!";
my @contentarray = (<FH>);
close (FH);

while (my $str = pop @contentarray) {
	$str =~ s/(\s|\n)*$//;
	if ($str =~ m/^#/) {
		next if($outarray[0] =~ m/^#/);
	} elsif (exists $outhash{$str}) {
		next;
	}
	$outhash{$str} = 1;
	unshift @outarray, $str ;
}

my $tofile = join ("\n", @outarray)."\n";

open (WFH, ">", <~/.bash_history>) or die "Can't open history: $!";
print WFH $tofile;
close (WFH);
