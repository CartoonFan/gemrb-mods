#!/usr/local/ActivePerl-5.20/bin/perl5.20.1
# change that when i'm done

use strict;
use warnings;

sub extend {
    my $dummy = shift;
    my $input_baf = shift;
    my $output_baf = shift;
    my $party_num = shift;

#    open(my $input_baf, "tests/test8");
#    s/IF/IF\n#/ge
    my @baf_blocks = split(m{\n\n}x, <$input_baf>); # perl doesn't like this, fix.
    
    foreach (@baf_blocks) { # might need to change if other method is used.
	# it would be ideal to drop this on a LINE
	# loop, not block loop.
#	if ($_ =~ m/^.*NumInParty\(\d\)$/) {
#	    my $NumInParty_orig = $1;
	    # calculate $NumInParty_change according to $party_num
	    # and $NumInParty_orig, not sure, need lynx's opinion.
#	    if ($1 <= 6) {
#		my $NumInParty_change = $1 * 666;
#	    }
#	}
#	if ($_ =~ m/[ ][ ]OR\(\d\)\n/)
	if ($_ =~ m/([ ][ ][ ][ ](.*)Player4(.*)\n)/) {
	    # might need less robust check for the ones that aren't together
	    # or random ordering support too, sigh, that'll get long.
	    if ($_ =~ m/($1[ ][ ][ ][ ](.*)Player5(.*)\n)/) {
		if ($_ =~ m/($1[ ][ ][ ][ ](.*)Player6(.*)\n)/) {
		    for (my $i =7; i<$party_num; i++) {
			s/$1/$2Player$i$3/ # dunno if I should do this with flag g or no
		    }
		}
	    }
	} # if player4

	
    }
}

exit 0;
