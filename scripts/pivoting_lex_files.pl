#!/usr/bin/perl
package main;

use strict;
use warnings;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError) ;

my $e2f_path=$ARGV[1];
my $f2e_path=$ARGV[2];
my $e2f_file = IO::Uncompress::Gunzip->new( $e2f_path ) or die "IO::Uncompress::Gunzip failed ($GunzipError) \n";
my $f2e_file = IO::Uncompress::Gunzip->new( $f2e_path ) or die "IO::Uncompress::Gunzip failed ($GunzipError) \n";

my %lexe2f;
my %lexf2e;

my $THRESH = 0.001;

while (my $row = <$e2f_file>) {
    chomp $row;
    my @line = split(/ /, $row);
    my $word_f = $line[0];
    my $word_e = $line[1];
    my $prob = $line[2];
    $lexe2f{$word_f}{$word_e} = $prob;
#    print "$row ::::::: $n1 $n2 \n";
}
while (my $row = <$f2e_file>) {
    chomp $row;
    my @line = split(/ /, $row);
    my $word_e = $line[0];
    my $word_f = $line[1];
    my $prob = $line[2];
    $lexf2e{$word_e}{$word_f} = $prob;
#    print "$row ::::::: $n1 $n2 \n";
}
foreach my $e1 (keys %lexf2e) {
    foreach my $e2 (keys %lexf2e) {
        my $tmp = 0.0;
        foreach my $f (keys %{ $lexf2e{ $e1 } }) {
            if(exists $lexe2f{$f}{$e2}) {
                $tmp = $tmp + $lexf2e{$e1}{$f} * $lexe2f{$f}{$e2};
            }
        }
        if($tmp > $THRESH) {
            print "$e1 $e2 $tmp \n";
        }
    }
}
