use strict;
use warnings;
use IO::File;

my $f1=$ARGV[0];
my $f2=$ARGV[1];
my $o=$ARGV[2];

my $fh1 = IO::File->new($f1, "r");
my $fh2 = IO::File->new($f2, "r");

open(OUT, ">$o") || die "File not found";

my $counter = 0;
my $current_sentence = "";
my %subs = ();

while (not eof $fh1 and not eof $fh2) {
    my $line = <$fh1>;
    my $line2 = <$fh2>;
    my $ssstr = substr $line, -1;
    my $ssstr2 = substr $line2, -1;
    if($line =~ /^\s*$/ and $line2 =~ /^\s*$/) {
        next;
    }
    elsif($line eq $line2 and $line !~ /\{\}/ and $line2 !~ /\{\}/) {
        print OUT $line;
        %subs = ();
        $counter = 0;
        chomp $line;
        $current_sentence = $line;
        next;
    }
    else {
        my $output = "";
        my %dates = ();
        my @FF1=split /\s\}/, $line;
        my @FF2=split /\s\}/, $line2;
        my @F1=split /\s\{/, $FF1[0];
        my @F2=split /\s\{/, $FF2[0];
        my @cands1;
        my @cands2;
        if(exists $F1[1]){
            @cands1 = split /\s/, $F1[1];
        }
        if(exists $F2[1]){
            @cands2 = split /\s/, $F2[1];
        }
        $output = $output.$F1[0]."{";
        my @comn_array;
        my @sort_s_array = sort { $a cmp $b } @cands1;
        my @sort_l_array = sort { $a cmp $b } @cands2;
        my %seen1 = (); my @un_s_array = grep { ! $seen1{$_}++ } @sort_s_array;
        my %seen2 = (); my @un_l_array = grep { ! $seen2{$_}++ } @sort_l_array;
        foreach my $s_el  (@un_s_array){
            foreach my $l_el (@un_l_array){
                push @comn_array, $l_el if $s_el eq $l_el;
            }
        }
        my $tmp_c = 0;
        foreach my $el (@comn_array){
            if(length($el) > 1) {
                $output = $output.$el." ";
                $subs{$counter}{$tmp_c} = $el;
                $tmp_c = $tmp_c + 1;
            }
        }
        $output =~ s/^\s+|\s+$//g;
        $output = $output."}\n";
        $counter = $counter + 1;
        print OUT $output;
    }
}
