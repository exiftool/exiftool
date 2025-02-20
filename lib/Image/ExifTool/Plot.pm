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

$VERSION = '1.01';

# default plot settings (lower-case settings may be overridden by the user)
my %defaults = (
    size   => [ 800, 600 ],        # width,height of output image
    margin => [ 60, 15, 15, 30 ],  # left,top,right,bottom margins around plot area
    legend => [ 0, 0 ],            # top,right offset for legend
    txtPad => [ 10, 10 ],          # padding between text and x,y scale
    lineSpacing => 20,             # text line spacing
    # colors for plot lines
    cols   => [ qw(red green blue black orange gray purple cyan brown pink
                   goldenrod lightsalmon seagreen goldenrod cadetblue plum
                   deepskyblue mediumpurple royalblue tomato) ],
    grid   => 'darkgray',          # grid color
    text   => 'black',             # text and plot frame color
    type   => 'line',              # plot type, 'line' or 'scatter'
    style  => 'line',              # 'line', 'marker' or 'line+marker'
    xlabel => '',                  # x axis label
    ylabel => '',                  # y axis label
    title  => '',                  # plot title
    nbins  => 20,                  # number of histogram bins
    # xmin, xmax                   # x axis minimum,maximum
    # ymin, ymax                   # y axis minimum,maximum
    # split                        # split list of numbers into separate plot lines
    # bkg                          # background color
    Data   => { },                 # data arrays for each variable
    Name   => [ ],                 # variable names
    XMax   => 0,                   # number of points in plot so far
);

my @markerName = qw(circle square triangle diamond triangle2 triangle3 triangle4);
my @markerData = (
    '<circle cx="6" cy="6" r="4" stroke-width="1.5" stroke="context-stroke" fill="none" />',
    '<path stroke-width="1.5" stroke="context-stroke" fill="none" d="M2.5 2.5 l7 0 0 7 -7 0 z"/>',
    '<path stroke-width="1.5" stroke="context-stroke" fill="none" d="M6 1.2 l4 8 -8 0 z"/>',
    '<path stroke-width="1.5" stroke="context-stroke" fill="none" d="M6 1.5 l4.5 4.5 -4.5 4.5 -4.5 -4.5 z"/>',
    '<path stroke-width="1.5" stroke="context-stroke" fill="none" d="M1.2 6 l8 4 0 -8 z"/>',
    '<path stroke-width="1.5" stroke="context-stroke" fill="none" d="M6 10.8 l4 -8 -8 0 z"/>',
    '<path stroke-width="1.5" stroke="context-stroke" fill="none" d="M10.8 6 l-8 4 0 -8 z"/>',
);
# optimal number grid lines in X and Y for a 800x600 plot and nominal character width
my ($nx, $ny, $wch) = (15, 12, 8);

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
        my ($name, $val) = ($1, $3);
        if (ref $$self{$name} eq 'ARRAY') {
            next unless defined $val;
            $$self{lc $name} = [ split /[\s\/]+/, $val ]; # split on space or slash
        } else {
            $val = 1 unless defined $val;   # default to 1 if no "="
            my %charName = ('&'=>'amp', '<'=>'lt', '>'=>'gt');
            # escape necessary XML characters, but allow numerical entities
            $val =~ s/([&><])/&$charName{$1};/sg and $val =~ s/&amp;(#(\d+|x[0-9a-fA-F]+);)/&$1/;
            undef $val unless length $val;
            $$self{lc $name} = $val;
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
    my $scat = $$self{type} =~ /^s/i;
    my $xname = $$self{Name}[0];    # (x-axis name if using scatter plot)
    my $maxLines = $$self{type} =~ /^h/i ? 1 : 20;
    for (;;) {
        if (@vals) {
            $val = shift @vals;
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
        next unless defined $val and $val =~ /^[+-]?(?=\.?\d)\d*\.?\d*(?:e[+-]?\d+)?([ ,;\t\n\r]?|\z)/i;
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
            if (@{$$self{Name}} >= $maxLines) {
                unless ($$self{MaxTags}) {
                    if ($$self{type} =~ /^h/i) {
                        $$self{Warn} = 'A histogram can only plot one variable';
                    } else {
                        $$self{Warn} = 'Too many variables to plot all of them';
                    }
                    $$self{MaxTags} = 1;
                }
                next;
            }
            push @{$$self{Name}}, $name;
            $xname or $xname = $name;   # x-axis data for scatter plot
            unless (defined $$self{Min}) {
                $$self{Min} = $$self{Max} = $val unless $scat and $name eq $xname;
                $xmin = $xmax = $docNum unless defined $xmin;
            }
            $num{$name} = $xmax;
            $$data{$name}[$xmax - $xmin] = $val if $xmax >= $xmin;
            next;
        }
        if ($docNum and $num{$name} < $docNum) {
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
# Inputs: 0) nominal spacing (must be positive)
# Returns: spacing rounded to an even number
sub GetGridSpacing($)
{
    my $nom = shift;
    my $rounded;
    my $div = sprintf('%.3e', $nom);
    my $num = substr($div, 0, 1);
    my $exp = $div =~ s/.*e// ? $div : 0;
    # look for nearest factor to 1, 1.5, 2 or 5 * 10^x
    ($num, $exp) = $num < 8 ? (5, $exp) : (1, $exp+1) if $num > 2;
    return $exp >= 0 ? $num . ('0' x $exp) : '.' . ('0' x (-$exp - 1)) . $num;
}

#------------------------------------------------------------------------------
# Draw SVG plot
# Inputs: 0) Plot ref, 1) Output file reference
sub Draw($$)
{
    my ($self, $fp) = @_;
    my ($min, $max, $xmin, $xmax, $name, $style) = @$self{qw(Min Max XMin XMax Name style)};

    if (not defined $min or not defined $xmin or not $style) {
        $$self{Error} = 'Nothing to plot';
        return;
    }
    my ($data, $title, $xlabel, $ylabel, $cols) = @$self{qw(Data title xlabel ylabel cols)};
    my ($i, $n, %col, %class, $dx, $dy, $dx2, $xAxis, $x, $y, $px, $py);
    my ($grid, $lastLen, $noLegend, $xname, $xdat, $xdiff, $diff);
    my $scat = $$self{type} =~ /^s/i ? 1 : 0;
    my $hist = $$self{type} =~ /^h/i ? [ ] : 0;
    my @name = @$name;
    my @margin = ( @{$$self{margin}} );

    # set reasonable default titles and labels
    $xname = shift @name if $scat;
    $title = "$name[0] vs $xname" if $scat and defined $title and not $title and @name == 1;
    $xlabel = $$name[0] if $scat || $hist and defined $xlabel and not $xlabel;
    $ylabel = ($hist ? 'Count' : $name[0]) and $noLegend=1 if defined $ylabel and not $ylabel and @name == 1;

    # make room for title/labels
    $margin[1] += $$self{lineSpacing} * 1.5 if $title;
    $margin[3] += $$self{lineSpacing} if $xlabel;
    $margin[0] += $$self{lineSpacing} if $ylabel;

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
            my $dnx2 = ($xmax - $xmin) / ($nx * 2);
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
        my $dny2 = ($max - $min) / ($ny * 2);
        $min = ($min >= 0 and  $min < $dny2) ? 0 : $min - $dny2;
        $max = ($max <= 0 and -$max < $dny2) ? 0 : $max + $dny2;
        # adjust to user-defined range if specified
        $min = $$self{ymin} if defined $$self{ymin};
        $max = $$self{ymax} if defined $$self{ymax};
    }
    # generate random colors if we need more
    while (@$cols < @$name) {#138
        $$self{seeded} or srand(141), $$self{seeded} = 1;
        push @$cols, sprintf("#%.2x%.2x%.2x",int(rand(220)),int(rand(220)),int(rand(220)));
    }
    $diff = $max - $min || 1;
    $xdiff = $xmax - $xmin || 1;

    # determine y grid spacing (nice even numbers)
    $dy = GetGridSpacing($diff / ($hist ? $$self{nbins} : $ny));
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
        $diff = $max - $min || 1;
        $dx = $dy;
        $dy = GetGridSpacing($diff / $ny);
        $max = ($max > 0 ? int($max/$dy+0.9999) : int($max/$dy)) * $dy;
        $$data{$name[0]} = $hist;
    } else {
        $dx = GetGridSpacing($xdiff / $nx);
    }
    if ($scat) {
        $xmin = ($xmin > 0 ? int($xmin/$dx) : int($xmin/$dx-0.9999)) * $dx;
        $xmax = ($xmax > 0 ? int($xmax/$dx+0.9999) : int($xmax/$dx)) * $dx;
    }
    $diff = $max - $min || 1;
    $xdiff = $xmax - $xmin || 1;
    # width/height of plot area
    my $width  = $$self{size}[0] - $margin[0] - $margin[2];
    my $height = $$self{size}[1] - $margin[1] - $margin[3];
    my $yscl = $height / $diff;
    my $xscl = $width / $xdiff;
    my $px0 = $margin[0] - $xmin * $xscl;
    my $py0 = $margin[1] + $height + $min * $yscl;
    my $tmp = $title || "Plot by ExifTool $Image::ExifTool::VERSION";
    print $fp qq{<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 20010904//EN" "http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd">
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="$$self{size}[0]" height="$$self{size}[1]"
 preserveAspectRatio="xMidYMid meet" viewBox="0 0 $$self{size}[0] $$self{size}[1]">
<title>$tmp</title>};
    print $fp "<rect x='0' y='0' width='$$self{size}[0]' height='$$self{size}[1]' fill='$$self{bkg}'/>" if $$self{bkg};
    print $fp "\n<!-- X axis -->";
    print $fp "\n<g dominant-baseline='hanging' text-anchor='middle'>";
    $py = int(($margin[1] + $height + $$self{txtPad}[1]) * 10 + 0.5) / 10;
    $px = int(($margin[0] + $width / 2) * 10 + 0.5) / 10;
    if ($title) {
        print $fp "\n<text x='${px}' y='14' font-size='150%'>$title</text>";
    }
    if ($xlabel) {
        $y = $py + $$self{lineSpacing};
        print $fp "\n<text x='${px}' y='${y}'>$xlabel</text>";
    }
    if ($ylabel) {
        $y = $margin[1] + $height / 2;
        print $fp "\n<text x='10' y='${y}' transform='rotate(-90,10,$y)'>$ylabel</text>";
    }
    # check to be sure the X labels will fit
    my $len = 0;
    for ($i=0, $x=$xmax; $i<3; ++$i, $x-=$dx) {
        $n = length sprintf('%g', $x);
        $len = $n if $len < $n;
    }
    my $n = $wch * $len * $xdiff / $dx; # conservative length of all x-axis text
    $dx2 = GetGridSpacing($dx * $n * 1.5 / 500) if $n > 500; # use larger label spacing
    ($grid, $lastLen) = ('', 0);
    for ($x=int($xmin/$dx-1)*$dx; ; $x+=$dx) {
        $px = int(($margin[0] + ($x - $xmin) * $width / $xdiff) * 10 + 0.5) / 10;
        next if $px < $margin[0] - 0.5;
        last if $px > $margin[0] + $width + 0.5;
        if (not $dx2 or $x/$dx2 - int($x/$dx2) < 0.1) {
            printf $fp "\n<text x='${px}' y='${py}'>%g</text>", $x;
        }
        length($grid) - $lastLen > 80 and $grid .= "\n", $lastLen = length($grid);
        $grid .= sprintf("M$px $margin[1] v$height ");
    }
    print $fp "\n<path stroke='$$self{grid}' stroke-width='0.5' d='\n${grid}'/>";
    print $fp "\n</g>\n<!-- Y axis -->\n<g dominant-baseline='middle' text-anchor='end'>";
    $px = int(($margin[0] - $$self{txtPad}[0]) * 10 + 0.5) / 10;
    ($grid, $lastLen) = ('', 0);
    for ($y=$min; ; $y+=$dy) {
        $py = int(($margin[1] + $height - ($y - $min) * $yscl) * 10 + 0.5) / 10;
        last if $py < $margin[1] - 0.5;
        $y = 0 if $y < $dy/2 and $y > -$dy/2; # (avoid round-off errors)
        printf $fp "\n<text x='${px}' y='${py}'>%g</text>", $y;
        $y < $dy/2 and $y > -$dy/2 and $xAxis = 1, next;    # draw x axis later
        length($grid) - $lastLen > 80 and $grid .= "\n", $lastLen = length($grid);
        $grid .= "M$margin[0] $py h$width ";
    }
    if ($xAxis and $min!=0) {
        $py = $margin[1] + $height + $min * $yscl;
        print $fp "\n<path stroke='$$self{text}' d='M$margin[0] $py h${width}'/>";
    }
    print $fp "\n<path stroke='$$self{grid}' stroke-width='0.5' d='\n${grid}'/>";
    print $fp "\n</g>\n<!-- Plot box and legend-->\n<g dominant-baseline='middle' text-anchor='start'>";
    print $fp "\n<path stroke='$$self{text}' fill='none' d='M$margin[0] $margin[1] l0 $height $width 0 0 -$height z'/>";
    for ($i=0; $i<@name and not $noLegend; ++$i) {
        next if $scat and not $i;
        $x = $margin[0] + $$self{legend}[0] + 550;
        $y = $margin[1] + $$self{legend}[1] + 15 + $$self{lineSpacing} * ($i - $scat + 0.5);
        my $col = $$cols[$i];
        my $mark = '';
        if ($style =~ /\b[mp]/i) { # 'm' for 'marker' or 'p' for 'point' (undocumented)
            my $id = $markerName[$i % @markerName];
            $mark = " marker-end='url(#$id)' fill='none'";
        }
        my $line = ($style =~ /\bl/i) ? ' l-20 0' : '';
        print $fp "\n<path$mark stroke-width='2' stroke='${col}' d='M$x $y m-7 -1${line}'/>";
        print $fp "\n<text x='${x}' y='${y}'>$name[$i]</text>";
    }
    my @clip = ($margin[0]-6, $margin[1]-6, $width+12, $height+12);
    print $fp "\n</g>\n<!-- Definitions -->\n<defs>";
    print $fp "\n<clipPath id='plot-area'><rect x='$clip[0]' y='$clip[1]' width='$clip[2]' height='$clip[3]' /></clipPath>";
    if ($style =~ /\b[mp]/i) {
        for ($i=0; $i<@markerName and $i<@name; ++$i) {
            print $fp "\n<marker id='@markerName[$i]' markerWidth='12' markerHeight='12' refX='6' refY='6' markerUnits='userSpaceOnUse'>";
            my $mark = $markerData[$i];
            $mark =~ s/"none"/"$$cols[$i]"/ if $style =~ /\bf/i;
            print $fp "\n$mark\n</marker>";
        }
        print $fp "\n</defs>\n<style>";
        for ($i=0; $i<@markerName and $i<@name; ++$i) {
            print $fp "\n  path.$markerName[$i] { marker: url(#$markerName[$i]) }";
        }
        print $fp "\n  text { fill: $$self{text}] }";
        print $fp "\n</style>";
    } else {
        print $fp "\n</defs><style>\n  text { fill: $$self{text} }\n</style>";
    }
    print $fp "\n<g fill='none' clip-path='url(#plot-area)' stroke-linejoin='round' stroke-linecap='round' stroke-width='1.5'>";
    foreach (0..$#name) {
        $col{$name[$_]} = $$cols[$_];
        $class{$name[$_]} = $style =~ /\b[mp]/i ? ' class="' . $markerName[$_ % @markerName] . '"' : '';
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
        $fill = qq( fill="$$cols[0]" style="fill-opacity: .20") if $$self{style} =~ /\bf/i;
    } else {
        $i0 = int($xmin) - 1;
        $i0 = 0 if $i0 < 0;
        $i1 = int($xmax) + 1;
    }
    foreach (@name) {
        my $dat = $$data{$_};
        my $doLines = $style =~ /\bl/i;
        print $fp "\n<!-- $_ -->";
        print $fp "\n<path$class{$_}$fill stroke='$col{$_}' d='";
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
            print $fp $m, ($i % 20 ? ' ' : "\n"), "$x $y";
        }
        print $fp ' V', $margin[1]+$height, " H$margin[0] z" if $hist and $fill;
        print $fp "'/>";
    }
    print $fp "\n</g></svg>\n";
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Plot - Plot tag values in SVG format

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to plot tag
values in SVG format.

=head1 AUTHOR

Copyright 2003-2025, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

