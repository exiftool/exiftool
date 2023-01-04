#------------------------------------------------------------------------------
# File:         Motorola.pm
#
# Description:  Read Motorola meta information
#
# Revisions:    2015/10/29 - P. Harvey Created
#
# References:   1) Neal Krawetz private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Motorola;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;

$VERSION = '1.02';

# Motorola makernotes tags (ref PH)
%Image::ExifTool::Motorola::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Camera' },
    WRITABLE => 1,
    # 0x54e0 - int8u: 1
    # 0x54f0 - float
    0x5500 => { Name => 'BuildNumber',      Writable => 'string' }, #1 (eg. 'MPJ24.139-23.4')
    0x5501 => { Name => 'SerialNumber',     Writable => 'string' }, #1 (eg. 'ZY2238TJ4V')
    # 0x5502 - int8u
    # 0x5503 - int8u
    # 0x5510 - int8u: 0,1
    # 0x5511 - int32u (3 of these tags for some cameras)
    # 0x5512 - int32u
    # 0x5520 - int16s
    # 0x5530 - string: 'continuous-picture','auto','continuous-video'
    # 0x5540 - int8u: 95
    # 0x5550 - int8u: 85,90
    # 0x5560 - string: 'auto'
    # 0x5570 - string: 'auto','auto-hdr'
    # 0x5580 - int32s: 9000,14949,15000,24000
    # 0x5590 - int32s: 30000
    # 0x55a0 - int32s: 960,1280,1440
    # 0x55b0 - int32s: 720,960,1080
    # 0x55c0 - int32s: 30
    # 0x55d0 - string: 'yuv420sp'
    # 0x55e0-0x55e9 - int16u
    # 0x55f0 - int8u: 10
    # 0x55f1 - int8u: 13
    # 0x55f2-0x55f5 - int16u[130]
    # 0x5600 - int8u: 0,16
    # 0x5601 - int16u[16]
    # 0x5602 - int32u[3,50]
    # 0x5603 - int32u: 0
    # 0x6400 - string: 'AUTO','ON','OFF'
    # 0x6401 - string: 'HDR'
    # 0x6410 - string: 'NO','YES'
    # 0x6420 - int32s for some models: 0 (only exists in HDR images?)
    0x6420 => { #forum13731
        Condition => '$format eq "string"',
        Name => 'CustomRendered',
        Writable => 'string',
    },
    # 0x6430 - float
    # 0x6431 - int8u: 0,1
    # 0x6432 - int8u: 0,79,100
    # 0x6433 - int8u: 0,1
    # 0x6434 - int8u: 0,65,100
    # 0x6435 - int8u: 1,6,24
    # 0x6436 - int8u: 55,60
    # 0x6437 - int8u: 30,35,40
    # 0x6438 - int8u: 24,40
    # 0x6439 - int8u: 15,50
    # 0x643a - int8u: 0,20
    # 0x643b - string: '2,8,-4','2,10,-4',''
    # 0x643c - int32s
    # 0x643d - float
    # 0x6440 - int8u[N]: 0's and 1's
    # 0x6441 - int8u[N]
    # 0x6442,0x6443 - int8u[N]: 0's and 1's
    # 0x644d - string: 'YES'
    # 0x644f - float
    # 0x6450 - float
    # 0x6451 - float: 0.699999988079071
    # 0x6452 - int8u: 1
    # 0x6470 - string: 'AUTO'
    # 0x6471 - int8u: 1
    # 0x6473 - int8u: 24
    # 0x6474 - int8u: 10
    # 0x6475 - int32u[24]
    # 0x6476 - int32u: 2
    # 0x6490 - int8u: 0
    # 0x64c0 - int32s: 0,2
    # 0x64c1 - int32u: 1,4,64
    # 0x64c2,0x64c3 - int32s
    # 0x64c4 - int32s
    # 0x64c5 - int32u
    0x64d0 => { Name => 'DriveMode', Writable => 'string' }, #forum13731
    # 0x6500 - int8u: 1
    # 0x6501 - string: 'Luma-Chroma Plane','Chroma only' or int8u: 0
    # 0x6502 - string: 'Luma-Chroma Plane','Chroma only','' or int8u: 1,255
    # 0x6504 - int32s
    # 0x6530-0x6535 - int32s
    # 0x6600-0x6605 - int8u
    # 0x6606 - string: 'D50','TL84','5000' - illuminant? color temperature?
    # 0x6607 - string: 'D50g','D65','3000' - illuminant? color temperature?
    # 0x6608 - string: 'A'
    # 0x6609-0x660e - float
    # 0x660f - int12u
    # 0x6612-0x661b - int16u
    # 0x661d - int16u
    # 0x661e-0x6635 - float
    # 0x6637 - int8u[212]
    # 0x6640,0x6641 - int8u
    # 0x6642-0x6649 - int16u
    # 0x664e - in8u
    # 0x664f-0x6652 - int16u
    # 0x6653 - string: 'QC','AL'
    # 0x6654-0x6656 - int16u
    # 0x665d - int8u: 0
    0x665e => { Name => 'Sensor',           Writable => 'string' }, # (eg. 'BACK,IMX230')
    # 0x6700 - string: eg. 'eac040d0','333e1721','001b7b3a','000000000005040f'
    # 0x6701 - string: eg. '14048001',940140230','940140190'
    # 0x6702 - string: '0L','1L','0S','3S','32','33,'42'
    # 0x6703 - string: 'PR','SEG','LIG','LI','SHV','SH','SO'
    # 0x6704 - string: 'DO','GX1','GZ0','GZ1','GX2','VI','VI1','VI2','GU',''
    0x6705 => { Name => 'ManufactureDate',  Writable => 'string' }, # (NC, eg. '03Jun2015')
    # 0x6706 - string: eg. '30454e4e','42%','01%','01','1','904c2ca2'
    # 0x6707 - string: eg. '1','25a2ca16','002371e1','69'
    # 0x6708-0x670c - string or int16u (string may be firmware revision)
    # 0x6800 - int32u: 1,2
    # 0x6801,0x6802 - float
    # 0x6803 - int16u
    # 0x6804,0x6805 - float
    # 0x6806 - int16u,int32s
    # 0x6807 - int32s,int32u[3]
    # 0x6808 - int32u,int32u[3]
    # 0x6809,0x680a - float[3]
    # 0x680d - int8u: 0
    # 0x680e - float: 0
    # 0x7000 - int8u: 0,2
    # 0x7001,0x7002 - int16s
    # 0x7003-0x7005 - int16u
    # 0x7100 - string: '0-7'
    # 0x7101 - string: '4-7','0-7'
    # 0x7102 - string: '0-3',''
    # 0x7103,0x7104 - string: comma-separated lists of numbers
);

1; # end

__END__

=head1 NAME

Image::ExifTool::Motorola - Read Motorola meta information

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains the definitions to read meta information from Motorola
cell phone images.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Motorola Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
