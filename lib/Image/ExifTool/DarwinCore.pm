#------------------------------------------------------------------------------
# File:         DarwinCore.pm
#
# Description:  Darwin Core XMP tags
#
# Revisions:    2013-01-28 - P. Harvey Created
#
# References:   1) http://rs.tdwg.org/dwc/index.htm
#------------------------------------------------------------------------------

package Image::ExifTool::DarwinCore;

use strict;
use vars qw($VERSION);
use Image::ExifTool::XMP;

$VERSION = '1.01';

my %dateTimeInfo = (
    # NOTE: Do NOT put "Groups" here because Groups hash must not be common!
    Writable => 'date',
    Shift => 'Time',
    PrintConv => '$self->ConvertDateTime($val)',
    PrintConvInv => '$self->InverseDateTime($val,undef,1)',
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
        Struct => {
            STRUCT_NAME => 'DarwinCore Event',
            NAMESPACE => 'dwc',
            day                 => { Writable => 'integer', Groups => { 2 => 'Time' } },
            earliestDate        => { %dateTimeInfo, Groups => { 2 => 'Time' } },
            endDayOfYear        => { Writable => 'integer', Groups => { 2 => 'Time' } },
            eventID             => { },
            eventRemarks        => { Writable => 'lang-alt' },
            eventTime           => { %dateTimeInfo, Groups => { 2 => 'Time' } },
            fieldNotes          => { },
            fieldNumber         => { },
            habitat             => { },
            latestDate          => { %dateTimeInfo, Groups => { 2 => 'Time' } },
            month               => { Writable => 'integer', Groups => { 2 => 'Time' } },
            samplingEffort      => { },
            samplingProtocol    => { },
            startDayOfYear      => { Writable => 'integer', Groups => { 2 => 'Time' } },
            verbatimEventDate   => { Groups => { 2 => 'Time' } },
            year                => { Writable => 'integer', Groups => { 2 => 'Time' } },
        },
    },
    # tweak a few of the flattened tag names
    EventEventID      => { Name => 'EventID',       Flat => 1 },
    EventEventRemarks => { Name => 'EventRemarks',  Flat => 1 },
    EventEventTime    => { Name => 'EventTime',     Flat => 1 },
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
        },
    },
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
            otherCatalogNumbers         => { },
            preparations                => { },
            previousIdentifications     => { },
            recordedBy                  => { },
            recordNumber                => { },
            reproductiveCondition       => { },
            sex                         => { },
        },
    },
    OccurrenceOccurrenceRemarks => { Name => 'OccurrenceRemarks', Flat => 1 },
    OccurrenceOccurrenceDetails => { Name => 'OccurrenceDetails', Flat => 1 },
    OccurrenceOccurrenceID      => { Name => 'OccurrenceID',      Flat => 1 },
    OccurrenceOccurrenceStatus  => { Name => 'OccurrenceStatus',  Flat => 1 },
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

Copyright 2003-2016, Phil Harvey (phil at owl.phy.queensu.ca)

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
