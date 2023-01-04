#------------------------------------------------------------------------------
# File:         DarwinCore.pm
#
# Description:  Darwin Core XMP tags
#
# Revisions:    2013-01-28 - P. Harvey Created
#
# References:   1) http://rs.tdwg.org/dwc/index.htm
#               2) https://exiftool.org/forum/index.php/topic,4442.0/all.html
#------------------------------------------------------------------------------

package Image::ExifTool::DarwinCore;

use strict;
use vars qw($VERSION);
use Image::ExifTool::XMP;

$VERSION = '1.07';

my %dateTimeInfo = (
    # NOTE: Do NOT put "Groups" here because Groups hash must not be common!
    Writable => 'date',
    Shift => 'Time',
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => '$self->InverseDateTime($val,undef,1)',
);

my %materialSample = (
    STRUCT_NAME => 'DarwinCore MaterialSample',
    NAMESPACE => 'dwc',
    materialSampleID    => { },
);

my %event = (
    STRUCT_NAME => 'DarwinCore Event',
    NAMESPACE => 'dwc',
    day                 => { Writable => 'integer', Groups => { 2 => 'Time' } },
    earliestDate        => { %dateTimeInfo, Groups => { 2 => 'Time' } },
    endDayOfYear        => { Writable => 'integer', Groups => { 2 => 'Time' } },
    eventDate           => { %dateTimeInfo, Groups => { 2 => 'Time' } },
    eventID             => { Avoid => 1, Notes => 'avoided in favor of XMP-iptcExt:EventID' },
    eventRemarks        => { Writable => 'lang-alt' },
    eventTime => {
        Groups => { 2 => 'Time' },
        Writable => 'string', # (so we can format this ourself)
        Shift => 'Time',
        # (allow date/time or just time value)
        ValueConv => 'Image::ExifTool::XMP::ConvertXMPDate($val)',
        PrintConv => '$self->ConvertDateTime($val)',
        ValueConvInv => 'Image::ExifTool::XMP::FormatXMPDate($val) or $val',
        PrintConvInv => q{
            my $v = $self->InverseDateTime($val,undef,1);
            undef $Image::ExifTool::evalWarning;
            return $v if $v;
            # allow time-only values by adding dummy date (thanks Herb)
            my $v = $self->InverseDateTime("2000:01:01 $val",undef,1);
            undef $Image::ExifTool::evalWarning;
            return $v if $v and $v =~ s/.* //;  # strip off dummy date
            $Image::ExifTool::evalWarning = 'Invalid date/time or time-only value (use HH:MM:SS[.ss][+/-HH:MM|Z])';
            return undef;
        },
    },
    fieldNotes          => { },
    fieldNumber         => { },
    habitat             => { },
    latestDate          => { %dateTimeInfo, Groups => { 2 => 'Time' } },
    month               => { Writable => 'integer', Groups => { 2 => 'Time' } },
    parentEventID       => { },
    samplingEffort      => { },
    samplingProtocol    => { },
    sampleSizeValue     => { },
    sampleSizeUnit      => { },
    startDayOfYear      => { Writable => 'integer', Groups => { 2 => 'Time' } },
    verbatimEventDate   => { Groups => { 2 => 'Time' } },
    year                => { Writable => 'integer', Groups => { 2 => 'Time' } },
);

