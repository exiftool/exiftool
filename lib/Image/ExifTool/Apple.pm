#------------------------------------------------------------------------------
# File:         Apple.pm
#
# Description:  Apple EXIF maker notes tags
#
# Revisions:    2013-09-13 - P. Harvey Created
#
# References:   1) http://www.photoinvestigator.co/blog/the-mystery-of-maker-apple-metadata/
#               2) Frank Rupprecht private communication
#------------------------------------------------------------------------------

package Image::ExifTool::Apple;

use strict;
use vars qw($VERSION);
use Image::ExifTool::Exif;
use Image::ExifTool::PLIST;

$VERSION = '1.14';

sub ConvertPLIST($$);

# Apple iPhone metadata (ref PH)
%Image::ExifTool::Apple::Main = (
    WRITE_PROC => \&Image::ExifTool::Exif::WriteExif,
    CHECK_PROC => \&Image::ExifTool::Exif::CheckExif,
    WRITABLE => 1,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => 'Tags extracted from the maker notes of iPhone images.',
    0x0001 => { # (Version, ref 2)
        Name => 'MakerNoteVersion',
        Writable => 'int32s',
    },
    0x0002 => { #2
        Name => 'AEMatrix',
        Unknown => 1,
        # (not currently writable)
        ValueConv => \&ConvertPLIST,
    },
    0x0003 => { # (Timestamp, ref 2)
        Name => 'RunTime', # (includes time plugged in, but not when suspended, ref 1)
        SubDirectory => { TagTable => 'Image::ExifTool::Apple::RunTime' },
    },
    0x0004 => { #2
        Name => 'AEStable',
        Writable => 'int32s',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x0005 => { #2
        Name => 'AETarget',
        Writable => 'int32s',
    },
    0x0006 => { #2
        Name => 'AEAverage',
        Writable => 'int32s',
    },
    0x0007 => { #2
        Name => 'AFStable',
        Writable => 'int32s',
        PrintConv => { 0 => 'No', 1 => 'Yes' },
    },
    0x0008 => { #1 (FocusAccelerometerVector, ref 2)
        Name => 'AccelerationVector',
        Groups => { 2 => 'Camera' },
        Writable => 'rational64s',
        Count => 3,
        # Note: the directions are contrary to the Apple documentation (which have the
        # signs of all axes reversed -- apparently the Apple geeks aren't very good
        # with basic physics, and don't understand the concept of acceleration.  See
        # http://nscookbook.com/2013/03/ios-programming-recipe-19-using-core-motion-to-access-gyro-and-accelerometer/
        # for one of the few correct descriptions of this).  Note that this leads to
        # a left-handed coordinate system for acceleration.
        Notes => q{
            XYZ coordinates of the acceleration vector in units of g.  As viewed from
            the front of the phone, positive X is toward the left side, positive Y is
            toward the bottom, and positive Z points into the face of the phone
        },
    },
    # 0x0009 - int32s: seen 19,275,531,4371 (SISMethod, ref 2)
    0x000a => { # (HDRMethod, ref 2)
        Name => 'HDRImageType',
        Writable => 'int32s',
        PrintConv => {
            # 2 => ? (iPad mini 2)
            3 => 'HDR Image',
            4 => 'Original Image',
        },
    },
    0x000b => { # (BurstUUID, ref 2)
        Name => 'BurstUUID',
        Writable => 'string',
        Notes => 'unique ID for all images in a burst',
    },
    0x000c => { # ref forum13710 (Neal Krawetz) (SphereHealthTrackingError, ref 2)
        Name => 'FocusDistanceRange',
        Writable => 'rational64s',
        Count => 2,
        PrintConv => q{
            my @a = split ' ', $val;
            sprintf('%.2f - %.2f m', $a[0] <= $a[1] ? @a : reverse @a);
        },
        PrintConvInv => '$val =~ s/ - / /; $val =~ s/ ?m$//; $val',
    },
    # 0x000d - int32s: 0,1,6,20,24,32,40 (SphereHealthAverageCurrent, ref 2)
    # 0x000e - int32s: 0,1,4,12 (Orientation? 0=landscape? 4=portrait? ref 1) (SphereMotionDataStatus, ref 2)
    0x000f => { #2
        Name => 'OISMode',
        Writable => 'int32s',
        # seen: 2,3,5
    },
    # 0x0010 - int32s: 1 (SphereStatus, ref 2)
    0x0011 => { # (if defined, there is a live photo associated with the video, #forum13565) (AssetIdentifier, ref 2)
        Name => 'ContentIdentifier',
        Notes => 'called MediaGroupUUID when it appears as an XAttr',
        # - originally called ContentIdentifier, forum8750
        # - changed in 12.19 to MediaGroupUUID, NealKrawetz private communication
        # - changed back to ContentIdentifier since Apple writes this to Keys content.identifier (forum14874)
        Writable => 'string',
        
    },
    # 0x0012 - (QRMOutputType, ref 2)
    # 0x0013 - (SphereExternalForceOffset, ref 2)
    0x0014 => { # (StillImageCaptureType, ref 2)
        Name => 'ImageCaptureType',
        Writable => 'int32s',
        # seen: 1,2,3,4,5,10,12
        PrintConv => { #forum15096
            1 => 'ProRAW',
            2 => 'Portrait',
            10 => 'Photo',
            11 => 'Manual Focus', #forum16044
            12 => 'Scene', #forum16044
        },
    },
    0x0015 => { # (ImageGroupIdentifier, ref 2)
        Name => 'ImageUniqueID',
        Writable => 'string',
    },
    # 0x0016 - string[29]: "AXZ6pMTOh2L+acSh4Kg630XCScoO\0" (PhotosOriginatingSignature, ref 2)
    0x0017 => { #forum13565 (only valid if MediaGroupUUID/ContentIdentifier exists) (StillImageCaptureFlags, ref 2)
        Name => 'LivePhotoVideoIndex',
        Notes => 'divide by RunTimeScale to get time in seconds',
    },
    # 0x0018 - (PhotosRenderOriginatingSignature, ref 2)
    0x0019 => { # (StillImageProcessingFlags, ref 2)
        Name => 'ImageProcessingFlags',
        Writable => 'int32s',
        Unknown => 1,
        PrintConv => { BITMASK => { } },
    },
    0x001a => { # (PhotoTranscodeQualityHint, ref 2)
        Name => 'QualityHint',
        Writable => 'string',
        Unknown => 1,
        # seen: "q825s\0", "q750n\0", "q900n\0"
    },
    # 0x001b - (PhotosRenderEffect, ref 2)
    # 0x001c - (BracketedCaptureSequenceNumber, ref 2)
    # 0x001c - Flash,  2="On" (ref PH)
    0x001d => { #2
        Name => 'LuminanceNoiseAmplitude',
        Writable => 'rational64s',
    },
    # 0x001e - (OriginatingAppID, ref 2)
    0x001f => {
        Name => 'PhotosAppFeatureFlags', #2
        Notes => 'set if person or pet detected in image', #PH
        Writable => 'int32s',
    },
    0x0020 => { # (ImageCaptureRequestIdentifier, ref 2)
        Name => 'ImageCaptureRequestID',
        Writable => 'string',
        Unknown => 1,
    },
    0x0021 => { # (MeteorHeadroom, ref 2)
        Name => 'HDRHeadroom',
        Writable => 'rational64s',
    },
    # 0x0022 - (ARKitPhoto, ref 2)
    0x0023 => {
        Name => 'AFPerformance', #2
        Writable => 'int32s',
        Count => 2,
        Notes => q{
            first number maybe related to focus distance, last number maybe related to
            focus accuracy
        },
        PrintConv => 'my @a=split " ",$val; sprintf("%d %d %d",$a[0],$a[1]>>28,$a[1]&0xfffffff)',
        PrintConvInv => 'my @a=split " ",$val; sprintf("%d %d",$a[0],($a[1]<<28)+$a[2])',
    },
    # 0x0023 - int32s[2] (AFPerformance, ref 2)
    # 0x0024 - (AFExternalOffset, ref 2)
    0x0025 => { # (StillImageSceneFlags, ref 2)
        Name => 'SceneFlags',
        Writable => 'int32s',
        Unknown => 1,
        PrintConv => { BITMASK => { } },
    },
    0x0026 => { # (StillImageSNRType, ref 2)
        Name => 'SignalToNoiseRatioType',
        Writable => 'int32s',
        Unknown => 1,
    },
    0x0027 => { # (StillImageSNR, ref 2)
        Name => 'SignalToNoiseRatio',
        Writable => 'rational64s',
    },
    # 0x0028 - int32s (UBMethod, ref 2)
    # 0x0029 - string (SpatialOverCaptureGroupIdentifier, ref 2)
    # 0x002A - (iCloudServerSoftwareVersionForDynamicallyGeneratedMedia, ref 2)
    0x002b => {
        Name => 'PhotoIdentifier', #2
        Writable => 'string',
    },
    # 0x002C - (SpatialOverCaptureImageType, ref 2)
    # 0x002D - (CCT, ref 2)
    0x002d => { #PH
        Name => 'ColorTemperature',
        Writable => 'int32s',
    },
    # 0x002E - (ApsMode, ref 2)
    0x002e => { #PH
        Name => 'CameraType',
        Writable => 'int32s',
        PrintConv => {
            0 => 'Back Wide Angle',
            1 => 'Back Normal',
            6 => 'Front',
        },
    },
    # 0x002e - set to 0 for 0.5x (crop?) (ref PH)
    0x002F => { #2
        Name => 'FocusPosition',
        Writable => 'int32s',
    },
    0x0030 => { # (MeteorPlusGainMap, ref 2)
        Name => 'HDRGain',
        Writable => 'rational64s',
    },
    # 0x0031 - (StillImageProcessingHomography, ref 2)
    # 0x0032 - (IntelligentDistortionCorrection, ref 2)
    # 0x0033 - (NRFStatus, ref 2)
    # 0x0034 - (NRFInputBracketCount, ref 2)
    # 0x0034 - 1 for flash on, otherwise doesn't exist (ref PH)
    # 0x0035 - (NRFRegisteredBracketCount, ref 2)
    # 0x0035 - 0 for flash on, otherwise doesn't exist (ref PH)
    # 0x0036 - (LuxLevel, ref 2)
    # 0x0037 - (LastFocusingMethod, ref 2)
    0x0038 => { # (TimeOfFlightAssistedAutoFocusEstimatorMeasuredDepth, ref 2)
        Name => 'AFMeasuredDepth',
        Notes => 'from the time-of-flight-assisted auto-focus estimator',
        Writable => 'int32s',
    },
    # 0x0039 - (TimeOfFlightAssistedAutoFocusEstimatorROIType, ref 2)
    # 0x003A - (NRFSRLStatus, ref 2)
    # 0x003a - non-zero if a person was in the image? (ref PH)
    # 0x003B - (SystemPressureLevel, ref 2)
    # 0x003C - (CameraControlsStatisticsMaster, ref 2)
    # 0x003c - 4=rear cam, 1=front cam? (ref PH)
    0x003D => { # (TimeOfFlightAssistedAutoFocusEstimatorSensorConfidence, ref 2)
        Name => 'AFConfidence',
        Writable => 'int32s',
    },
    0x003E => { # (ColorCorrectionMatrix, ref 2)
        Name => 'ColorCorrectionMatrix',
        Unknown => 1,
        ValueConv => \&ConvertPLIST,
    },
    0x003F => { #2
        Name => 'GreenGhostMitigationStatus',
        Writable => 'int32s',
        Unknown => 1,
    },
    0x0040 => { #2
        Name => 'SemanticStyle',
        Notes => '_1=Tone, _2=Warm, _3=1.Std,2.Vibrant,3.Rich Contrast,4.Warm,5.Cool', #PH
        ValueConv => \&ConvertPLIST,
    },
    0x0041 => { # (SemanticStyleKey_RenderingVersion, ref 2)
        Name => 'SemanticStyleRenderingVer',
        ValueConv => \&ConvertPLIST,
    },
    0x0042 => { # (SemanticStyleKey_Preset, ref 2)
        Name => 'SemanticStylePreset',
        ValueConv => \&ConvertPLIST,
    },
    # 0x0043 - (SemanticStyleKey_ToneBias, ref 2)
    # 0x0044 - (SemanticStyleKey_WarmthBias, ref 2)
    # 0x0045 - (FrontFacing, ref 2) (not for iPhone15, ref PH)
    # 0x0046 - (TimeOfFlightAssistedAutoFocusEstimatorContainsBlindSpot, ref 2)
    # 0x0047 - (LeaderFollowerAutoFocusLeaderDepth, ref 2)
    # 0x0048 - (LeaderFollowerAutoFocusLeaderFocusMethod, ref 2)
    # 0x0049 - (LeaderFollowerAutoFocusLeaderConfidence, ref 2)
    # 0x004a - (LeaderFollowerAutoFocusLeaderROIType, ref 2)
    # 0x004a - 2=back normal, 4=back wide angle, 5=front (ref PH)
    # 0x004b - (ZeroShutterLagFailureReason, ref 2)
    # 0x004c - (TimeOfFlightAssistedAutoFocusEstimatorMSPMeasuredDepth, ref 2)
    # 0x004d - (TimeOfFlightAssistedAutoFocusEstimatorMSPSensorConfidence, ref 2)
    # 0x004e - (Camera, ref 2)
    0x004e => {
        Name => 'Apple_0x004e',
        Unknown => 1,
        # first number is 0 for front cam, 1 for either back cam (ref PH)
        ValueConv => \&ConvertPLIST,
    },
    0x004f => {
        Name => 'Apple_0x004f',
        Unknown => 1,
        ValueConv => \&ConvertPLIST,
    }
);

# PLIST-format CMTime structure (ref PH)
# (CMTime ref https://developer.apple.com/library/ios/documentation/CoreMedia/Reference/CMTime/Reference/reference.html)
%Image::ExifTool::Apple::RunTime = (
    PROCESS_PROC => \&Image::ExifTool::PLIST::ProcessBinaryPLIST,
    GROUPS => { 0 => 'MakerNotes', 2 => 'Image' },
    NOTES => q{
        This PLIST-format information contains the elements of a CMTime structure
        representing the amount of time the phone has been running since the last
        boot, not including standby time.
    },
    timescale => { Name => 'RunTimeScale' }, # (seen 1000000000 --> ns)
    epoch     => { Name => 'RunTimeEpoch' }, # (seen 0)
    value     => { Name => 'RunTimeValue' }, # (should divide by RunTimeScale to get seconds)
    flags => {
        Name => 'RunTimeFlags',
        PrintConv => { BITMASK => {
            0 => 'Valid',
            1 => 'Has been rounded',
            2 => 'Positive infinity',
            3 => 'Negative infinity',
            4 => 'Indefinite',
        }},
    },
);

# Apple composite tags
%Image::ExifTool::Apple::Composite = (
    GROUPS => { 2 => 'Camera' },
    RunTimeSincePowerUp => {
        Require => {
            0 => 'Apple:RunTimeValue',
            1 => 'Apple:RunTimeScale',
        },
        ValueConv => '$val[1] ? $val[0] / $val[1] : undef',
        PrintConv => 'ConvertDuration($val)',
    },
);

# add our composite tags
Image::ExifTool::AddCompositeTags('Image::ExifTool::Apple');

#------------------------------------------------------------------------------
# Convert from binary PLIST format to a tag value we can use
# Inputs: 0) binary plist data, 1) ExifTool ref
# Returns: converted value
sub ConvertPLIST($$)
{
    my ($val, $et) = @_;
    my $dirInfo = { DataPt => \$val, NoVerboseDir => 1 };
    my $oldOrder = $et->GetByteOrder();
    require Image::ExifTool::PLIST;
    Image::ExifTool::PLIST::ProcessBinaryPLIST($et, $dirInfo);
    $val = $$dirInfo{Value};
    if (ref $val eq 'HASH' and not $et->Options('Struct')) {
        require 'Image/ExifTool/XMPStruct.pl';
        $val = Image::ExifTool::XMP::SerializeStruct($et, $val);
    }
    $et->SetByteOrder($oldOrder);
    return $val;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::Apple - Apple EXIF maker notes tags

=head1 SYNOPSIS

This module is loaded automatically by Image::ExifTool when required.

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to interpret
Apple maker notes in EXIF information.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 SEE ALSO

L<Image::ExifTool::TagNames/Apple Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
