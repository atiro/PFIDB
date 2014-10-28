#!/usr/bin/perl
# Quick display of column from CSV rows

use Text::CSV;
use v5.10;

use strict;

my $filename = shift or die "Failed to pass filename";
my $col = shift or die "Failed to pass column number";

my $csv = Text::CSV->new( { binary => 1 } );

open my $fh, "<$filename" or die "Failed to opne file - $!";

my $i = 0;
while( my $row = $csv->getline( $fh)) {
        say "$i ", $row->[$col];
        $i++;
}

close $fh;
