#!/usr/bin/env perl
# change that when i'm done

use strict;
use warnings;

use File::Basename;

# files not to touch
#my $exceptions = "cut35h.baf test31 uddrow16.d udlesa.d player1.dlg";
my $exceptions = " cut35h.baf cut35h.bcs test08 test31 uddrow16.d udlesa.d udlesa.dlg uddrow16.dlg fguard.bcs fguard.baf _fguard.bcs _fguard.baf ";

# reads passed BAF and extends it to request max party count if needed
sub extend {
    my $input_file = shift;
    my $output_file = shift;
    my $party_num = shift;

    # skip false positives like Faldorn's pit fight teleporter
    if (index(lc $exceptions, lc basename "$input_file") != -1) {
        return 0;
    }

    open(my $output_handle, "+>", "$output_file");
    open(my $baf_handle, "<:utf8", "$input_file");
    my $input_text = do { local $/; <$baf_handle> };
    my @baf_blocks = split(m{\n\n}x, $input_text) or die "Couldn't split $input_file (empty?): $!";
    # read data, close file
    close($baf_handle);

    # shortcircuit scripts that won't need changing
    # IOW those that have no mentions of Player6
    if ((grep /Player6/, $input_text) == 0) {
        close($output_handle);
        return 0;
    }

    # treat dialogs separately, since the format is different
    if ($input_file =~ /d$/i or $input_file =~ /\.dlg$/i) {
        my $rc = extendDLG($output_handle, $input_text, $party_num);
        close($output_handle);
        return $rc;
    }

    # overview:
    # 1. read each block into its:
    #   * trigger list
    #   * response block1 ... blockN
    # 2. check which class of a problem the block represents
    # 3. fix it
    #
    # We're writing to the output handle as we go, so we don't need to reread
    # the original
    foreach my $block (@baf_blocks) {
        # nothing to do? Just write it out
        if ($block !~ /Player6/) {
            say $output_handle $block . "\n";
            next;
        }

        # now we know there is a mention of Player6, so let's dig deeper
        my $trigger_mention = 0;
        my $response_mention = 0;
        # safely strip out the contents
        my ($trigger_half) = ($block =~ /^IF\n((?:(?!^IF).)*)THEN$/ms);
        my ($response_half) = ($block =~ /^THEN\n((?:(?!^THEN).)*)END$/ms);

        # where are the uses?
        $trigger_mention++ if ($trigger_half =~ /Player6/);
        $response_mention++ if ($response_half =~ /Player6/);
        if ($trigger_mention == $response_mention && $trigger_mention == 0) {
            print $trigger_half . "||||\n" . $response_half . "\n\n";
            print "FATAL PARSING ERROR: player mention mismatch! Dumped problematic block above.\nAre you sure this is a script file?\n";
            exit;
        }

        my $no_write = 0;
        my @trigger_list = split /\n/, $trigger_half;
        # note the capture group - we need to preserve the weight
        my @response_blocks = split /(\s*RESPONSE .*\n)/m, $response_half;
        # remove first element; always empty due to the way $response_half is built
        shift @response_blocks;
        # for my $line (@response_blocks) { print "+$line-"; }

        # figure out what toplevel strategy to take
        if ($trigger_mention == $response_mention) {
            # both triggers and response blocks need to be changed
            # test5, test8-10 and others
            # we have at least 4 cases to handle:
            #   * append triggers + append actions: test27
            #   * append triggers + new response blocks: test28, 29
            #   * whole block copy (new trigger block + body append): test26
            #   * whole block copy (new trigger block + new response blocks): test5, 8, 25
            # use same "party vs individual" detection as elsewhere
            if ($trigger_half =~ /Player5/) {
                if ($response_half =~ /Player5/) {
                    $trigger_half = fixTriggersOnly($trigger_half, $party_num, @trigger_list);
                    $response_half = fixResponsesOnly($response_half, $party_num, @response_blocks);
                } else {
                    # test29 works, since it has separate response blocks
                    if ($#response_blocks > 1) {
                        $trigger_half = fixTriggersOnly($trigger_half, $party_num, @trigger_list);
                        $response_half = fixResponsesOnly($response_half, $party_num, @response_blocks);
                    } else {
                        # test28 has only one response block
                        $trigger_half = fixTriggersOnly($trigger_half, $party_num, @trigger_list);
                        fixResponses($output_handle, $trigger_half, $response_half, $party_num);
                        $no_write = 1;
                    }
                }
            } else {
                if ($response_half =~ /Player5/) {
                    # whole block copy (new trigger block + body append): test26
                    fixResponses2($output_handle, $trigger_half, $response_half, $party_num);
                } else {
                    # whole block copy (new trigger block + new response blocks): test5, 8, 25
                    fixResponses3($output_handle, $trigger_half, $response_half, $party_num);
                }
                $no_write = 1;
            }
        } elsif ($trigger_mention == 1) {
            # likely only triggers need to be changed
            $trigger_half = fixTriggers($trigger_half, $response_half, $output_handle, $party_num, 1, @trigger_list);
            $no_write = 1;
        } else {
            # likely only response blocks need to be changed
            # if (everyone) is mentioned append action(s) (tests: 4, 6, 7)
            if ($response_half =~ /Player5/) {
                # NOTE: for now assuming this is enough and that scripts work either on the whole party or individuals
                $response_half = fixResponsesOnly($response_half, $party_num, @response_blocks);
            } else {
                # else copy the whole block (test3)
                # write the current one
                writeBlock ($output_handle, $trigger_half, $response_half);

                # add copies for each extra party member
                my $prevPC = "Player6";
                for (my $i = 7; $i <= $party_num; $i++) {
                    my $nextPC = "Player" . $i;
                    $response_half = $response_half =~ s/^(\s*)(.*)($prevPC)(.*)$/$1$2$nextPC$4/gmr;
                    $prevPC = $nextPC;
                    writeBlock ($output_handle, $trigger_half, $response_half);
                }
                $no_write = 1;
            }
        }

        # final writeout of modified current block
        writeBlock ($output_handle, $trigger_half, $response_half) if not $no_write;
    }
    close($output_handle);
    return 1;
}

