#!/usr/bin/perl 2.4 -w
$DEBUG = 0;

our @indents = ();
our $indent_space = "  ";
our $indent_space_init_already = 0;
our @arrayVars = ();

# check whether statement is array
# 1 means yes, 0 means no
sub isStatementArray {
    my $line = shift;
    if ($line =~ /^\s*sys\.stdin\.readlines?\((.*)\)\s*$/ ) {
        #sys,stdin.readlines
        return 1;
    } elsif ($line =~ /^\s*\[(.*)\]\s*$/ ) {
        #[]
        return 1;
    } elsif ($line =~ /^\s*(.*)\.\s*split\s*\((.*)\)\s*$/ ) {
        return 1;
    }

    return 0;
}

sub isVariableArray {
    my $line = shift;
    if ($line ~~ @arrayVars) {
        return 1;
    } else {
        return 0;
    }
}

sub isPrintfFormat {
    my $line = shift;
    if ($line =~ /^\s*"(.*)"\s*%\s*(.*)$/) {
        return 1;
    } else {
        return 0;
    }
}

sub convertVariable {
    my $line = shift;

    if ($line =~ /^\s*int\((.*)\)\s*$/ ) {
        # convert int()
        return convertVariable($1);
    } elsif ($line =~ /^\s*sys\.stdin\.readline[s]?\((.*)\)\s*$/ ) {
        # sys.stdin.readline
        return "<STDIN>";
    } elsif ($line =~ /^\s*sys\.stdin\s*$/) {
        # sys.stdin
        return "(<STDIN>)";
    } elsif ( $line =~ /^\s*sys\.stdout\.write\((.*)\)\s*$/ ) {
        # sys.stdout.write
        return "print " . convertVariable($1);
    } elsif ( $line =~ /^\s*sys\s*\.\s*argv\s*$/ ) {
        # sys.argv
        return "\@ARGV";
    } elsif ( $line =~ /^\s*sys\.exit\s*\((.*)\)\s*$/ ) {
        # sys.exit
        return "exit ".convertVariable(trim($1));
    } elsif ( $line =~ /^\s*range\s*\((.*),(.*)\)\s*$/ ) {
        # range(0,5) to (1..4)
        return "(". convertVariable(trim($1)) . " .. " .
                convertVariable(trim($2)) . "-1)";
    } elsif ( $line =~ /^\s*range\s*\((.*)\)\s*$/ ) {
        # range(10) to (0..9)
        return "(0 .. " . convertVariable(trim($1)) . "-1)";
    } elsif ($line =~ /^\s*"(.*)"\s*%\s*(.*)$/) {
        #printf format string
        return "\"$1\" , (" . convertVariable($2) . ")";
    } elsif ($line =~ /^\s*\[(.*)\]\s*$/) {
        # convert [] into ()
        return "(" . convertVariable($1) .")";
    } elsif ($line =~ /^\s*(.*)\.(index)\((.*)\)\s*$/) {
        # list.index('a') --> grep{ $_ if $a[$_] == 'a' } 0..$#a
        my $array_var = $1;
        my $keyword = $2;
        my $var = trim($3);
        unshift (@arrayVars, $array_var);

        my $cmp = "eq";
        if ($var =~ /^\s*\d+\s*$/){
            $cmp = "=="
        }

        return "(grep { \$_ if \$" .$array_var. "[\$_] " . $cmp . " " . $var .
            " } 0..(scalar(\@$array_var)-1))[0]";
    } 

    elsif ( $line =~ /^\s*(.+)\.\s*join\s*\((.*)\)\s*$/){
        return "join(" 
            . convertVariable( trim($1), 0 ) . ","
            . convertVariable( trim($2), 1 ) . ")";
    }

    elsif ( $line =~ /^\s*(.*)\.\s*split\s*\((.*)\)\s*$/ ) {
        my $var = $2;
        if ( $2 eq "" ) {
            $var = " ";
        }

        my $new_var = convertVariable(trim($var));
        return
            "split /"
          . substr( $new_var, 1, length($new_var) - 2 ) . "/,"
          . "\$$1";
    }

    elsif ( $line =~ /^\s*sys\s*\.\s*argv\s*$/ ) {
        # sys.argv
        return "\@ARGV";
    } elsif ($line =~ /^\s*sys\s*\.\s*argv\s*\[\s*(.*)\s*:\s*(.*)\]\s*$/ ) {
        #print "\@ARGV";
        my $start = trim($1);
        my $to = trim($2);
        
        if($start =~ /^\s*1\s*$/ && $to =~ /^\s*$/){
            return "\@ARGV";
        } else {
            return "\@ARGV[(" . convertVariable($start) . "-1)..(" . convertVariable($to) . "-2)]";
        }
    } elsif ( $line =~ /^\s*sys\s*\.\s*argv\s*\[\s*(.*)\s*\]\s*$/ ) {
        # sys.argv[1]
        #       print "\$ARGV[";
        #       print printChunkedPart($variable);
        #       print "]";
        my $var = $1;
        
        if(trim($var) eq "0"){
            return "\$0";
        } else {
            return "\$ARGV[" . convertVariable($var)  . "-1]";
        }
    }

    # don't convert string
    # TODO haven't handle multiple string case
    if ($line =~ /^\s*"(.*)"\s*$/){
        return $line;
    }

    # convert variable, prepend $
    $line =~ s/([a-zA-Z_][a-zA-Z_0-9]*)/\$$1/g;
    # remove prepend $ for function
    $line =~ s/\$([a-zA-Z_][a-zA-Z_0-9]*\()/$1/g;
    # remove %$variable case inside ""
    $line =~ s/"(.*)%\$([a-zA-Z_][a-zA-Z_0-9]*)/"$1%$2/g;


    # get all $ variable, check whether they are array or not
    @var = $line =~ /\$([a-zA-Z_][a-zA-Z_0-9]*)/;
    # convert array varible's name from $ to @
    foreach (@var) {
        if (isVariableArray($_)){
            $line =~ s/\$$_/\@$_/g;
        }
    }

    # convert @array[i] into $array[i]
    $line =~ s/\@([a-zA-Z_][a-zA-Z_0-9]*\[)/\$$1/g;
    # convert 'not' 'or' 'and' back to normal
    $line =~ s/\$(not|or|and\s)/$1/g;


    # try translate function len()
    if ($line =~ /^(.*)len\((.*)\)(.*)$/) {
        my $left = $1;
        my $middle = trim($2);
        my $right = $3;

        if ($middle =~ /^\$/) {
            $line = $left. "length($middle)" . $right;
        } elsif ($middle =~ /^\@/) {
            $line = $left. "scalar($middle)" . $right;
        }
    }

    return $line;
}

sub trim { #???
    my $line = shift;
    $line =~ s/^\s*(.*)\s*$/$1/g;
    return $line;
}

sub translateLine {
    #my ($line) = @_;

    #obtain parameter
    my $line = shift;
    my $output_line = "";
    my $current_space = ""; #keep track of #space in front of each line
    # deal with indents
    if ($line !~ /^\s*#/ && $line !~ /^\s*$/){
            print "I am in line 30\n" if $DEBUG;
        if($line =~ /^(\s*).*/){ #for holding space before the line??
            print "I am in line 31\n" if $DEBUG;
            $current_space = $1;
            if (scalar(@indents) == 0) {
                print "I am in line 34\n" if $DEBUG;
                # init indents array
                unshift (@indents, $current_space);
            } else {
                print "I am in line 38\n" if $DEBUG;
                my $prev_space = $indents[0];
                if (length($current_space) > length($prev_space)) { #check if next line a new loop or ifels??
                    print "I am in line 41\n" if $DEBUG;
                    unshift (@indents, $current_space);
                    # init global indent space
                    if ($indent_space_init_already == 0){ #??????
                        print "I am in line 45\n" if $DEBUG;
                        $indent_space = $current_space;
                        $indent_space_init_already = 1;
                    }
                } else {
                    print "I am in line 50\n" if $DEBUG;
                    while (length($current_space) < length($indents[0])) {
                        #if curr space less than prev space (@indents)
                        #close bracket when it's ending of a loop or if,elif,else condition
                        print "I am in line 52\n" if $DEBUG;
                        shift(@indents);
                        print "}\n"; 
                    }
                }
            }
        }
    }


    if ($line =~ /^#!/ && $. == 1) {
        # translate #! line , $. line # of curr line
        $output_line = "#!/usr/bin/perl -w\n";

    } elsif ($line =~ /^\s*#/ || $line =~ /^\s*$/) {
        # Blank, comment lines unchanged
        $output_line = $line;

    } elsif ($line =~ /^\s*\bbreak\b\s*$/) {
        # break
        $output_line = "$current_space"."last;". "\n";

    } elsif ($line =~ /^\s*\bcontinue\b\s*$/) { 
        #continue
        $output_line = "$current_space"."next;". "\n";

    } elsif ($line =~ /^\s*\b(if|while|elif)\b\s*(.*)\s*:\s*$/) {
        # if/while multiple line mode
        my $keyword = $1 eq 'elif' ? 'elsif' : $1;
        $output_line = "$current_space" . "$keyword \(".convertVariable($2)."\) {\n";
    
    } elsif ($line =~ /^\s*\b(if|while|elif)\b\s*(.*)\s*:\s*(.*)\s*$/) {
      
        # if/while one line mode
        # print "I am in line 59 "."$2\n" if $DEBUG;
        my $keyword = $1 eq 'elif' ? 'elsif' : $1;
        $output_line = "$current_space" . "$keyword \(".convertVariable($2)."\) {\n" .
                translateLine($current_space . $indent_space . $3). translateLine($current_space);
    } elsif ($line =~ /^\s*\b(else)\b\s*:\s*$/) {
      
        # else in multiple line
        $output_line = "$current_space" . "$1 {\n";    
    } elsif ($line =~ /^\s*\b(else)\b\s*:\s*(.*)\s*$/) {
      
        # else in one line
        $output_line = "$current_space" . "$1 {\n".translateLine($current_space . $indent_space . $3) .
        translateLine($current_space);
    
    } elsif ($line =~ /^\s*for\s+(.*)\s+in\s+(.*)\s*:\s*$/) {
      
        # for loop multiple line
        $output_line = "$current_space" . "foreach ".convertVariable($1)." ".convertVariable($2)." { \n";

    } elsif ($line =~ /^\s*for\s+(.*)\s+in\s+(.*)\s*:\s*(.*)\s*$/) {
      
        # for loop single line
        $output_line = "$current_space" . "foreach ".convertVariable($1)." ".convertVariable($2)." { \n";
        $output_line .= translateLine($current_space . $indent_space . $3);

    } elsif ($line =~ /^\s*.*;\s*.*$/){
        # if line contians ';', then split them into multiple lines
        @lines = split(';', $line);
        foreach (@lines){
            # print "---$current_space---";
            my $result = translateLine("$current_space" . trim($_));
            $output_line .= $result;
        }

    } elsif ($line =~ /^\s*print\s*"(.*)"\s*$/) {
        # Python's "print" print a new-line character by default
        # so we need to add it explicitly to the Perl print statement
        
        #single quote???

        #double quote case
        #print string
        $output_line = "$current_space" . "print \"$1\\n\";\n";

    } elsif ($line =~ /^\s*print\s*(.*)\s*$/) {
        my $content = $1;
        my $print_new_line = 1;
        if ($content =~ /,\s*$/) {
            $print_new_line = 0;
            $content =~ s/(.*),\s*$/$1/g;
        }
        # print variable
        if (isPrintfFormat($content)){
            $output_line = "$current_space" . "printf ". convertVariable($content)  .";\n";
            if (print_new_line) {
                $output_line .= "$current_space" . "print \"\\n\";\n";
            }
        } else {
            my $new_line = convertVariable($content);
            if ($new_line eq "") {
                $output_line = "$current_space" . "print \"\\n\";\n";
            } else {
                if ($print_new_line == 1) {
                    $output_line = "$current_space" . "print ". convertVariable($content) . ", \"\\n\";\n";
                } else {
                    $output_line = "$current_space" . "print ". convertVariable($content) . " ;\n";
                }
            }
        }
    
    } elsif ($line =~ /^\s*(.*)\.(append)\((.*)\)\s*$/) {
        # list.append
        my $array_var = $1;
        my $keyword = $2;
        my $var = $3;
        unshift (@arrayVars, $array_var);
        $output_line = $current_space . "$keyword \@$1, ". convertVariable($var) . ";\n";

    } elsif ($line =~ /^\s*(.*)\.(pop)\((.*)\)\s*$/) {
        # list.pop
        my $array_var = $1;
        my $keyword = $2;
        my $var = trim($3);
        unshift (@arrayVars, $array_var);
        if ($var =~ /^\s*$/) {
            $output_line = $current_space . "$keyword \@$array_var ;\n";
        } else {
            $output_line = $current_space . "splice \@$array_var, " . convertVariable($var) . ", 1;\n" 
        }

    } elsif ($line =~ /^\s*([a-zA-Z_][a-zA-Z_0-9]*)\s*=\s*(.*)\s*$/){
        # simple variable INITIALIZATION
        #e.g. answer = 42

        # number = int(sys.stdin.readline()) will come in...
        # variable = 5 + function + function + 5 +6... come in???
        my $isArray = isStatementArray($2);
        my $variable = $1;
        if ($isArray == 1) {
             unshift (@arrayVars, $variable);
             $variable = "\@".$variable;
        } else {
            $variable = "\$".$variable;
        }

        $output_line = "$current_space" . "$variable = ".convertVariable($2).";\n";
    } 


    elsif ($line =~ /^\s*\bimport\b\s*.*$/) {
        #get rid of import
        $output_line = '',"\n";
    }

    else {
        # try to convert variable inside
        $output_line = $current_space . convertVariable($line);
        # Lines we can't translate are turned into comments
        if ($output_line eq $line) {
            $output_line = "#$line\n";
        } else {
            $output_line .= ";\n";
        }
    }

    return $output_line;
}

# main 
while ($line = <>) {
    print translateLine($line);
    # translateLine($line);
} 

# after file END, check how many '}' need to print
while (scalar(@indents) != 1 ) {
    shift @indents;
    print "}\n";
}