# Darwin Core tags
%Image::ExifTool::DarwinCore::Main = (
    GROUPS    => { 0 => 'XMP', 1 => 'XMP-dwc', 2 => 'Other' },
    NAMESPACE => 'dwc',
    WRITABLE  => 'string',
    NOTES => q{
        Tags defined in the Darwin Core (dwc) XMP namespace.  See
        L<http://rs.tdwg.org/dwc/index.htm> for the official specification.
    },
    Event => {
        Name => 'DCEvent',  # (avoid conflict with XMP-iptcExt:Event)
        FlatName => 'Event',
        Struct => \%event,
    },
    # tweak a few of the flattened tag names
    EventEventDate    => { Name => 'EventDate',     Flat => 1 },
    EventEventID      => { Name => 'EventID',       Flat => 1 },
    EventEventRemarks => { Name => 'EventRemarks',  Flat => 1 },
    EventEventTime    => { Name => 'EventTime',     Flat => 1 },
    FossilSpecimen    => { Struct => \%materialSample },
    GeologicalContext => {
        FlatName => '', # ('GeologicalContext' is too long)
        Struct => {
            STRUCT_NAME => 'DarwinCore GeologicalContext',
            NAMESPACE => 'dwc',
            bed                         => { },
            earliestAgeOrLowestStage    => { },
            earliestEonOrLowestEonothem => { },
            earliestEpochOrLowestSeries => { },
            earliestEraOrLowestErathem  => { },
            earliestPeriodOrLowestSystem=> { },
            formation                   => { },
            geologicalContextID         => { },
            group                       => { },
            highestBiostratigraphicZone => { },
            latestAgeOrHighestStage     => { },
            latestEonOrHighestEonothem  => { },
            latestEpochOrHighestSeries  => { },
            latestEraOrHighestErathem   => { },
            latestPeriodOrHighestSystem => { },
            lithostratigraphicTerms     => { },
            lowestBiostratigraphicZone  => { },
            member                      => { },
        },
    },
    GeologicalContextBed        => { Name => 'GeologicalContextBed',        Flat => 1 },
    GeologicalContextFormation  => { Name => 'GeologicalContextFormation',  Flat => 1 },
    GeologicalContextGroup      => { Name => 'GeologicalContextGroup',      Flat => 1 },
    GeologicalContextMember     => { Name => 'GeologicalContextMember',     Flat => 1 },
    HumanObservation => { Struct => \%event },
    Identification => {
        FlatName => '', # ('Identification' is redundant)
        Struct => {
            STRUCT_NAME => 'DarwinCore Identification',
            NAMESPACE => 'dwc',
            dateIdentified              => { %dateTimeInfo, Groups => { 2 => 'Time' } },
            identificationID            => { },
            identificationQualifier     => { },
            identificationReferences    => { },
            identificationRemarks       => { },
            identificationVerificationStatus => { },
            identifiedBy                => { },
            typeStatus                  => { },
            # new, ref forum13707
            identifiedByID              => { },
            verbatimIdentification      => { },
        },
    },
    LivingSpecimen      => { Struct => \%materialSample },
    MachineObservation  => { Struct => \%event },
    MaterialSample      => { Struct => \%materialSample },
    MaterialSampleMaterialSampleID => { Name => 'MaterialSampleID', Flat => 1 },
    MeasurementOrFact => {
        FlatName => '', # ('MeasurementOrFact' is redundant and too long)
        Struct => {
            STRUCT_NAME => 'DarwinCore MeasurementOrFact',
            NAMESPACE => 'dwc',
            measurementAccuracy         => { Format => 'real' },
            measurementDeterminedBy     => { },
            measurementDeterminedDate   => { %dateTimeInfo, Groups => { 2 => 'Time' } },
            measurementID               => { },
            measurementMethod           => { },
            measurementRemarks          => { },
            measurementType             => { },
            measurementUnit             => { },
            measurementValue            => { },
        },
    },
    Occurrence => {
        Struct => {
            STRUCT_NAME => 'DarwinCore Occurrence',
            NAMESPACE => 'dwc',
            associatedMedia             => { },
            associatedOccurrences       => { },
            associatedReferences        => { },
            associatedSequences         => { },
            associatedTaxa              => { },
            behavior                    => { },
            catalogNumber               => { },
            disposition                 => { },
            establishmentMeans          => { },
            individualCount             => { },
            individualID                => { },
            lifeStage                   => { },
            occurrenceDetails           => { },
            occurrenceID                => { },
            occurrenceRemarks           => { },
            occurrenceStatus            => { },
            organismQuantity            => { },
            organismQuantityType        => { },
            otherCatalogNumbers         => { },
            preparations                => { },
            previousIdentifications     => { },
            recordedBy                  => { },
            recordNumber                => { },
            reproductiveCondition       => { },
            sex                         => { },
            # new, ref forum13707
            degreeOfEstablishment       => { },
            georeferenceVerificationStatus => { },
            pathway                     => { },
            recordedByID                => { },
        },
    },
    OccurrenceOccurrenceDetails => { Name => 'OccurrenceDetails', Flat => 1 },
    OccurrenceOccurrenceID      => { Name => 'OccurrenceID',      Flat => 1 },
    OccurrenceOccurrenceRemarks => { Name => 'OccurrenceRemarks', Flat => 1 },
    OccurrenceOccurrenceStatus  => { Name => 'OccurrenceStatus',  Flat => 1 },
    Organism => {
        Struct => {
            STRUCT_NAME => 'DarwinCore Organism',
            NAMESPACE => 'dwc',
            associatedOccurrences       => { },
            associatedOrganisms         => { },
            organismID                  => { },
            organismName                => { },
            organismRemarks             => { },
            organismScope               => { },
            previousIdentifications     => { },
        },
    },
    OrganismOrganismID      => { Name => 'OrganismID',      Flat => 1 },
    OrganismOrganismName    => { Name => 'OrganismName',    Flat => 1 },
    OrganismOrganismRemarks => { Name => 'OrganismRemarks', Flat => 1 },
    OrganismOrganismScope   => { Name => 'OrganismScope',   Flat => 1 },
    PreservedSpecimen       => { Struct => \%materialSample },
    Record => {
        Struct => {
            STRUCT_NAME => 'DarwinCore Record',
            NAMESPACE => 'dwc',
            basisOfRecord               => { },
            collectionCode              => { },
            collectionID                => { },
            dataGeneralizations         => { },
            datasetID                   => { },
            datasetName                 => { },
            dynamicProperties           => { },
            informationWithheld         => { },
            institutionCode             => { },
            institutionID               => { },
            ownerInstitutionCode        => { },
        },
    },
    ResourceRelationship => {
        FlatName => '', # ('ResourceRelationship' is redundant and too long)
        Struct => {
            STRUCT_NAME => 'DarwinCore ResourceRelationship',
            NAMESPACE => 'dwc',
            relatedResourceID           => { },
            relationshipAccordingTo     => { },
            relationshipEstablishedDate => { %dateTimeInfo, Groups => { 2 => 'Time' } },
            relationshipOfResource      => { },
            relationshipRemarks         => { },
            resourceID                  => { },
            resourceRelationshipID      => { },
            relationshipOfResourceID    => { }, # new, ref forum13707
        },
    },
    Taxon => {
        Struct => {
            STRUCT_NAME => 'DarwinCore Taxon',
            NAMESPACE => 'dwc',
            acceptedNameUsage           => { },
            acceptedNameUsageID         => { },
            class                       => { },
            family                      => { },
            genus                       => { },
            higherClassification        => { },
            infraspecificEpithet        => { },
            cultivarEpithet             => { }, # new, ref forum13707
            kingdom                     => { },
            nameAccordingTo             => { },
            nameAccordingToID           => { },
            namePublishedIn             => { },
            namePublishedInID           => { },
            namePublishedInYear         => { },
            nomenclaturalCode           => { },
            nomenclaturalStatus         => { },
            order                       => { },
            originalNameUsage           => { },
            originalNameUsageID         => { },
            parentNameUsage             => { },
            parentNameUsageID           => { },
            phylum                      => { },
            scientificName              => { },
            scientificNameAuthorship    => { },
            scientificNameID            => { },
            specificEpithet             => { },
            subgenus                    => { },
            taxonConceptID              => { },
            taxonID                     => { },
            taxonRank                   => { },
            taxonRemarks                => { },
            taxonomicStatus             => { },
            verbatimTaxonRank           => { },
            vernacularName              => { Writable => 'lang-alt' },
        },
    },
    TaxonTaxonConceptID => { Name => 'TaxonConceptID',  Flat => 1 },
    TaxonTaxonID        => { Name => 'TaxonID',         Flat => 1 },
    TaxonTaxonRank      => { Name => 'TaxonRank',       Flat => 1 },
    TaxonTaxonRemarks   => { Name => 'TaxonRemarks',    Flat => 1 },
    dctermsLocation => {
        Name => 'DCTermsLocation',
        Groups => { 2 => 'Location' },
        FlatName => 'DC', # ('dctermsLocation' is too long)
        Struct => {
            STRUCT_NAME => 'DarwinCore DCTermsLocation',
            NAMESPACE => 'dwc',
            continent                   => { },
            coordinatePrecision         => { },
            coordinateUncertaintyInMeters => { },
            country                     => { },
            countryCode                 => { },
            county                      => { },
            decimalLatitude             => { },
            decimalLongitude            => { },
            footprintSpatialFit         => { },
            footprintSRS                => { },
            footprintWKT                => { },
            geodeticDatum               => { },
            georeferencedBy             => { },
            georeferencedDate           => { },
            georeferenceProtocol        => { },
            georeferenceRemarks         => { },
            georeferenceSources         => { },
            georeferenceVerificationStatus => { },
            higherGeography             => { },
            higherGeographyID           => { },
            island                      => { },
            islandGroup                 => { },
            locality                    => { },
            locationAccordingTo         => { },
            locationID                  => { },
            locationRemarks             => { },
            maximumDepthInMeters        => { },
            maximumDistanceAboveSurfaceInMeters => { },
            maximumElevationInMeters    => { },
            minimumDepthInMeters        => { },
            minimumDistanceAboveSurfaceInMeters => { },
            minimumElevationInMeters    => { },
            municipality                => { },
            pointRadiusSpatialFit       => { },
            stateProvince               => { },
            verbatimCoordinates         => { },
            verbatimCoordinateSystem    => { },
            verbatimDepth               => { },
            verbatimElevation           => { },
            verbatimLatitude            => { },
            verbatimLocality            => { },
            verbatimLongitude           => { },
            verbatimSRS                 => { },
            waterBody                   => { },
            # new, ref forum13707
            verticalDatum               => { },
        },
    },
);

1;  #end

__END__

=head1 NAME

Image::ExifTool::DarwinCore - Darwin Core XMP tags

=head1 SYNOPSIS

This module is used by Image::ExifTool

=head1 DESCRIPTION

This file contains tag definitions for the Darwin Core XMP namespace.

=head1 AUTHOR

Copyright 2003-2023, Phil Harvey (philharvey66 at gmail.com)

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 REFERENCES

=over 4

=item L<http://rs.tdwg.org/dwc/index.htm>

=back

=head1 SEE ALSO

L<Image::ExifTool::TagNames/XMP Tags>,
L<Image::ExifTool(3pm)|Image::ExifTool>

=cut