# whole block copy (new trigger block + new response blocks)
sub fixResponses3 {
    my $output_handle = shift;
    my $trigger_half = shift;
    my $response_half = shift;
    my $party_num = shift;

    # flush the original Player6 block
    writeBlock ($output_handle, $trigger_half, $response_half);

    my $old_trigger_half = $trigger_half;
    my $prevPC = "Player6";
    for (my $i = 7; $i <= $party_num; $i++) {
        my $nextPC = "Player" . $i;
        $trigger_half = $old_trigger_half =~ s/^(\s*)(.*)($prevPC)(.*)$/$1$2$nextPC$4/gmr;
        my $new_block = $response_half =~ s/^(\s*)(.*)($prevPC)(.*)$/$1$2$nextPC$4/gmr;
        writeBlock ($output_handle, $trigger_half, $new_block);
    }
}

# whole block copy (new trigger block + body append)
sub fixResponses2 {
    my $output_handle = shift;
    my $trigger_half = shift;
    my $response_half = shift;
    my $party_num = shift;

    my $old_block = $response_half;
    my $old_trigger_half = $trigger_half;
    for (my $i = 6; $i <= $party_num; $i++) {
        my $prevPC = "Player6";
        my $nextPC = "Player" . $i;
        $trigger_half = $old_trigger_half =~ s/^(\s*)(.*)($prevPC)(.*)$/$1$2$nextPC$4/gmr;
        my $new_block = $response_half;
        for (my $j = 7; $j <= $party_num; $j++) {
            $nextPC = "Player" . $j;
            $new_block = $new_block =~ s/^(\s*)(.*)($prevPC)(.*)$/$&\n$1$2$nextPC$4/gmr;
            $prevPC = $nextPC;
        }
        writeBlock ($output_handle, $trigger_half, $new_block);
    }
}

# single response block block that requires whole copies along with adapted triggers
sub fixResponses {
    my $output_handle = shift;
    my $trigger_half = shift;
    my $response_half = shift;
    my $party_num = shift;

    # flush the original Player6 block
    writeBlock ($output_handle, $trigger_half, $response_half);

    my $old_block = $response_half;
    my $prevPC = "Player6";
    #print "|$header::$block|";
    for (my $i = 7; $i <= $party_num; $i++) {
        my $nextPC = "Player" . $i;
        my $new_block = $old_block =~ s/^(\s*)(.*)($prevPC)(.*)$/$1$2$nextPC$4/gmr;
        writeBlock ($output_handle, $trigger_half, $new_block);
    }
}

# NOTE: for now we don't care about ordering (567 vs 765)
sub fixResponsesOnly {
    my $response_half = shift;
    my $party_num = shift;
    my @response_blocks = @_;

    # we have a party, add extra actions by copying Player6 lines and
    # potentially adding new RESPONSE BLOCKS
    # TODO: adjust weights (not that important & how would we know?)
    my $new_response_half = "";
    my @response_keys = keys @response_blocks;
    for my $key (@response_keys) {
        my $block = $response_blocks[$key];

        if ($block =~ /Player5/ and $block =~ /Player6/) {
            # block mentions everyone, just append
            my $prevPC = "Player6";
            for (my $i = 7; $i <= $party_num; $i++) {
                my $nextPC = "Player" . $i;
                $block = $block =~ s/^(\s*)(.*)($prevPC)(.*)$/$&\n$1$2$nextPC$4/gmr;
                $prevPC = $nextPC;
            }
        } elsif ($block =~ /Player6/) {
            # block mentions only last, append as new response block
            my $prevPC = "Player6";
            my $header = $response_blocks[$key-1]; # RESPONSE #100
            chomp $block;
            my $old_block = $block;
            #print "|$header|$block|";
            for (my $i = 7; $i <= $party_num; $i++) {
                my $nextPC = "Player" . $i;
                my $new_block = $old_block =~ s/^(\s*)(.*)($prevPC)(.*)$/$1$2$nextPC$4/gmr;
                $new_block = $header . $new_block;
                $block .=  $new_block;
            }
            #print ":$key:$#response_keys:";
            $block .= "\n" if $key == $#response_keys;
        }
        $new_response_half .= $block;# . "\n";
    }
    return $new_response_half;
}

