#------------------------------------------------------------------------------
# File:         ZISRAW.pm
#
# Description:  Read ZISRAW (CZI) meta information
#
# Revisions:    2020-08-07 - P. Harvey Created
#
# References:   1) https://www.zeiss.com/microscopy/us/products/microscope-software/zen/czi.html
#------------------------------------------------------------------------------

package Image::ExifTool::ZISRAW;

use strict;
use vars qw($VERSION);
use Image::ExifTool qw(:DataAccess :Utils);

$VERSION = '1.01';

%Image::ExifTool::ZISRAW::Main = (
    PROCESS_PROC => \&Image::ExifTool::ProcessBinaryData,
    GROUPS => { 0 => 'File', 1 => 'File', 2 => 'Image' },
    NOTES => q{
        As well as the header information listed below, ExifTool also extracts the
        top-level XML-based metadata from Zeiss Integrated Software RAW (ZISRAW) CZI
        files.
    },
    0x20 => {
        Name => 'ZISRAWVersion',
        Format => 'int32u[2]',
        PrintConv => '$val =~ tr/ /./; $val',
    },
    0x30 => {
        Name => 'PrimaryFileGUID',
        Format => 'undef[16]',
        ValueConv => 'unpack("H*",$val)',
    },
    0x40 => {
        Name => 'FileGUID',
        Format => 'undef[16]',
        ValueConv => 'unpack("H*",$val)',
    },
);

#------------------------------------------------------------------------------
# Shorten obscenely long CZI tag names
# Inputs: Tag name
# Returns: Shortened tag name
sub ShortenTagNames($)
{
    local $_;
    $_ = shift;
    s/^HardwareSetting//;
    s/^DevicesDevice/Device/;
    s/LightPathNode//g;
    s/Successors//g;
    s/ExperimentExperiment/Experiment/g;
    s/ObjectivesObjective/Objective/;
    s/ChannelsChannel/Channel/;
    s/TubeLensesTubeLens/TubeLens/;
    s/^ExperimentHardwareSettingsPoolHardwareSetting/HardwareSetting/;
    s/SharpnessMeasureSetSharpnessMeasure/Sharpness/;
    s/FocusSetupAutofocusSetup/Autofocus/;
    s/TracksTrack/Track/;
    s/ChannelRefsChannelRef/ChannelRef/;
    s/ChangerChanger/Changer/;
    s/ElementsChangerElement/Changer/;
    s/ChangerElements/Changer/;
    s/ContrastChangerContrast/Contrast/;
    s/KeyFunctionsKeyFunction/KeyFunction/;
    s/ManagerContrastManager(Contrast)?/ManagerContrast/;
    s/ObjectiveChangerObjective/ObjectiveChanger/;
    s/ManagerLightManager/ManagerLight/;
    s/WavelengthAreasWavelengthArea/WavelengthArea/;
    s/ReflectorChangerReflector/ReflectorChanger/;
    s/^StageStageAxesStageAxis/StageAxis/;
    s/ShutterChangerShutter/ShutterChanger/;
    s/OnOffChangerOnOff/OnOffChanger/;
    s/UnsharpMaskStateUnsharpMask/UnsharpMask/;
    s/Acquisition/Acq/;
    s/Continuous/Cont/;
    s/Resolution/Res/;
    s/Experiment/Expt/g;
    s/Threshold/Thresh/;
    s/Reference/Ref/;
    s/Magnification/Mag/;
    s/Original/Orig/;
    s/FocusSetupFocusStrategySetup/Focus/;
    s/ParametersParameter/Parameter/;
    s/IntervalInfo/Interval/;
    s/ExptBlocksAcqBlock/AcqBlock/;
    s/MicroscopesMicroscope/Microscope/;
    s/TimeSeriesInterval/TimeSeries/;
    s/Interval(.*Interval)/$1/;
    s/SingleTileRegionsSingleTileRegion/SingleTileRegion/;
    s/AcquisitionMode//;
    s/DetectorsDetector/Detector/;
    s/Setup//;
    s/Setting//;
    s/TrackTrack/Track/;
    s/AnalogOutMaximumsAnalogOutMaximum/AnalogOutMaximum/;
    s/AnalogOutMinimumsAnalogOutMinimum/AnalogOutMinimum/;
    s/DigitalOutLabelsDigitalOutLabelLabel/DigitalOutLabelLabel/;
    s/(VivaTomeOpticalSectionInformation)+VivaTomeOpticalSectionInformation/VivaTomeOpticalSectionInformation/;
    s/FocusDefiniteFocus/FocusDefinite/;
    s/ChangerChanger/Changer/;
    s/Calibration/Cal/;
    s/LightSwitchChangerRLTLSwitch/LightSwitchChangerRLTL/;
    s/Parameters//;
    s/Fluorescence/Fluor/;
    s/CameraGeometryCameraGeometry/CameraGeometry/;
    s/CameraCamera/Camera/;
    s/DetectorsCamera/Camera/;
    s/FilterChangerLeftChangerEmissionFilter/LeftChangerEmissionFilter/;
    s/SwitchingStatesSwitchingState/SwitchingState/;
    s/Information/Info/;
    s/SubDimensions?//g;
    s/Setups?//;
    s/Parameters?//;
    s/Calculate/Calc/;
    s/Visibility/Vis/;
    s/Orientation/Orient/;
    s/ListItems/Items/;
    s/Increment/Incr/;
    s/Parameter/Param/;
    s/(ParfocalParcentralValues)+ParfocalParcentralValue/Parcentral/;
    s/ParcentralParcentral/Parcentral/;
    s/CorrFocusCorrection/FocusCorr/;
    s/(ApoTomeDepthInfo)+Element/ApoTomeDepth/;
    s/(ApoTomeClickStopInfo)+Element/ApoTomeClickStop/;
    s/DepthDepth/Depth/;
    s/(Devices?)+Device/Device/;
    s/(BeamPathNode)+/BeamPathNode/;
    s/BeamPathsBeamPath/BeamPath/g;
    s/BeamPathBeamPath/BeamPath/g;
    s/Configuration/Config/;
    s/StageAxesStageAxis/StageAxis/;
    s/RangesRange/Range/;
    s/DataGridDatasGridData(Grid)?/DataGrid/;
    s/DataMicroscopeDatasMicroscopeData(Microscope)?/DataMicroscope/;
    s/DataWegaDatasWegaData/DataWega/;
    s/ClickStopPositionsClickStopPosition/ClickStopPosition/;
    s/LightSourcess?LightSource(Settings)?(LightSource)?/LightSource/;
    s/FilterSetsFilterSet/FilterSet/;
    s/EmissionFiltersEmissionFilter/EmissionFilter/;
    s/ExcitationFiltersExcitationFilter/ExcitationFilter/;
    s/FiltersFilter/Filter/;
    s/DichroicsDichroic/Dichronic/;
    s/WavelengthsWavelength/Wavelength/;
    s/MultiTrackSetup/MultiTrack/;
    s/TrackTrack/Track/;
    s/DataGrabberSetup/DataGrabber/;
    s/CameraFrameSetup/CameraFrame/;
    s/TimeSeries(TimeSeries|Setups)/TimeSeries/;
    s/FocusFocus/Focus/;
    s/FocusAutofocus/Autofocus/;
    s/Focus(Hardware|Software)(Autofocus)+/Autofocus$1/;
    s/AutofocusAutofocus/Autofocus/;
    return $_;
}

