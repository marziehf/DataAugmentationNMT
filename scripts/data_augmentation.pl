use strict;
use warnings;
use IO::File;

my $f1=$ARGV[0];
my $f22=$ARGV[1];
my $al=$ARGV[2];
my $lextrans=$ARGV[3];
my $oo1=$ARGV[4];

my $fh1 = IO::File->new($f1, "r");
#my $fh2 = IO::File->new($f2, "r");
my $decorp = IO::File->new($f22, "r");
my $aligned_file = IO::File->new($al, "r"); ### use when augmenting EN
my $fe_file = IO::File->new($lextrans, "r");

open(OUT_EN, ">$oo1.augment.multmax.aug") || die "File not found";
open(OUT_DE, ">$oo1.fillout.multmax.aug") || die "File not found";

my %subs = ();
my $counter = 0;
my $current_sentence = "";
my $current_alignments;

my %lex;

while (not eof $fe_file) {
    my $line = <$fe_file>;
    my @tmp = split /\s/, $line;
    $lex{$tmp[0]} = $tmp[1]; #en augment
#    $lex{$tmp[1]} = $tmp[0]; #de augment
}
#############################

my $other_sentence;
my $local_counter = 0; # word counter, per sentence restarted

while (not eof $fh1) {
    my $line = <$fh1>;
    $line =~ s/^\s+|\s+$//g;
    my $ssstr = substr $line, -1;
    if($line !~ /\{\}/ and $ssstr ne '}') { #is sentence?

        if($current_sentence ne "") {
            &augmentData;
        }

        $current_sentence = $line;
        $current_alignments = <$aligned_file>;
        $other_sentence = <$decorp>;
        $other_sentence =~ s/^\s+|\s+$//g;
        $current_alignments =~ s/^\s+|\s+$//g;
        $local_counter = 0;
        %subs = ();
    }
    else {
        my @FF1=split /\}/, $line;
        my @F1=split /\{/, $FF1[0];
        my %cands = ();
        if(exists $F1[1] and $F1[0] =~ /[a-zA-ZäöüßÄÖÜẞ]/){
            my @tmp_cands = split /\s/, $F1[1];
            my $cand_counter = 0;
            foreach my $wordi (@tmp_cands) {
                my @tmppp = split /\:/, $wordi;
                if(exists $tmppp[1] and $tmppp[1]=~ /^[0-9,.E]+$/ and length($tmppp[0]) > 2) {
                    $subs{$local_counter}{$cand_counter} = $wordi;                    
                    $cand_counter = $cand_counter + 1;
                }
            }
        }
        $local_counter = $local_counter + 1;
    }
}

sub augmentData {
    my @words = split /\s/, $current_sentence;
    my @aligns = split /\s/, $current_alignments;

    foreach my $origin (sort keys %subs) {
        my $origin_de = "";
        foreach my $i (0 .. $#aligns){
            my @tmpp = split /-/,$aligns[$i];
            if($tmpp[1] == $origin) {     
                $origin_de = $tmpp[0];       #3########### for now we skip over sentence pairs where the subs is unaligned 
            }
        }
        if(exists $words[$origin] and $words[$origin] =~ m/[a-zA-Z0-9äöüßÄÖÜẞ]/ and $origin_de ne "") {
            foreach my $candidate (keys %{ $subs{$origin} }) {
                my $string = "";
                foreach my $i (0 .. $#words){
                    if($i == $origin) { 
                        $string = $string . $subs{$origin}{$candidate}."~".$words[$i]." ";
                    }
                    else {
                        $string = $string .$words[$i]." ";
                    }
                }
############ Augmented bitext
                my @otwords = split /\s/, $other_sentence;
                my $de_string = "";
                foreach my $i (0 .. $#otwords){
                    if($i == $origin_de) {
                        my @pure = split /:/,$subs{$origin}{$candidate};
                        if(!exists $lex{$pure[0]}) {
                            $de_string = $de_string."::: "; #### empty space  
                        }
                        else {
                            $de_string = $de_string.$lex{$pure[0]}."~".$otwords[$i]." ";                            
                        }
                    }
                    else {
                        $de_string = $de_string.$otwords[$i]." ";
                    }
                }
                print OUT_DE $de_string."\n";
                print OUT_EN $string."\n";
            }
        }
    }
}
