#------------------------------------------------------------------------------
# File:         Plot.pm
#
# Description:  Plot tag values in SVG format
#
# Revisions:    2025-02-14 - P. Harvey Created
#------------------------------------------------------------------------------

package Image::ExifTool::Plot;

use strict;
use vars qw($VERSION);

$VERSION = '1.05';

# default plot settings (lower-case settings may be overridden by the user)
my %defaults = (
    size   => [ 800, 600 ],        # width,height of output image
    margin => [ 60, 15, 15, 30 ],  # left,top,right,bottom margins around plot area
    legend => [ 0, 0 ],            # top,right offset for legend
    txtpad => [ 10, 10 ],          # padding between text and x,y scale
    linespacing => 20,             # text line spacing
    # colours for plot lines
    cols   => [ qw(red green blue black orange gray fuchsia brown turquoise gold
                   lime violet maroon aqua navy pink olive indigo silver teal) ],
    marks  => [ qw(circle square triangle diamond star plus pentagon left down right) ],
    stroke => 1,                   # stroke width and marker scaling
    grid   => 'darkgray',          # grid colour
    text   => 'black',             # text and plot frame colour
    type   => 'line',              # plot type, 'line' or 'scatter'
    style  => '',                  # 'line', 'marker' or 'line+marker'
    xlabel => '',                  # x axis label
    ylabel => '',                  # y axis label
    title  => '',                  # plot title
    nbins  => 20,                  # number of histogram bins
    # xmin, xmax                   # x axis minimum,maximum
    # ymin, ymax                   # y axis minimum,maximum
    # split                        # split list of numbers into separate plot lines
    # bkg                          # background colour
    # multi                        # flag to make one plot per dataset
#
# members containing capital letters are used internally
#
    Data   => { },                 # data arrays for each variable
    Name   => [ ],                 # variable names
    # XMin, XMax                   # min/max data index
    # YMin, YMax                   # min/max data value
    # SaveName, Save               # saved variables between plots
);

my %markerData = (
    circle   => '<circle cx="4" cy="4" r="2.667"',
    square   => '<path d="M1.667 1.667 l4.667 0 0 4.667 -4.667 0 z"',
    triangle => '<path d="M4 0.8 l2.667 5.333 -5.333 0 z"',
    diamond  => '<path d="M4 1 l3 3 -3 3 -3 -3 z"',
    star     => '<path d="M4 0.8 L5 2.625 7.043 3.011 5.617 4.525 5.881 6.589 4 5.7 2.119 6.589 2.383 4.525 0.957 3.011 3 2.625 z"',
    plus     => '<path d="M2.75 1 l2.5 0 0 1.75 1.75 0 0 2.5 -1.75 0 0 1.75 -2.5 0 0 -1.75 -1.75 0 0 -2.5 1.75 0 z"',
    pentagon => '<path d="M4 1 L6.853 3.073 5.763 6.427 2.237 6.427 1.147 3.073 z"',
    left     => '<path d="M0.8 4 l5.333 2.667 0 -5.333 z"',
    down     => '<path d="M4 7.2 l2.667 -5.333 -5.333 0 z"',
    right    => '<path d="M7.2 4 l-5.333 2.667 0 -5.333 z"',
);

my @ng = (20, 15);  # optimal number grid lines in X and Y for a 800x600 plot
my $wch = 8;        # nominal width of a character (measured at 7.92)

#------------------------------------------------------------------------------
# Create new plot object
sub new
{
    my $that = shift;
    my $class = ref($that) || $that || 'Image::ExifTool::Plot';
    my $self = bless { }, $class;
    foreach (keys %defaults) {
        ref $defaults{$_} eq 'HASH' and $$self{$_} = { %{$defaults{$_}} }, next;
        ref $defaults{$_} eq 'ARRAY' and $$self{$_} = [ @{$defaults{$_}} ], next;
        $$self{$_} = $defaults{$_};
    }
    return $self;
}

#------------------------------------------------------------------------------
# Set plot settings
# Inputs: 0) Plot ref, 1) comma-separated options
sub Settings($$)
{
    my ($self, $set) = @_;
    return unless $set;
    foreach (split /,\s*/, $set) {
        next unless /^([a-z].*?)(=(.*))?$/i;
        my ($name, $val) = (lc $1, $3);
        if (ref $$self{$name} eq 'ARRAY') {
            next unless defined $val;
            my $isNum = $$self{$name}[0] =~ /^\d+$/;
            # also allow numbers to also be separated by 'x'
            my @vals = $isNum ? split(/\s*[x\s\/+]\s*/, $val) : split(/\s*[\s\/+]\s*/, $val);
            my $i;
            for ($i=0; @vals; ++$i) {
                my $val = lc shift @vals;
                next unless length $val;
                if ($name eq 'marks') {
                    my @v = split /-/, $val;
                    if ($v[0]) {
                        if ($v[0] =~ /^n/) {
                            $v[0] = 'none';
                        } else {
                            ($v[0]) = grep /^$v[0]/, @{$defaults{marks}};
                            $v[0] or $$self{Warn} = 'Invalid marker name', next;
                        }
                    } else {
                        # cycle through default markers if none specified
                        $v[0] = $defaults{marks}[$i % @{$defaults{marks}}];
                    }
                    $val = join '-', @v;
                }
                $$self{$name}[$i] = $val;
            }
        } else {
            $val = 1 unless defined $val;   # default to 1 if no "="
            my %charName = ('&'=>'amp', '<'=>'lt', '>'=>'gt');
            # escape necessary XML characters, but allow numerical entities
            $val =~ s/([&><])/&$charName{$1};/sg and $val =~ s/&amp;(#(\d+|x[0-9a-fA-F]+);)/&$1/;
            undef $val unless length $val;
            $$self{$name} = $val;
        }
    }
}

#------------------------------------------------------------------------------
# Add points to SVG plot
# Inputs: 0) Plot object ref, 1) tag value hash ref, 2) tag ID list ref
sub AddPoints($$$)
{
    my ($self, $info, $tags) = @_;
    my ($tag, $name, %num, $index, $mod, $val, @vals);
    my ($ee, $docNum, $data, $xmin, $xmax) = @$self{qw(EE DocNum Data XMin XMax)};
    $$self{type} or $$self{type} = 'line';
    my $scat = $$self{type} =~ /^s/ ? 1 : 0;
    my $xname = $$self{Name}[0];    # (x-axis name if using scatter plot)
    my $maxLines = ($$self{type} =~ /^h/ and not $$self{multi}) ? 1 : 20;
    for (;;) {
        if (@vals) {
            $val = shift @vals;
            next unless $val =~ /^[+-]?(?=\.?\d)\d*\.?\d*(?:e[+-]?\d+)?$/;
        } else {
            $tag = shift @$tags or last;
            # ignore non-floating-point values
            $val = $$info{$tag};
            ($name) = $tag =~ /^(\S+)/g;    # remove index number
            if (ref $val) {
                if (ref $val eq 'ARRAY') {
                    $index = defined $index ? $index + 1 : 0;
                    $val = $$val[$index];
                    defined $val or undef($index), undef($mod), next;
                    $name .= $mod ? '['.($index % $mod).']' : "[$index]";
                    unshift @$tags, $tag;   # will continue with this tag later
                } elsif (ref $val eq 'SCALAR') {
                    $val = $$val;   # handle binary values
                } else {
                    next;
                }
            }
        }
        next unless defined $val and $val =~ /^[+-]?(?=\.?\d)\d*\.?\d*(?:e[+-]?\d+)?([ ,;\t\n\r]+|$)/i;
        if ($1) {
            # split a string of numbers into separate plot points (eg. histogram tags)
            if ($$self{'split'}) {
                # make an array
                $$info{$tag} = [ split /[ ,;\t\n\r][\n\r]? */, $val ];
                unshift @$tags, $tag;
                # split into lists of 'split' elements if split > 1
                $mod = $$self{'split'} if $$self{'split'} > 1;
                next;
            } else {
                @vals = split /[ ,;\t\n\r][\n\r]? */, $val;
                $val = shift @vals;
            }
        }
        my $docNum = $docNum ? $$docNum{$tag} || 0 : 0;
        next if $docNum and not $ee;
        unless ($$data{$name}) {
            if (@{$$self{Name}} >= $maxLines + $scat) {
                unless ($$self{MaxTags}) {
                    if ($$self{type} =~ /^h/ and not $$self{multi}) {
                        $$self{Warn} = 'Use the Multi setting to make a separate histogram for each dataset';
                    } else {
                        $$self{Warn} = 'Too many variables to plot all of them';
                    }
                    $$self{MaxTags} = 1;
                }
                next;
            }
            push @{$$self{Name}}, $name;
            $xname or $xname = $name;   # x-axis data for scatter plot
            unless ($scat and $name eq $xname) {
                $$self{Max} = $val if not defined $$self{Max} or $val > $$self{Max};
                $$self{Min} = $val if not defined $$self{Min} or $val < $$self{Min};
            }
            $xmin = $xmax = $docNum unless defined $xmin;
            $num{$name} = $xmax;
            $$data{$name}[$xmax - $xmin] = $val if $xmax >= $xmin;
            next;
        }
        if ($docNum and defined $num{$name} and $num{$name} < $docNum) {
            $num{$name} = $docNum; # keep documents synchronized if some tags are missing
        } else {
            $num{$name} = $xmax unless defined $num{$name};
            ++$num{$name};
        }
        $$data{$name}[$num{$name} - $xmin] = $val if $num{$name} >= $xmin;
        unless ($scat and $name eq $xname) {
            $$self{Max} = $val if $val > $$self{Max};
            $$self{Min} = $val if $val < $$self{Min};
        }
    }
    # start next file at x value so far
    $xmax < $num{$_} and $xmax = $num{$_} foreach keys %num;
    $$self{XMin} = $xmin;
    $$self{XMax} = $xmax;
}

#------------------------------------------------------------------------------
# Calculate a nice round number for grid spacing
# Inputs: 0) nominal spacing (must be positive), 1) flag to increment to next number
# Returns: spacing rounded to an even number
sub GetGridSpacing($;$)
{
    my ($nom, $inc) = @_;
    my ($rounded, $spc);
    my $div = sprintf('%.3e', $nom);
    my $num = substr($div, 0, 1);
    my $exp = $div =~ s/.*e// ? $div : 0;
    if ($inc) {
        # increment to next highest even number
        $num = $num < 2 ? 2 : ($num < 5 ? 5 : (++$exp, 1));
    } else {
        # look for nearest factor to 1, 2 or 5 * 10^x
        $num = $num < 8 ? 5 : (++$exp, 1) if $num > 2;
    }
    return $exp >= 0 ? $num . ('0' x $exp) : '.' . ('0' x (-$exp - 1)) . $num;
}

#------------------------------------------------------------------------------
# Get plot range
# Inputs: 0) minimum, 1) maximum
# Returns: difference
# Notes: Adjusts min/max if necessary to make difference positive
sub GetRange($$)
{
    if ($_[0] >= $_[1]) {
        $_[0] = ($_[0] + $_[1]) / 2;
        $_[0] -= 0.5 if $_[0];
        $_[1] = $_[0] + 1;
    }
    return $_[1] - $_[0];
}

#------------------------------------------------------------------------------
# Draw SVG plot
# Inputs: 0) Plot ref, 1) Output file reference
sub Draw($$)
{
    my ($self, $fp) = @_;
    my ($min, $max, $xmin, $xmax, $name, $style) = @$self{qw(Min Max XMin XMax Name style)};
    my ($plotNum, $multiMulti);

    if (not defined $min or not defined $xmin) {
        $$self{Error} = 'Nothing to plot';
        return;
    }
    my $scat = $$self{type} =~ /^s/ ? 1 : 0;
    my $hist = $$self{type} =~ /^h/ ? [ ] : 0;
    my $multi = $$self{multi} || 0;
    my @multi = $multi =~ /\d+/g;
    my @names = @$name;
    shift @names if $scat;
    $multi = shift @multi;
    $multi = 0 unless $multi > 0;
    $style or $style = $hist ? 'line+fill' : 'line';
    unless ($style =~ /\b[mpl]/ or ($hist and $style =~ /\bf/)) {
        $$self{Error} = 'Invalid plot Style setting';
        return;
    }
    my $numPlots = 0;
    if ($multi) {
        my $n;
        for ($n=0; $n<scalar(@$name)-$scat; ++$numPlots) {
            $n += ($multi[$numPlots] || 1);
            $multiMulti = 1 if $multi[$numPlots] and $multi[$numPlots] > 1;
        }
    } else {
        $numPlots = 1;
    }
    my @size = @{$$self{size}};
    my $sy = $size[1];
    if ($multi) {
        $sy *= int(($numPlots + $multi - 1) / $multi) / $multi;
        $_ /= $multi foreach @size;
    }
    my $tmp = $$self{title} || "Plot by ExifTool $Image::ExifTool::VERSION";
    print $fp qq{<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20010904//EN" "http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="$$self{size}[0]" height="$sy"
 preserveAspectRatio="xMidYMid meet" viewBox="0 0 $$self{size}[0] $sy">
<title>$tmp</title>};
  # loop through all plots
  for ($plotNum=0; $plotNum<$numPlots; ++$plotNum) {
    my ($i, $n, %col, %class, $dx, $dy, $dx2, $xAxis, $x, $y, $px, $py, @og);
    my ($noLegend, $xname, $xdat, $xdiff, $diff, %markID);
    if ($numPlots > 1) {
        print $fp "\n<g transform='translate(", ($plotNum % $multi) * $size[0],
                  ',', int($plotNum/$multi) * $size[1], ")'>";
        if ($plotNum) {
            @$self{qw(XMin XMax title xlabel ylabel)} = @{$$self{Save}};
        } else {
            $$self{Save} = [ @$self{qw(XMin XMax title xlabel ylabel)} ];
            $$self{SaveName} = [ @{$$self{Name}} ];
        }
        $name = $$self{Name} = [ ];
        push @{$$self{Name}}, $$self{SaveName}[0] if $scat;
        foreach (0 .. (($multi[$plotNum] || 1) - 1)) {
            push @{$$self{Name}}, shift(@names);
        }
        undef $min; undef $max;
        foreach ($scat .. (@{$$self{Name}} - 1)) {
            my $dat = $$self{Data}{$$self{Name}[$_]};
            foreach (@$dat) {
                defined or next;
                defined $min or $min = $max = $_, next;
                $min > $_ and $min = $_;
                $max < $_ and $max = $_;
            }
        }
    }
    my ($data, $title, $xlabel, $ylabel, $cols, $marks, $tpad, $wid) =
        @$self{qw(Data title xlabel ylabel cols marks txtpad stroke)};
    my @name = @$name;
    my @margin = ( @{$$self{margin}} );

    # set reasonable default titles and labels
    $xname = shift @name if $scat;
    $title = "$name[0] vs $xname" if $scat and defined $title and not $title and @name == 1 and not $multi;
    if ($scat || $hist and defined $xlabel and not $xlabel) {
        $xlabel = $$name[0];
        $noLegend = 1 if $hist;
    }
    if (defined $ylabel and not $ylabel and @name == 1 and not $multiMulti) {
        $ylabel = $hist ? 'Count' : $name[0];
        $noLegend = 1 unless $hist;
    }

    # make room for title/labels
    $margin[1] += $$self{linespacing} * 1.5 if $title;
    $margin[3] += $$self{linespacing} if $xlabel;
    $margin[0] += $$self{linespacing} if $ylabel;

    # calculate optimal number of X/Y grid lines
    for ($i=0; $i<2; ++$i) {
        $og[$i] = $ng[$i] * ($size[$i] - $margin[$i] - $margin[$i+2]) /
                     ($defaults{size}[$i] - $defaults{margin}[$i] - $defaults{margin}[$i+2]);
        $og[$i] <= 0 and $$self{Error} = 'Invalid plot size', return;
    }
    if ($scat) {
        $xdat = $$self{Data}{$xname};
        unless (defined $$self{xmin} and defined $$self{xmax}) {
            my $set;
            foreach (@$xdat) {
                next unless defined;
                $set or $xmin = $xmax = $_, $set = 1, next;
                $xmin = $_ if $xmin > $_;
                $xmax = $_ if $xmax < $_;
            }
            my $dnx2 = ($xmax - $xmin) / ($og[0] * 2);
            # leave a bit of a left/right margin, but don't pass 0
            $xmin = ($xmin >= 0 and  $xmin < $dnx2) ? 0 : $xmin - $dnx2;
            $xmax = ($xmax <= 0 and -$xmax < $dnx2) ? 0 : $xmax + $dnx2;
        }
        $xmin = $$self{xmin} if defined $$self{xmin};
        $xmax = $$self{xmax} if defined $$self{xmax};
    } else {
        # shift x range to correspond with index in data list
        $xmax -= $xmin;
        $xmin = 0;
    }
    if ($hist) {
        $$self{nbins} > 0 or $$self{Error} = 'Invalid number of histogram bins', return;
        $noLegend = 1;
        # y axis becomes histogram x axis after binning
        $min = $$self{xmin} if defined $$self{xmin};
        $max = $$self{xmax} if defined $$self{xmax};
    } else {
        # leave a bit of a margin above/below data when autoscaling but don't pass 0
        my $dny2 = ($max - $min) / ($og[1] * 2);
        $min = ($min >= 0 and  $min < $dny2) ? 0 : $min - $dny2;
        $max = ($max <= 0 and -$max < $dny2) ? 0 : $max + $dny2;
        # adjust to user-defined range if specified
        $min = $$self{ymin} if defined $$self{ymin};
        $max = $$self{ymax} if defined $$self{ymax};
    }
    # generate random colors if we need more
    while (@$cols < @$name) {
        $$self{seeded} or srand(141), $$self{seeded} = 1;
        push @$cols, sprintf("#%.2x%.2x%.2x",int(rand(220)),int(rand(220)),int(rand(220)));
    }
    $diff = GetRange($min, $max);
    $xdiff = GetRange($xmin, $xmax);

    # determine y grid spacing (nice even numbers)
    $dy = GetGridSpacing($diff / ($hist ? $$self{nbins} : $og[1]));
    # expand plot min/max to the nearest even multiple of our grid spacing
    $min = ($min > 0 ? int($min/$dy) : int($min/$dy-0.9999)) * $dy;
    $max = ($max > 0 ? int($max/$dy+0.9999) : int($max/$dy)) * $dy;

    # bin histogram
    if ($hist) {
        my $dat = $$data{$name[0]};
        my $nmax = int(($max - $min) / $dy + 0.5);
        @$hist = (0) x $nmax;
        foreach (@$dat) {
            next unless defined;
            $n = ($_ - $min) / $dy;
            next if $n < 0 or $n > $nmax + 0.00001;
            $n = int($n);
            ++$$hist[$n < $nmax ? $n : $nmax - 1];
        }
        ($xmin, $xmax, $min, $max) = ($min, $max, 0, 0);
        if ($$self{ymax}) {
            $max = $$self{ymax};
        } else {
            $max < $_ and $max = $_ foreach @$hist;   # find max count
        }
        $diff = GetRange($min, $max);
        $dx = $dy;
        $dy = GetGridSpacing($diff / $og[1]);
        $max = ($max > 0 ? int($max/$dy+0.9999) : int($max/$dy)) * $dy;
        $$data{$name[0]} = $hist;
    } else {
        $dx = GetGridSpacing($xdiff / $og[0]);
    }
    if ($scat) {
        $xmin = ($xmin > 0 ? int($xmin/$dx) : int($xmin/$dx-0.9999)) * $dx;
        $xmax = ($xmax > 0 ? int($xmax/$dx+0.9999) : int($xmax/$dx)) * $dx;
    }
    $diff = GetRange($min, $max);
    $xdiff = GetRange($xmin, $xmax);
    # width/height of plot area
    my $width  = $size[0] - $margin[0] - $margin[2];
    my $height = $size[1] - $margin[1] - $margin[3];
    my $yscl = $height / $diff;
    my $xscl = $width / $xdiff;
    my $px0 = $margin[0] - $xmin * $xscl;
    my $py0 = $margin[1] + $height + $min * $yscl;
    my @clip = ($margin[0]-6*$wid, $margin[1]-6*$wid, $width+12*$wid, $height+12*$wid);
    print $fp "\n<!-- Definitions -->\n<defs>\n<clipPath id='plot-area'>";
    print $fp "<rect x='$clip[0]' y='$clip[1]' width='$clip[2]' height='$clip[3]'/></clipPath>";
    if ($style =~ /\b[mp]/) { # 'm' for 'marker' or 'p' for 'point' (undocumented)
        for ($i=0; $i<@name; ++$i) {
            my @m = split /-/, ($$marks[$i] || $defaults{marks}[$i % @{$defaults{marks}}]);
            my ($fill, $mark);
            $fill = $m[2] || $$cols[$i] if $m[1] ? $m[1] =~ /^f/ : $style =~ /\bf/;
            $mark = $markerData{$m[0]};
            $mark or $markID{$mark} = '', next; # skip 'none' or unrecognized marker name
            if ($fill and $fill ne 'none') {
                my $op = $m[3] || ($$cols[$i] eq 'none' ? 50 : 20);
                $mark .= qq( fill="$fill" style="fill-opacity: $op%");
            } else {
                $mark .= ' fill="none"';
            }
            # (was using 'context-stroke', but Chrome didn't show this properly)
            $mark .= " stroke='$$cols[$i]'/>";
            # don't re-define mark if it is the same as a previous one
            $markID{$mark} and $markID{$i} = $markID{$mark}, next;
            $markID{$mark} = $markID{$i} = "mark$i";
            print $fp "\n<marker id='$markID{$i}' markerWidth='8' markerHeight='8' refX='4'",
                      " refY='4'>\n$mark\n</marker>";
        }
        print $fp "\n</defs>\n<style>";
        for ($i=0; $i<@name; ++$i) {
            next unless $markID{$i} eq "mark$i";
            print $fp "\n  path.mark$i { marker: url(#mark$i) }";
        }
    } else {
        print $fp "\n</defs>\n<style>";
    }
    print $fp "\n  text { fill: $$self{text} }\n</style>";
    print $fp "\n<rect x='0' y='0' width='$size[0]' height='$size[1]' fill='$$self{bkg}'/>" if $$self{bkg};
    print $fp "\n<!-- X axis -->";
    print $fp "\n<g dominant-baseline='hanging' text-anchor='middle'>";
    $py = int(($margin[1] + $height + $$tpad[1]) * 10 + 0.5) / 10;
    $px = int(($margin[0] + $width / 2) * 10 + 0.5) / 10;
    if ($title) {
        print $fp "\n<text x='${px}' y='14' font-size='150%'>$title</text>";
    }
    if ($xlabel) {
        $y = $py + $$self{linespacing};
        print $fp "\n<text x='${px}' y='${y}'>$xlabel</text>";
    }
    if ($ylabel) {
        $y = $margin[1] + $height / 2;
        print $fp "\n<text x='10' y='${y}' transform='rotate(-90,10,$y)'>$ylabel</text>";
    }
    # make sure the X labels will fit
    my $spc = $dx;
    for (;;) {
        # find longest label at current spacing
        my $len = 0;
        my $x0 = int($xmax / $spc + 0.5) * $spc;    # get value of last x label
        for ($i=0, $x=$x0; $i<3; ++$i, $x-=$spc) {
            $n = length sprintf('%g', $x);
            $len = $n if $len < $n;
        }
        last if $spc >= ($len + 1) * $wch * $xdiff / $width;
        # increase label spacing by one increment and try again
        $spc = $dx2 = GetGridSpacing($spc, 1);
    }
    my ($grid, $lastLen) = ('', 0);
    for ($x=int($xmin/$dx-1)*$dx; ; $x+=$dx) {
        $px = int(($margin[0] + ($x - $xmin) * $width / $xdiff) * 10 + 0.5) / 10;
        next if $px < $margin[0] - 0.5;
        last if $px > $margin[0] + $width + 0.5;
        my $h = $height;
        if (not $dx2 or abs($x/$dx2 - int($x/$dx2+($x>0 ? 0.5 : -0.5))) < 0.01) {
            printf $fp "\n<text x='${px}' y='${py}'>%g</text>", $x;
            $h += $$tpad[1]/2;
        }
        length($grid) - $lastLen > 80 and $grid .= "\n", $lastLen = length($grid);
        $grid .= sprintf("M$px $margin[1] v$h ");
    }
    print $fp "\n<path stroke='$$self{grid}' stroke-width='0.5' d='\n${grid}'/>";
    print $fp "\n</g>\n<!-- Y axis -->\n<g dominant-baseline='middle' text-anchor='end'>";
    $px = int(($margin[0] - $$tpad[0]) * 10 + 0.5) / 10;
    ($grid, $lastLen) = ('', 0);
    my ($gx, $gw) = ($margin[0]-$$tpad[0]/2, $width + $$tpad[0]/2);
    for ($y=$min; ; $y+=$dy) {
        $py = int(($margin[1] + $height - ($y - $min) * $yscl) * 10 + 0.5) / 10;
        last if $py < $margin[1] - 0.5;
        $y = 0 if $y < $dy/2 and $y > -$dy/2;       # (avoid round-off errors)
        printf $fp "\n<text x='${px}' y='${py}'>%g</text>", $y;
        $y < $dy/2 and $y > -$dy/2 and $xAxis = 1;  # redraw x axis later
        length($grid) - $lastLen > 80 and $grid .= "\n", $lastLen = length($grid);
        $grid .= "M$gx $py h$gw ";
    }
    if ($xAxis and $min!=0) {
        $py = $margin[1] + $height + $min * $yscl;
        print $fp "\n<path stroke='$$self{text}' d='M$margin[0] $py h$width'/>";
    }
    print $fp "\n<path stroke='$$self{grid}' stroke-width='0.5' d='\n${grid}'/>";
    print $fp "\n</g>\n<!-- Plot box and legend -->\n<g dominant-baseline='middle' text-anchor='start'>";
    print $fp "\n<path stroke='$$self{text}' fill='none' d='M$margin[0] $margin[1] l0 $height $width 0 0 -$height z'/>";
    for ($i=0; $i<@name and not $noLegend; ++$i) {
        $x = $size[0] - $margin[2] - 175 + $$self{legend}[0];
        $y = $margin[1] + $$self{legend}[1] + 15 + $$self{linespacing} * ($i + 0.5);
        my $col = $$cols[$i];
        my $mark = $markID{$i} ? " marker-end='url(#$markID{$i})' fill='none'" : '';
        my $line = ($style =~ /\bl/) ? ' l-20 0' : sprintf(' m%.4g 0', -5 * $wid);
        my $sw = ($style =~ /\bm/ ? 1.5 : 2) * $wid; # (wider for line-only style so colour is more visible)
        print $fp "\n<path$mark stroke-width='${sw}' stroke='${col}' d='M$x $y m-7 -1${line}'/>";
        print $fp "\n<text x='${x}' y='${y}'>$name[$i]</text>";
    }
    # print the data
    foreach (0..$#name) {
        $col{$name[$_]} = $$cols[$_];
        $class{$name[$_]} = $markID{$_} ? " class='$markID{$_}'" : '';
    }
    my ($i0, $i1, $xsclr);
    my $fill = '';
    if ($scat) {
        ($i0, $i1) = (0, $#$xdat);
    } elsif ($hist) {
        ($i0, $i1) = (0, $#$hist);
        $xscl = $width / @$hist;
        $px0 = $margin[0];
        $xsclr = int($xscl * 100 + 0.5) / 100;
        if ($style =~ /\bf/) {
            my @m = split /-/, $$marks[0];
            my $op = $m[3] || ($style =~ /\bl/ ? 20 : 50);
            $fill = " fill='$$cols[0]'";
            $fill .= " style='fill-opacity: $op%'" if $$cols[0] ne 'none';
        }
    } else {
        $i0 = int($xmin) - 1;
        $i0 = 0 if $i0 < 0;
        $i1 = int($xmax) + 1;
    }
    print $fp "\n</g>\n<!-- Datasets -->\n<g fill='none' clip-path='url(#plot-area)'",
              " stroke-linejoin='round' stroke-linecap='round' stroke-width='",1.5*$wid,"'>";
    my $doLines = $style =~ /\bl/;
    foreach (@name) {
        my $stroke = ($hist and not $doLines) ? 'none' : $col{$_};
        my $dat = $$data{$_};
        print $fp "\n<!-- $_ -->";
        print $fp "\n<path$class{$_}$fill stroke='${stroke}' d='";
        print $fp 'M' if $doLines;
        my $m = $doLines ? '' : ' M';
        for ($i=$i0; $i<=$i1; ++$i) {
            next unless defined $$dat[$i];
            $y = int(($py0 - $$dat[$i] * $yscl) * 10 + 0.5) / 10;
            if ($scat) {
                next unless defined $$xdat[$i];
                $x = int(($px0 + $$xdat[$i] * $xscl) * 10 + 0.5) / 10;
            } else {
                $x = int(($px0 + $i * $xscl) * 10 + 0.5) / 10;
                if ($hist) {
                    print $fp $m, ($i % 5 ? ' ' : "\n"), "$x $y h$xsclr";
                    $m = ' L';  # (draw lines after the first point)
                    next;
                }
            }
            print $fp $m, ($i % 10 ? ' ' : "\n"), "$x $y";
        }
        print $fp ' V', $margin[1]+$height, " H$margin[0] z" if $hist and $fill;
        print $fp "'/>";
    }
    print $fp "\n</g>";
    print $fp "\n</g>" if $numPlots > 1;
  }
  print $fp "</svg>\n" or $$self{Error} = 'Error writing output plot file';
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Plot - Plot tag values in SVG format

=head1 DESCRIPTION

Output plots in SVG format based on  ExifTool tag information.

=head1 METHODS

=head2 new

Create a new Plot object.

    $plot = Image::ExifTool::Plot->new;

=head2 Settings

Change plot settings.

=over 4

=item Inputs:

0) Plot object reference

1) Comma-delimited string of options

=item Options:

  "Type=Line"           - plot type (Line, Scatter or Histogram)
  "Style=Line"          - data style (Line, Marker and/or Fill)
  "NBins=20"            - number of bins for histogram plot
  "Size=800 600"        - width,height of output image
  "Margin=60 15 15 30"  - left,top,right,bottom margins around plot area
  "Legend=0 0"          - x,y offset to shift plot legend
  "TxtPad=10 10"        - padding between text and x,y scale
  "LineSpacing=20"      - spacing between text lines
  "Stroke=1"            - plot stroke width and marker-size scaling factor
  Title, XLabel, YLabel - plot title and x/y axis labels (no default)
  XMin, XMax            - x axis minimum/maximum (autoscaling if not set)
  YMin, YMax            - y axis minimum/maximum
  Multi                 - number of columns when drawing multiple plots,
                          followed optional number of datasets for each
                          plot (1 by default) using any separator
  Split                 - flag to split strings of numbers into lists
                          (> 1 to split into lists of N items)
  "Grid=darkgray"       - grid color
  "Text=black"          - color of text and plot border
  "Bkg="                - background color (default is transparent)
  "Cols=red green blue black orange gray fuchsia brown turquoise gold"
                        - colors for plot data
  "Marks=circle square triangle diamond star plus pentagon left down right"
                        - marker-shape names for each dataset

=back

=head2 AddPoints

Add points to be plotted.

=over 4

=item Inputs:

0) Plot object reference

1) Tag information hash reference from ExifTool

2) List of tag keys to plot

=back

=head2 Draw

Draw the SVG plot to the specified output file.

=over 4

=item Inputs:

0) Plot object reference

1) Output file reference

=item Notes:

On return, the Plot Error and Warn members contain error or warning strings
if there were any problems.  If an Error is set, then the output SVG is
invalid.

=back

=head1 AUTHOR

Copyright 2003-2026, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

=over 4

=item L<https://exiftool.org/plot.html>

=back

=cut