#------------------------------------------------------------------------------
# Extract metadata from a ZISRAW (CZI) image
# Inputs: 0) ExifTool object reference, 1) dirInfo reference
# Returns: 1 on success, 0 if this wasn't a valid CZI file
sub ProcessCZI($$)
{
    my ($et, $dirInfo) = @_;
    my $raf = $$dirInfo{RAF};
    my ($buff, $tagTablePtr);

    # verify this is a valid CZI file
    return 0 unless $raf->Read($buff, 100) == 100;
    return 0 unless $buff =~ /^ZISRAWFILE\0{6}/;
    $et->SetFileType();
    SetByteOrder('II');
    my %dirInfo = (
        DataPt => \$buff,
        DirStart => 0,
        DirLen => length($buff),
    );
    $tagTablePtr = GetTagTable('Image::ExifTool::ZISRAW::Main');
    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);

    # read the metadata section
    my $pos = Get64u(\$buff, 92) or return 1;
    $raf->Seek($pos, 0) or $et->Warn('Error seeking to metadata'), return 0;
    $raf->Read($buff, 288) == 288 or $et->Warn('Error reading metadata header'), return 0;
    $buff =~ /^ZISRAWMETADATA\0\0/ or $et->Warn('Invalid metadata header'), return 0;
    my $len = Get32u(\$buff, 32);
    $len < 200000000 or $et->Warn('Metadata section too large. Ignoring'), return 0;
    $raf->Read($buff, $len) or $et->Warn('Error reading XML metadata'), return 0;
    $et->FoundTag('XML', $buff);    # extract as a block
    $tagTablePtr = GetTagTable('Image::ExifTool::XMP::XML');
    $dirInfo{DirLen} = length $buff;
    # shorten tag names somewhat by removing 'ImageDocumentMetadata' prefix from all
    $$et{XmpIgnoreProps} = [ 'ImageDocument', 'Metadata', 'Information' ];
    $$et{ShortenXmpTags} = \&ShortenTagNames;

    $et->ProcessDirectory(\%dirInfo, $tagTablePtr);

    return 1;
}

1;  # end

__END__

=head1 NAME

Image::ExifTool::ZISRAW - Read ZISRAW (CZI) meta information

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This module contains definitions required by Image::ExifTool to read
metadata from Zeiss Integrated Software RAW (ZISRAW) CZI files.

=head1 AUTHOR

Copyright 2003-2024, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<https://www.zeiss.com/microscopy/us/products/microscope-software/zen/czi.html>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/ZISRAW Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut

