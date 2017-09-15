use strict;
use warnings;
use IO::File;
use List::Util qw[min max];
$| = 1;

my $f1=$ARGV[0];
my $f2=$ARGV[1];
my $al=$ARGV[2];
my $lextrans=$ARGV[3];
my $o = $ARGV[4];

my $subfile = IO::File->new($f1, "r");
my $decorp = IO::File->new($f2, "r");
my $aligned_file = IO::File->new($al, "r"); ### use when augmenting EN
my $fe_file = IO::File->new($lextrans, "r");

my $ceiling = 1000; #augmentation per rare word limit
my $window = 3; #minimum space between two replacements

open(OUT_EN, ">$o.multiaugment.multmax.aug") || die "File not found";
open(OUT_DE, ">$o.multfillout.multmax.txt") || die "File not found";
#open(OUT_RARE, ">$o.rare_stats_after_multiaug.w3.s1000.multmax.txt") || die "File not found";

### LEX FILE
my %lex;
while (not eof $fe_file) {
    my $line = <$fe_file>;
    my @tmp = split /\s/, $line;
    $lex{$tmp[0]} = $tmp[1];
}

### SUB FILE
my %subs_file = ();
my %de_corp = ();
my %aligns = ();
my %en_corp = ();
my %rare_word_set = ();

my $other_sentence = "";
my $current_sentence = "";
my $current_alignments = "";

my $global_counter = 0; #sentence counter
my $local_counter = 0; # word counter, per sentence restarted

while (not eof $subfile) {
    my $line = <$subfile>;
    $line =~ s/^\s+|\s+$//g;
    my $ssstr = substr $line, -1;
    if($line !~ /\{\}/ and $ssstr ne '}') { #is the sentence
        $current_sentence = $line;
        $current_alignments = <$aligned_file>;
        $other_sentence = <$decorp>;
        $other_sentence =~ s/^\s+|\s+$//g;
        $current_alignments =~ s/^\s+|\s+$//g;

        $global_counter = $global_counter + 1;
        $de_corp{$global_counter} = $other_sentence;
        $aligns{$global_counter} = $current_alignments;
        $en_corp{$global_counter} = $current_sentence;
        $local_counter = 0;
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
                if(exists $tmppp[1] and $tmppp[1]=~ /^[0-9,.E]+$/) {
                    $subs_file{$global_counter}{$local_counter}{$tmppp[0]} = $tmppp[1];       
                    $cand_counter = $cand_counter + 1;
                    $rare_word_set{$tmppp[0]} = 0;
                }
            }
        }
        $local_counter = $local_counter + 1;
    }
}

my $size = keys %rare_word_set;
my $goal = $size * $ceiling;

my $augmentedwords = 0;
my %augmentations = ();

my $gradient = 10000;

while($augmentedwords <= $goal and $gradient > 0) {
    $gradient = $augmentedwords;
    foreach my $index (keys %en_corp) {         
        my @en_sentence = split /\s/, $en_corp{$index};
        my @de_sentence = split /\s/, $de_corp{$index};
        my @this_aligns = split /\s/, $aligns{$index};
        my $down = 0;
        my $en_length = scalar @en_sentence;
        my $up = min($en_length, $window);
        while($up <= $en_length) {
            my $pos = $down + int(rand($up - $down - 1));
            my @cands = keys %{$subs_file{$index}{$pos}};
            if(scalar @cands > 0) {
                my $substitut = $cands[rand @cands]; 
                my $nothing = 0;
                foreach my $i (0 .. $#this_aligns){
                    my @tmpp = split /-/,$this_aligns[$i];
                    if($tmpp[1] == $pos) {
                        my $de_pos = $tmpp[0];       #3########### MOI: for now we skip over sentence pairs where the subs is unaligned
                        if (exists $en_sentence[$pos] and exists $lex{$en_sentence[$pos]} and $rare_word_set{$substitut} <= $ceiling) {
                            my $de_substitut = $lex{$substitut};
                            splice @de_sentence, $de_pos, 1, "$de_substitut~$de_sentence[$de_pos]";
                            splice @en_sentence, $pos, 1, "$substitut:$subs_file{$index}{$pos}{$substitut}~$en_sentence[$pos]";
                            my $tmp = join(" ", @en_sentence);
                            $rare_word_set{$substitut} = $rare_word_set{$substitut} + 1;
                            if($rare_word_set{$substitut} > $ceiling) {
                                delete $subs_file{$index}{$pos}{$substitut};
                                $nothing = 1;
                            }
                            last;
                        }
                    }
                }
                if($nothing == 0) {
                     delete $subs_file{$index}{$pos}{$substitut};
                }
            }
            if($up == $en_length) {
                last;
            }
            $down = $pos+$window;
            $up = min($en_length, $down+$window);
        }
        my $en_augmented = join(" ", @en_sentence);
        my $de_augmented = join(" ", @de_sentence);
        if(!exists $augmentations{$en_augmented} and $en_augmented ne $en_corp{$index} and length($de_augmented) > 2) {
            my $number = () = $en_augmented =~ /\~/gi;
            $augmentedwords = $augmentedwords + $number;
            $augmentations{$en_augmented} = 1;
            print OUT_EN "$en_augmented\n";
            print OUT_DE "$de_augmented\n";    
        }
    }
#    print OUT_RARE "$augmentedwords out of $goal\n";
#    foreach my $index (keys %rare_word_set) {
#        print OUT_RARE "$index $rare_word_set{$index}\n";
#    }
    $gradient = $augmentedwords - $gradient;
    print "$augmentedwords words augmented.\n";
}

