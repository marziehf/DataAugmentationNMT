
use strict;
use warnings;
use IO::File;

my $f1=$ARGV[0];
my $f2=$ARGV[1];
my $THRESH = $ARGV[2];

my $fh1 = IO::File->new($f1, "r");
my $fh2 = IO::File->new($f2, "r");
open(OUT_EN, ">$f1.filtered.$THRESH") || die "File not found";
open(OUT_DE, ">$f2.filtered.$THRESH") || die "File not found";

while (not eof $fh1 and not eof $fh2) { 
    my $line = <$fh1>;
    my $line2 = <$fh2>;
    my @en_words = split /\s/, $line;
    my $shouldIwritethis = 0;
    my $unkcount = 0;
    my $string = "";
    for my $index (0..$#en_words) {
        if($en_words[$index] eq 'unk') {
            $unkcount = $unkcount + 1;
        }
        my @reall = split /~/, $en_words[$index];
        my @tmpp = split /\:/, $reall[0];
        if(exists $tmpp[0] && exists $tmpp[1] && length $tmpp[0] > 2 && length $tmpp[1] < 4 && $tmpp[0] =~ /[a-zA-Z]+/) {
            if($tmpp[1] < $THRESH) {
                 $string = $string." ".$tmpp[0]; 
                 $shouldIwritethis = 1;
            }
        }
        else {
            $string = $string." ".$en_words[$index];
        }
    }
    if($shouldIwritethis == 1 and $unkcount < 6) {
        my $de_string = "";
        my @de_words = split /\s/, $line2;
        for my $index (0..$#de_words) {
            my @reall = split /\~/, $de_words[$index];
            $de_string = $de_string." ".$reall[0];    
        }
         $de_string =~ s/^\s+|\s+$//g;
         $string =~ s/^\s+|\s+$//g;
         print OUT_DE $de_string."\n";
         print OUT_EN $string."\n";
    }
}