# only triggers need to be changed
sub fixTriggers {
    my $trigger_half = shift;
    my $response_half = shift;
    my $output_handle = shift;
    my $party_num = shift;
    my $write = shift;
    my @trigger_list = @_;

    # if (everyone) is mentioned append trigger (test2)
    if ($trigger_half =~ /Player5/) {
        # NOTE: for now assuming this is enough and that scripts work either on the whole party or individuals
        $trigger_half = fixTriggersOnly($trigger_half, $party_num, @trigger_list);
        if ($write) {
            writeBlock ($output_handle, $trigger_half, $response_half);
        }
    } else {
        # else copy the whole block (test17)
        # write the current one
        if ($write) {
            writeBlock ($output_handle, $trigger_half, $response_half);
		}

        # add copies for each extra party member
        my $prevPC = "Player6";
        for (my $i = 7; $i <= $party_num; $i++) {
            my $nextPC = "Player" . $i;
            $trigger_half = $trigger_half =~ s/^(\s*)(.*)($prevPC)(.*)$/$1$2$nextPC$4/gmr;
            $prevPC = $nextPC;
            if ($write) {
                writeBlock ($output_handle, $trigger_half, $response_half)
			}
        }
    }
    return $trigger_half;
}

# NOTE: for now we don't care about ordering (567 vs 765)
sub fixTriggersOnly {
    my $trigger_half = shift;
    my $party_num = shift;
    my @trigger_list = @_;

    # we have a party, just add extra triggers by copying Player6 lines
    my $new_trigger_half = "";
    my $in_or = 0;
    for my $line (@trigger_list) {
        if ($line =~ /  OR\(/) {
            $in_or = 1;
            $new_trigger_half .= $line . "\n";
            next;
        } elsif ($line =~ /^\s\s\S/) {
            # OR causes extra indent (python style)
            $in_or = 0;
        }
        if ($line =~ /Player6/) {
            # adjust OR() if needed
            if ($in_or) {
                # FIXME: UGLY, perhaps just split on OR(.) and work on that?
                my $cur_pos = index $new_trigger_half, my $grr = $line =~ s/Player6/Player5/r;
                my $or_pos = rindex $new_trigger_half, " OR(", $cur_pos;
				if (index $new_trigger_half, " OR(", ($or_pos) > 0) {
				    $or_pos = index $new_trigger_half, " OR(", ($or_pos);
				}
#               print $new_trigger_half, "|\n" , $line, "\n";
#               print ((substr $new_trigger_half, $or_pos, 6), "||", $cur_pos, "||", $or_pos, "||\n");
                # we have to set the new count carefully in case there are other actions inside the Or: just add to existing
                my $old_count = (substr $new_trigger_half, $or_pos+4, 2) =~ s/(\d+).?/$1/r;
                my $new_count = $old_count + ($party_num - 6);
                substr $new_trigger_half, $or_pos, 5+(length $old_count), " OR($new_count)";
                #$in_or = 0; # one fix per Or block is only enough if there is only one Player6-using trigger ...
            }
            # add new triggers
            my $prevPC = "Player6";
            for (my $i = 7; $i <= $party_num; $i++) {
                my $nextPC = "Player" . $i;
                $line = $line =~ s/^(\s*)(.*)($prevPC)(.*)$/$1$2$3$4\n$1$2$nextPC$4/mr;
                $prevPC = $nextPC;
            }
        }
        $new_trigger_half .= $line . "\n";
    }
    return $new_trigger_half;
}

# don't forget to properly reconstruct the halves before use!
sub writeBlock {
    my $output_handle = shift;
    my $trigger_half = shift;
    my $response_half = shift;

    # HACK: NumInParty(6)
    $trigger_half = $trigger_half =~ s/(NumInParty)\(6\)/$1GT(5)/gmr;
    say $output_handle "IF\n" . $trigger_half . "THEN\n" . $response_half . "END\n";
}

sub extendDLG {
    my $output_handle = shift;
    my $dialog_string = shift;
    my $party_num = shift;

    $dialog_string = $dialog_string =~ s{^//.*\n}{}gmr;
    $dialog_string = $dialog_string =~ s{//.*}{}gr;
    # NOTE: weidu supports some extra forms, but hopefully all get replaced with this when compiling and decompiling or just affect the action part
    my @dlg_states = split(/^IF((?:(?!^END).)*)^END/ms, $dialog_string) or die "Couldn't split dialog: $!";

    # write out the header (BEGIN and any other noise)
    print $output_handle $dlg_states[0];
    shift @dlg_states;

#     require 'print_r.pl';
#     print_r(@dlg_states);

    foreach my $state (@dlg_states) {
        if ($state =~ /^\s*$/) {
            say $output_handle "";
            next;
        }
        if ($state !~ /\bPlayer6\b/ or $state !~ /\bPlayer5\b/) {
            $state = $state =~ s{/\*(?:(?!\*/).)*\*/}{}gsr; # see below
            say $output_handle "IF" . $state . "END";
            next;
        }

        # strip out /* */ comments (delimited by more ~) then split on ~
        # IF( [^~]*)? ~.*~ THEN .* (GOTO|EXIT|EXTERN).*$?
        $state = $state =~ s{/\*(?:(?!\*/).)*\*/}{}gsr;
        my $state2;
        my @transitions = split /(^\s*IF(?:(?:(?!(?:GOTO|EXIT|EXTERN)).)*)(?:GOTO|EXIT|EXTERN) *\w*\n?)/ms, $state;
        my $seenP5 = 0;
        # print_r(@transitions);
        foreach my $trans (@transitions) {
#             if ($trans =~ /^\s*$/) {
#                 next;
#             }

            # track player5 here for full transition copying
            # NOTE: assumes well-ordered dialog scripting
            if ($trans !~ /\bPlayer6\b/) {
                $state2 .= $trans;
                #$seenP5 = ($trans !~ /Player5/);
                if ($trans =~ /\bPlayer5\b/) {
                    $seenP5 = 1;
                } elsif ($trans =~ /\S/) {
                    $seenP5 = 0;
                }
                next;
            }

            if ($seenP5) {
                $state2 .= $trans;
                my $new_state = "";
                my $prevPC = "Player6";
                for (my $i = 7; $i <= $party_num; $i++) {
                    my $nextPC = "Player" . $i;
                    my $new_line = $trans =~ s/$prevPC/$nextPC/gr;
                    # also tick off tokens or bugs?
                    $new_line = $new_line =~ s/\U$prevPC\E/\U$nextPC\E/gr;
                    $new_state .= $new_line;
                }
                $state2 .= $new_state;
                next;
            }

            my @blocks = split /(~|\bIF\b)/, $trans;
#             print_r(@blocks);
#print "|@blocks|\n";

            $trans = $blocks[0]; # intro WEIGHT or nothing
            shift @blocks;
            #while ($blocks[0] =~ /^(~|IF||\s*THEN DO)\s*$/) {
            my $lastBoringField = 3;
            if ($blocks[3] =~ /^\s*$/) {
                $lastBoringField = 7;
            }
            for (my $z=1; $z <= $lastBoringField; $z++) {
                $trans .= $blocks[0];
                shift @blocks;
            }
#print "|$blocks[0]|\n";

            # now we're either at the triggers or actions
            if ($lastBoringField == 3) {
                # fix triggers + shift 4
                if ($blocks[0] =~ /\bPlayer6\b/) {
                    # preprocess block, so it looks similar to script blocks
                    if ($blocks[0] =~ /OR\(/) {
                        $blocks[0] = $blocks[0] =~ s/OR\(/  OR(/gr;
                    }
                    $blocks[0] = fixTriggers($blocks[0], $blocks[2], $output_handle, $party_num, 0, split(/\n/, $blocks[0]));
                    # restore whitespace used for OR detection
                    $blocks[0] = $blocks[0] =~ s/  //gr;
                }
                for (my $z=1; $z <= 4; $z++) {
                     if ($#blocks >= 0) {
                        $trans .= $blocks[0];
                        shift @blocks;
                     }
                }
            }

            if ($#blocks < 1) {
                $state2 .= $trans;
                next;
            }

            # fix the actions
# print "|$blocks[0]|\n";
            if ($blocks[0] =~ /\bPlayer6\b/) {
                $blocks[0] = fixTriggers($blocks[0], $blocks[2], $output_handle, $party_num, 0, split(/\n/, $blocks[0]));
            }
#             print $blocks[0];
            for (my $z=0; $z < 3; $z++) {
                    if ($#blocks >= 0) {
                        $trans .= $blocks[0];
                        shift @blocks;
                    }
            }
            $state2 .= $trans ;
        }
        say $output_handle "IF" . $state2 . "END";
        $state2 = "";
    }
    return 1;
}

#exit 0;
1
