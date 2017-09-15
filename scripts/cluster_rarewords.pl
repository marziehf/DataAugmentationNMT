use strict;
use warnings;
use IO::File;

my $f1=$ARGV[0];
my $f2=$ARGV[1];
my $f3=$ARGV[2];
$THERESH=$ARGV[3];

my $fh1 = IO::File->new($f1, "r");
my $fh2 = IO::File->new($f2, "r");
open(OUT_EN, ">$f3") || die "File not found";

my %senss = ();
my %senss2 = ();

while (not eof $fh1 and not eof $fh2) { 
    my $line = <$fh1>;
    my $line2 = <$fh2>;
    my @en_words = split /\s/, $line;

    for my $index (0..$#en_words) {
        my @tmpp = split /\:/, $en_words[$index];
        if(exists $tmpp[0] && exists $tmpp[1] && length $tmpp[0] > 2 && $tmpp[0] =~ /[a-zA-Z]+/) { 
            my @ano = split /\~/, $tmpp[1];
            my $original_string = $tmpp[0].":".$ano[0];
            if(exists $senss{$original_string} and $ano[0] < $THERESH) {
                $senss{$original_string} = $senss{$original_string}.$line;#."\n";
                $senss2{$original_string} = $senss2{$original_string}.$line2;#."\n";
                last;
            }
            elsif(!exists $senss{$original_string} and $ano[0] < $THERESH) {
                $senss{$original_string} = $line;#."\n";
                $senss2{$original_string} = $line2;#."\n";
            }
        }
    }
}

foreach my $word (sort keys %senss) {
    print OUT_EN "$word\n";
    my @en = split /\n/, $senss{$word};
    my @de = split /\n/, $senss2{$word};
    for my $index (0..$#en) {
        $en[$index] =~ s/^\s+|\s+$//g;
        $de[$index] =~ s/^\s+|\s+$//g;
        print OUT_EN "EN: ".$en[$index]."\n";
        print OUT_EN "DE: ".$de[$index]."\n";
    }
    print OUT_EN "\n";
}
