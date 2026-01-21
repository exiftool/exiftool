package Archive::Zip::Archive;

# Represents a generic ZIP archive

use strict;
use File::Path;
use File::Find ();
use File::Spec ();
use File::Copy ();
use File::Basename;
use Cwd;
use Encode qw(encode_utf8 decode_utf8);

use vars qw( $VERSION @ISA );

BEGIN {
    $VERSION = '1.68';
    @ISA     = qw( Archive::Zip );
}

use Archive::Zip qw(
  :CONSTANTS
  :ERROR_CODES
  :PKZIP_CONSTANTS
  :UTILITY_METHODS
);

our $UNICODE;
our $UNTAINT = qr/\A(.+)\z/;

# Note that this returns undef on read errors, else new zip object.

sub new {
    my $class = shift;
    # Info-Zip 3.0 (I guess) seems to use the following values
    # for the version fields in the zip64 EOCD record:
    #
    #   version made by:
    #     30 (plus upper byte indicating host system)
    #
    #   version needed to extract:
    #     45
    my $self  = bless(
        {
            'zip64'                       => 0,
            'desiredZip64Mode'            => ZIP64_AS_NEEDED,
            'versionMadeBy'               => 0,
            'versionNeededToExtract'      => 0,
            'diskNumber'                  => 0,
            'diskNumberWithStartOfCentralDirectory' =>
              0,
            'numberOfCentralDirectoriesOnThisDisk' =>
              0,    # should be # of members
            'numberOfCentralDirectories'  => 0,   # should be # of members
            'centralDirectorySize'        => 0,   # must re-compute on write
            'centralDirectoryOffsetWRTStartingDiskNumber' =>
              0,                                  # must re-compute
            'writeEOCDOffset'             => 0,
            'writeCentralDirectoryOffset' => 0,
            'zipfileComment'              => '',
            'eocdOffset'                  => 0,
            'fileName'                    => ''
        },
        $class
    );
    $self->{'members'} = [];
    my $fileName = (ref($_[0]) eq 'HASH') ? shift->{filename} : shift;
    if ($fileName) {
        my $status = $self->read($fileName);
        return $status == AZ_OK ? $self : undef;
    }
    return $self;
}

sub storeSymbolicLink {
    my $self = shift;
    $self->{'storeSymbolicLink'} = shift;
}

sub members {
    @{shift->{'members'}};
}

sub numberOfMembers {
    scalar(shift->members());
}

sub memberNames {
    my $self = shift;
    return map { $_->fileName() } $self->members();
}

# return ref to member with given name or undef
sub memberNamed {
    my $self = shift;
    my $fileName = (ref($_[0]) eq 'HASH') ? shift->{zipName} : shift;
    foreach my $member ($self->members()) {
        return $member if $member->fileName() eq $fileName;
    }
    return undef;
}

sub membersMatching {
    my $self = shift;
    my $pattern = (ref($_[0]) eq 'HASH') ? shift->{regex} : shift;
    return grep { $_->fileName() =~ /$pattern/ } $self->members();
}

sub zip64 {
    shift->{'zip64'};
}

sub desiredZip64Mode {
    my $self = shift;
    my $desiredZip64Mode = $self->{'desiredZip64Mode'};
    if (@_) {
        $self->{'desiredZip64Mode'} =
          ref($_[0]) eq 'HASH' ? shift->{desiredZip64Mode} : shift;
    }
    return $desiredZip64Mode;
}

sub versionMadeBy {
    shift->{'versionMadeBy'};
}

sub versionNeededToExtract {
    shift->{'versionNeededToExtract'};
}

sub diskNumber {
    shift->{'diskNumber'};
}

sub diskNumberWithStartOfCentralDirectory {
    shift->{'diskNumberWithStartOfCentralDirectory'};
}

sub numberOfCentralDirectoriesOnThisDisk {
    shift->{'numberOfCentralDirectoriesOnThisDisk'};
}

sub numberOfCentralDirectories {
    shift->{'numberOfCentralDirectories'};
}

sub centralDirectorySize {
    shift->{'centralDirectorySize'};
}

sub centralDirectoryOffsetWRTStartingDiskNumber {
    shift->{'centralDirectoryOffsetWRTStartingDiskNumber'};
}

sub zipfileComment {
    my $self    = shift;
    my $comment = $self->{'zipfileComment'};
    if (@_) {
        my $new_comment = (ref($_[0]) eq 'HASH') ? shift->{comment} : shift;
        $self->{'zipfileComment'} = pack('C0a*', $new_comment);  # avoid Unicode
    }
    return $comment;
}

sub eocdOffset {
    shift->{'eocdOffset'};
}

# Return the name of the file last read.
sub fileName {
    shift->{'fileName'};
}

sub removeMember {
    my $self = shift;
    my $member = (ref($_[0]) eq 'HASH') ? shift->{memberOrZipName} : shift;
    $member = $self->memberNamed($member) unless ref($member);
    return undef unless $member;
    my @newMembers = grep { $_ != $member } $self->members();
    $self->{'members'} = \@newMembers;
    return $member;
}

sub replaceMember {
    my $self = shift;

    my ($oldMember, $newMember);
    if (ref($_[0]) eq 'HASH') {
        $oldMember = $_[0]->{memberOrZipName};
        $newMember = $_[0]->{newMember};
    } else {
        ($oldMember, $newMember) = @_;
    }

    $oldMember = $self->memberNamed($oldMember) unless ref($oldMember);
    return undef unless $oldMember;
    return undef unless $newMember;
    my @newMembers =
      map { ($_ == $oldMember) ? $newMember : $_ } $self->members();
    $self->{'members'} = \@newMembers;
    return $oldMember;
}

sub extractMember {
    my $self = shift;

    my ($member, $name);
    if (ref($_[0]) eq 'HASH') {
        $member = $_[0]->{memberOrZipName};
        $name   = $_[0]->{name};
    } else {
        ($member, $name) = @_;
    }

    $member = $self->memberNamed($member) unless ref($member);
    return _error('member not found') unless $member;
    my $originalSize = $member->compressedSize();
    my ($volumeName, $dirName, $fileName);
    if (defined($name)) {
        ($volumeName, $dirName, $fileName) = File::Spec->splitpath($name);
        $dirName = File::Spec->catpath($volumeName, $dirName, '');
    } else {
        $name = $member->fileName();
        if ((my $ret = _extractionNameIsSafe($name))
            != AZ_OK) { return $ret; }
        ($dirName = $name) =~ s{[^/]*$}{};
        $dirName = Archive::Zip::_asLocalName($dirName);
        $name    = Archive::Zip::_asLocalName($name);
    }
    if ($dirName && !-d $dirName) {
        mkpath($dirName);
        return _ioError("can't create dir $dirName") if (!-d $dirName);
    }
    my $rc = $member->extractToFileNamed($name, @_);

    # TODO refactor this fix into extractToFileNamed()
    $member->{'compressedSize'} = $originalSize;
    return $rc;
}

sub extractMemberWithoutPaths {
    my $self = shift;

    my ($member, $name);
    if (ref($_[0]) eq 'HASH') {
        $member = $_[0]->{memberOrZipName};
        $name   = $_[0]->{name};
    } else {
        ($member, $name) = @_;
    }

    $member = $self->memberNamed($member) unless ref($member);
    return _error('member not found') unless $member;
    my $originalSize = $member->compressedSize();
    return AZ_OK if $member->isDirectory();
    unless ($name) {
        $name = $member->fileName();
        $name =~ s{.*/}{};    # strip off directories, if any
        if ((my $ret = _extractionNameIsSafe($name))
            != AZ_OK) { return $ret; }
        $name = Archive::Zip::_asLocalName($name);
    }
    my $rc = $member->extractToFileNamed($name, @_);
    $member->{'compressedSize'} = $originalSize;
    return $rc;
}

sub addMember {
    my $self = shift;
    my $newMember = (ref($_[0]) eq 'HASH') ? shift->{member} : shift;
    push(@{$self->{'members'}}, $newMember) if $newMember;
    if($newMember && ($newMember->{bitFlag} & 0x800)
                  && !utf8::is_utf8($newMember->{fileName})){
        $newMember->{fileName} = Encode::decode_utf8($newMember->{fileName});
    }
    return $newMember;
}

sub addFile {
    my $self = shift;

    my ($fileName, $newName, $compressionLevel);
    if (ref($_[0]) eq 'HASH') {
        $fileName         = $_[0]->{filename};
        $newName          = $_[0]->{zipName};
        $compressionLevel = $_[0]->{compressionLevel};
    } else {
        ($fileName, $newName, $compressionLevel) = @_;
    }

    if ($^O eq 'MSWin32' && $Archive::Zip::UNICODE) {
        $fileName = Win32::GetANSIPathName($fileName);
    }

    my $newMember = Archive::Zip::Member->newFromFile($fileName, $newName);
    $newMember->desiredCompressionLevel($compressionLevel);
    if ($self->{'storeSymbolicLink'} && -l $fileName) {
        my $newMember =
          Archive::Zip::Member->newFromString(readlink $fileName, $newName);

  # For symbolic links, External File Attribute is set to 0xA1FF0000 by Info-ZIP
        $newMember->{'externalFileAttributes'} = 0xA1FF0000;
        $self->addMember($newMember);
    } else {
        $self->addMember($newMember);
    }

    return $newMember;
}

sub addString {
    my $self = shift;

    my ($stringOrStringRef, $name, $compressionLevel);
    if (ref($_[0]) eq 'HASH') {
        $stringOrStringRef = $_[0]->{string};
        $name              = $_[0]->{zipName};
        $compressionLevel  = $_[0]->{compressionLevel};
    } else {
        ($stringOrStringRef, $name, $compressionLevel) = @_;
    }

    my $newMember =
      Archive::Zip::Member->newFromString($stringOrStringRef, $name);
    $newMember->desiredCompressionLevel($compressionLevel);
    return $self->addMember($newMember);
}

sub addDirectory {
    my $self = shift;

    my ($name, $newName);
    if (ref($_[0]) eq 'HASH') {
        $name    = $_[0]->{directoryName};
        $newName = $_[0]->{zipName};
    } else {
        ($name, $newName) = @_;
    }

    if ($^O eq 'MSWin32' && $Archive::Zip::UNICODE) {
        $name = Win32::GetANSIPathName($name);
    }

    my $newMember = Archive::Zip::Member->newDirectoryNamed($name, $newName);
    if ($self->{'storeSymbolicLink'} && -l $name) {
        my $link = readlink $name;
        ($newName =~ s{/$}{}) if $newName;    # Strip trailing /
        my $newMember = Archive::Zip::Member->newFromString($link, $newName);

  # For symbolic links, External File Attribute is set to 0xA1FF0000 by Info-ZIP
        $newMember->{'externalFileAttributes'} = 0xA1FF0000;
        $self->addMember($newMember);
    } else {
        $self->addMember($newMember);
    }

    return $newMember;
}

# add either a file or a directory.

sub addFileOrDirectory {
    my $self = shift;

    my ($name, $newName, $compressionLevel);
    if (ref($_[0]) eq 'HASH') {
        $name             = $_[0]->{name};
        $newName          = $_[0]->{zipName};
        $compressionLevel = $_[0]->{compressionLevel};
    } else {
        ($name, $newName, $compressionLevel) = @_;
    }

    if ($^O eq 'MSWin32' && $Archive::Zip::UNICODE) {
        $name = Win32::GetANSIPathName($name);
    }

    $name =~ s{/$}{};
    if ($newName) {
        $newName =~ s{/$}{};
    } else {
        $newName = $name;
    }
    if (-f $name) {
        return $self->addFile($name, $newName, $compressionLevel);
    } elsif (-d $name) {
        return $self->addDirectory($name, $newName);
    } else {
        return _error("$name is neither a file nor a directory");
    }
}

sub contents {
    my $self = shift;

    my ($member, $newContents);
    if (ref($_[0]) eq 'HASH') {
        $member      = $_[0]->{memberOrZipName};
        $newContents = $_[0]->{contents};
    } else {
        ($member, $newContents) = @_;
    }

    my ($contents, $status) = (undef, AZ_OK);
    if ($status == AZ_OK) {
        $status = _error('No member name given') unless defined($member);
    }
    if ($status == AZ_OK && ! ref($member)) {
        my $memberName = $member;
        $member = $self->memberNamed($memberName);
        $status = _error('No member named $memberName') unless defined($member);
    }
    if ($status == AZ_OK) {
        ($contents, $status) = $member->contents($newContents);
    }

    return
      wantarray
      ? ($contents, $status)
      : $contents;
}

sub writeToFileNamed {
    my $self = shift;
    my $fileName =
      (ref($_[0]) eq 'HASH') ? shift->{filename} : shift;    # local FS format
    foreach my $member ($self->members()) {
        if ($member->_usesFileNamed($fileName)) {
            return _error("$fileName is needed by member "
                  . $member->fileName()
                  . "; consider using overwrite() or overwriteAs() instead.");
        }
    }
    my ($status, $fh) = _newFileHandle($fileName, 'w');
    return _ioError("Can't open $fileName for write") unless $status;
    $status = $self->writeToFileHandle($fh, 1);
    $fh->close();
    $fh = undef;

    return $status;
}

# It is possible to write data to the FH before calling this,
# perhaps to make a self-extracting archive.
sub writeToFileHandle {
    my $self = shift;

    my ($fh, $fhIsSeekable);
    if (ref($_[0]) eq 'HASH') {
        $fh = $_[0]->{fileHandle};
        $fhIsSeekable =
          exists($_[0]->{seek}) ? $_[0]->{seek} : _isSeekable($fh);
    } else {
        $fh = shift;
        $fhIsSeekable = @_ ? shift : _isSeekable($fh);
    }

    return _error('No filehandle given')   unless $fh;
    return _ioError('filehandle not open') unless $fh->opened();
    _binmode($fh);

    # Find out where the current position is.
    my $offset = $fhIsSeekable ? $fh->tell() : 0;
    $offset = 0 if $offset < 0;

    # (Re-)set the "was-successfully-written" flag so that the
    # contract advertised in the documentation ("that member and
    # *all following it* will return false from wasWritten()")
    # also holds for members written more than once.
    #
    # Not sure whether that mechanism works, anyway.  If method
    # $member->_writeToFileHandle fails with an error below and
    # user continues with calling $zip->writeCentralDirectory
    # manually, we should end up with the following picture
    # unless the user seeks back to writeCentralDirectoryOffset:
    #
    #   ...
    #   [last successfully written member]
    #      <- writeCentralDirectoryOffset points here
    #   [half-written member junk with unknown size]
    #   [central directory entry 0]
    #   ...
    foreach my $member ($self->members()) {
        $member->{'wasWritten'} = 0;
    }

    foreach my $member ($self->members()) {

        # (Re-)set object member zip64 flag.  Here is what
        # happens next to that flag:
        #
        #   $member->_writeToFileHandle
        #       Determines a local flag value depending on
        #       necessity and user desire and ors it to
        #       the object member
        #     $member->_writeLocalFileHeader
        #         Queries the object member to write appropriate
        #         local header
        #     $member->_writeDataDescriptor
        #         Queries the object member to write appropriate
        #         data descriptor
        #   $member->_writeCentralDirectoryFileHeader
        #       Determines a local flag value depending on
        #       necessity and user desire.  Writes a central
        #       directory header appropriate to the local flag.
        #       Ors the local flag to the object member.
        $member->{'zip64'} = 0;

        my ($status, $memberSize) =
          $member->_writeToFileHandle($fh, $fhIsSeekable, $offset,
                                      $self->desiredZip64Mode());
        $member->endRead();
        return $status if $status != AZ_OK;

        $offset += $memberSize;

        # Change this so it reflects write status and last
        # successful position
        $member->{'wasWritten'} = 1;
        $self->{'writeCentralDirectoryOffset'} = $offset;
    }

    return $self->writeCentralDirectory($fh);
}

# Write zip back to the original file,
# as safely as possible.
# Returns AZ_OK if successful.
sub overwrite {
    my $self = shift;
    return $self->overwriteAs($self->{'fileName'});
}

# Write zip to the specified file,
# as safely as possible.
# Returns AZ_OK if successful.
sub overwriteAs {
    my $self = shift;
    my $zipName = (ref($_[0]) eq 'HASH') ? $_[0]->{filename} : shift;
    return _error("no filename in overwriteAs()") unless defined($zipName);

    my ($fh, $tempName) = Archive::Zip::tempFile();
    return _error("Can't open temp file", $!) unless $fh;

    (my $backupName = $zipName) =~ s{(\.[^.]*)?$}{.zbk};

    my $status = $self->writeToFileHandle($fh);
    $fh->close();
    $fh = undef;

    if ($status != AZ_OK) {
        unlink($tempName);
        _printError("Can't write to $tempName");
        return $status;
    }

    my $err;

    # rename the zip
    if (-f $zipName && !rename($zipName, $backupName)) {
        $err = $!;
        unlink($tempName);
        return _error("Can't rename $zipName as $backupName", $err);
    }

    # move the temp to the original name (possibly copying)
    unless (File::Copy::move($tempName, $zipName)
        || File::Copy::copy($tempName, $zipName)) {
        $err = $!;
        rename($backupName, $zipName);
        unlink($tempName);
        return _error("Can't move $tempName to $zipName", $err);
    }

    # unlink the backup
    if (-f $backupName && !unlink($backupName)) {
        $err = $!;
        return _error("Can't unlink $backupName", $err);
    }

    return AZ_OK;
}

# Used only during writing
sub _writeCentralDirectoryOffset {
    shift->{'writeCentralDirectoryOffset'};
}

sub _writeEOCDOffset {
    shift->{'writeEOCDOffset'};
}

# Expects to have _writeEOCDOffset() set
sub _writeEndOfCentralDirectory {
    my ($self, $fh, $membersZip64) = @_;

    my $zip64                                 = 0;
    my $versionMadeBy                         = $self->versionMadeBy();
    my $versionNeededToExtract                = $self->versionNeededToExtract();
    my $diskNumber                            = 0;
    my $diskNumberWithStartOfCentralDirectory = 0;
    my $numberOfCentralDirectoriesOnThisDisk  = $self->numberOfMembers();
    my $numberOfCentralDirectories            = $self->numberOfMembers();
    my $centralDirectorySize =
      $self->_writeEOCDOffset() - $self->_writeCentralDirectoryOffset();
    my $centralDirectoryOffsetWRTStartingDiskNumber =
      $self->_writeCentralDirectoryOffset();
    my $zipfileCommentLength                  = length($self->zipfileComment());

    my $eocdDataZip64 = 0;
    $eocdDataZip64 ||= $numberOfCentralDirectoriesOnThisDisk > 0xffff;
    $eocdDataZip64 ||= $numberOfCentralDirectories > 0xffff;
    $eocdDataZip64 ||= $centralDirectorySize > 0xffffffff;
    $eocdDataZip64 ||= $centralDirectoryOffsetWRTStartingDiskNumber > 0xffffffff;

    if (   $membersZip64
        || $eocdDataZip64
        || $self->desiredZip64Mode() == ZIP64_EOCD) {
        return _zip64NotSupported() unless ZIP64_SUPPORTED;

        $zip64                  = 1;
        $versionMadeBy          = 45 if ($versionMadeBy == 0);
        $versionNeededToExtract = 45 if ($versionNeededToExtract < 45);

        $self->_print($fh, ZIP64_END_OF_CENTRAL_DIRECTORY_RECORD_SIGNATURE_STRING)
          or return _ioError('writing zip64 EOCD record signature');

        my $record = pack(
            ZIP64_END_OF_CENTRAL_DIRECTORY_RECORD_FORMAT,
            ZIP64_END_OF_CENTRAL_DIRECTORY_RECORD_LENGTH +
            SIGNATURE_LENGTH - 12,
            $versionMadeBy,
            $versionNeededToExtract,
            $diskNumber,
            $diskNumberWithStartOfCentralDirectory,
            $numberOfCentralDirectoriesOnThisDisk,
            $numberOfCentralDirectories,
            $centralDirectorySize,
            $centralDirectoryOffsetWRTStartingDiskNumber
        );
        $self->_print($fh, $record)
          or return _ioError('writing zip64 EOCD record');

        $self->_print($fh, ZIP64_END_OF_CENTRAL_DIRECTORY_LOCATOR_SIGNATURE_STRING)
          or return _ioError('writing zip64 EOCD locator signature');

        my $locator = pack(
            ZIP64_END_OF_CENTRAL_DIRECTORY_LOCATOR_FORMAT,
            0,
            $self->_writeEOCDOffset(),
            1
        );
        $self->_print($fh, $locator)
          or return _ioError('writing zip64 EOCD locator');
    }

    $self->_print($fh, END_OF_CENTRAL_DIRECTORY_SIGNATURE_STRING)
      or return _ioError('writing EOCD Signature');

    my $header = pack(
        END_OF_CENTRAL_DIRECTORY_FORMAT,
        $diskNumber,
        $diskNumberWithStartOfCentralDirectory,
        $numberOfCentralDirectoriesOnThisDisk > 0xffff
          ? 0xffff : $numberOfCentralDirectoriesOnThisDisk,
        $numberOfCentralDirectories > 0xffff
          ? 0xffff : $numberOfCentralDirectories,
        $centralDirectorySize > 0xffffffff
          ? 0xffffffff : $centralDirectorySize,
        $centralDirectoryOffsetWRTStartingDiskNumber > 0xffffffff
          ? 0xffffffff : $centralDirectoryOffsetWRTStartingDiskNumber,
        $zipfileCommentLength
    );
    $self->_print($fh, $header)
      or return _ioError('writing EOCD header');
    if ($zipfileCommentLength) {
        $self->_print($fh, $self->zipfileComment())
          or return _ioError('writing zipfile comment');
    }

    # Adjust object members related to zip64 format
    $self->{'zip64'}                  = $zip64;
    $self->{'versionMadeBy'}          = $versionMadeBy;
    $self->{'versionNeededToExtract'} = $versionNeededToExtract;

    return AZ_OK;
}

# $offset can be specified to truncate a zip file.
sub writeCentralDirectory {
    my $self = shift;

    my ($fh, $offset);
    if (ref($_[0]) eq 'HASH') {
        $fh     = $_[0]->{fileHandle};
        $offset = $_[0]->{offset};
    } else {
        ($fh, $offset) = @_;
    }

    if (defined($offset)) {
        $self->{'writeCentralDirectoryOffset'} = $offset;
        $fh->seek($offset, IO::Seekable::SEEK_SET)
          or return _ioError('seeking to write central directory');
    } else {
        $offset = $self->_writeCentralDirectoryOffset();
    }

    my $membersZip64 = 0;
    foreach my $member ($self->members()) {
        my ($status, $headerSize) =
          $member->_writeCentralDirectoryFileHeader($fh, $self->desiredZip64Mode());
        return $status if $status != AZ_OK;
        $membersZip64 ||= $member->zip64();
        $offset += $headerSize;
        $self->{'writeEOCDOffset'} = $offset;
    }

    return $self->_writeEndOfCentralDirectory($fh, $membersZip64);
}

sub read {
    my $self = shift;
    my $fileName = (ref($_[0]) eq 'HASH') ? shift->{filename} : shift;
    return _error('No filename given') unless $fileName;
    my ($status, $fh) = _newFileHandle($fileName, 'r');
    return _ioError("opening $fileName for read") unless $status;

    $status = $self->readFromFileHandle($fh, $fileName);
    return $status if $status != AZ_OK;

    $fh->close();
    $self->{'fileName'} = $fileName;
    return AZ_OK;
}

sub readFromFileHandle {
    my $self = shift;

    my ($fh, $fileName);
    if (ref($_[0]) eq 'HASH') {
        $fh       = $_[0]->{fileHandle};
        $fileName = $_[0]->{filename};
    } else {
        ($fh, $fileName) = @_;
    }

    $fileName = $fh unless defined($fileName);
    return _error('No filehandle given')   unless $fh;
    return _ioError('filehandle not open') unless $fh->opened();

    _binmode($fh);
    $self->{'fileName'} = "$fh";

    # TODO: how to support non-seekable zips?
    return _error('file not seekable')
      unless _isSeekable($fh);

    $fh->seek(0, 0);    # rewind the file

    my $status = $self->_findEndOfCentralDirectory($fh);
    return $status if $status != AZ_OK;

    my $eocdPosition;
    ($status, $eocdPosition) = $self->_readEndOfCentralDirectory($fh, $fileName);
    return $status if $status != AZ_OK;

    my $zip64 = $self->zip64();

    $fh->seek($eocdPosition - $self->centralDirectorySize(),
        IO::Seekable::SEEK_SET)
      or return _ioError("Can't seek $fileName");

    # Try to detect garbage at beginning of archives
    # This should be 0
    $self->{'eocdOffset'} = $eocdPosition - $self->centralDirectorySize() # here
      - $self->centralDirectoryOffsetWRTStartingDiskNumber();

    for (; ;) {
        my $newMember =
          Archive::Zip::Member->_newFromZipFile($fh, $fileName, $zip64,
            $self->eocdOffset());
        my $signature;
        ($status, $signature) = _readSignature($fh, $fileName);
        return $status if $status != AZ_OK;
        if (! $zip64) {
            last if $signature == END_OF_CENTRAL_DIRECTORY_SIGNATURE;
        }
        else {
            last if $signature == ZIP64_END_OF_CENTRAL_DIRECTORY_RECORD_SIGNATURE;
        }
        $status = $newMember->_readCentralDirectoryFileHeader();
        return $status if $status != AZ_OK;
        $status = $newMember->endRead();
        return $status if $status != AZ_OK;

        if ($newMember->isDirectory()) {
            $newMember->_become('Archive::Zip::DirectoryMember');
            # Ensure above call suceeded to avoid future trouble
            $newMember->_ISA('Archive::Zip::DirectoryMember') or
              return $self->_error('becoming Archive::Zip::DirectoryMember');
        }

        if(($newMember->{bitFlag} & 0x800) && !utf8::is_utf8($newMember->{fileName})){
            $newMember->{fileName} = Encode::decode_utf8($newMember->{fileName});
        }

        push(@{$self->{'members'}}, $newMember);
    }

    return AZ_OK;
}

# Read EOCD, starting from position before signature.
# Checks for a zip64 EOCD record and uses that if present.
#
# Return AZ_OK (in scalar context) or a pair (AZ_OK,
# $eocdPosition) (in list context) on success:
# ( $status, $eocdPosition ) = $zip->_readEndOfCentralDirectory( $fh, $fileName );
# where the returned EOCD position either points to the beginning
# of the EOCD or to the beginning of the zip64 EOCD record.
#
# APPNOTE.TXT as of version 6.3.6 is a bit vague on the
# "ZIP64(tm) format".  It has a lot of conditions like "if an
# archive is in ZIP64 format", but never explicitly mentions
# *when* an archive is in that format.  (Or at least I haven't
# found it.)
#
# So I decided that an archive is in ZIP64 format if zip64 EOCD
# locator and zip64 EOCD record are present before the EOCD with
# the format given in the specification.
sub _readEndOfCentralDirectory {
    my $self     = shift;
    my $fh       = shift;
    my $fileName = shift;

    # Remember current position, which is just before the EOCD
    # signature
    my $eocdPosition = $fh->tell();

    # Reset the zip64 format flag
    $self->{'zip64'} = 0;
    my $zip64EOCDPosition;

    # Check for zip64 EOCD locator and zip64 EOCD record.  Be
    # extra careful here to not interpret any random data as
    # zip64 data structures.  If in doubt, silently continue
    # reading the regular EOCD.
  NOZIP64:
    {
        # Do not even start looking for any zip64 structures if
        # that would not be supported.
        if (! ZIP64_SUPPORTED) {
            last NOZIP64;
        }

        if ($eocdPosition < ZIP64_END_OF_CENTRAL_DIRECTORY_LOCATOR_LENGTH + SIGNATURE_LENGTH) {
            last NOZIP64;
        }

        # Skip to before potential zip64 EOCD locator
        $fh->seek(-(ZIP64_END_OF_CENTRAL_DIRECTORY_LOCATOR_LENGTH) - SIGNATURE_LENGTH,
                  IO::Seekable::SEEK_CUR)
          or return _ioError("seeking to before zip 64 EOCD locator");
        my $zip64EOCDLocatorPosition =
          $eocdPosition - ZIP64_END_OF_CENTRAL_DIRECTORY_LOCATOR_LENGTH - SIGNATURE_LENGTH;

        my $status;
        my $bytesRead;

        # Read potential zip64 EOCD locator signature
        $status =
          _readSignature($fh, $fileName,
                         ZIP64_END_OF_CENTRAL_DIRECTORY_LOCATOR_SIGNATURE, 1);
        return $status if $status == AZ_IO_ERROR;
        if ($status == AZ_FORMAT_ERROR) {
            $fh->seek($eocdPosition, IO::Seekable::SEEK_SET)
              or return _ioError("seeking to EOCD");
            last NOZIP64;
        }

        # Read potential zip64 EOCD locator and verify it
        my $locator = '';
        $bytesRead = $fh->read($locator, ZIP64_END_OF_CENTRAL_DIRECTORY_LOCATOR_LENGTH);
        if ($bytesRead != ZIP64_END_OF_CENTRAL_DIRECTORY_LOCATOR_LENGTH) {
            return _ioError("reading zip64 EOCD locator");
        }
        (undef, $zip64EOCDPosition, undef) =
          unpack(ZIP64_END_OF_CENTRAL_DIRECTORY_LOCATOR_FORMAT, $locator);
        if ($zip64EOCDPosition >
            ($zip64EOCDLocatorPosition - ZIP64_END_OF_CENTRAL_DIRECTORY_RECORD_LENGTH - SIGNATURE_LENGTH)) {
            # No need to seek to EOCD since we're already there
            last NOZIP64;
        }

        # Skip to potential zip64 EOCD record
        $fh->seek($zip64EOCDPosition, IO::Seekable::SEEK_SET)
          or return _ioError("seeking to zip64 EOCD record");

        # Read potential zip64 EOCD record signature
        $status =
          _readSignature($fh, $fileName,
                         ZIP64_END_OF_CENTRAL_DIRECTORY_RECORD_SIGNATURE, 1);
        return $status if $status == AZ_IO_ERROR;
        if ($status == AZ_FORMAT_ERROR) {
            $fh->seek($eocdPosition, IO::Seekable::SEEK_SET)
              or return _ioError("seeking to EOCD");
            last NOZIP64;
        }

        # Read potential zip64 EOCD record.  Ignore the zip64
        # extensible data sector.
        my $record = '';
        $bytesRead = $fh->read($record, ZIP64_END_OF_CENTRAL_DIRECTORY_RECORD_LENGTH);
        if ($bytesRead != ZIP64_END_OF_CENTRAL_DIRECTORY_RECORD_LENGTH) {
            return _ioError("reading zip64 EOCD record");
        }

        # Perform one final check, hoping that all implementors
        # follow the recommendation of the specification
        # regarding the size of the zip64 EOCD record
        my ($zip64EODCRecordSize) = unpack("Q<", $record);
        if ($zip64EOCDPosition + 12 + $zip64EODCRecordSize != $zip64EOCDLocatorPosition) {
            $fh->seek($eocdPosition, IO::Seekable::SEEK_SET)
              or return _ioError("seeking to EOCD");
            last NOZIP64;
        }

        $self->{'zip64'} = 1;
        (
            undef,
            $self->{'versionMadeBy'},
            $self->{'versionNeededToExtract'},
            $self->{'diskNumber'},
            $self->{'diskNumberWithStartOfCentralDirectory'},
            $self->{'numberOfCentralDirectoriesOnThisDisk'},
            $self->{'numberOfCentralDirectories'},
            $self->{'centralDirectorySize'},
            $self->{'centralDirectoryOffsetWRTStartingDiskNumber'}
        ) = unpack(ZIP64_END_OF_CENTRAL_DIRECTORY_RECORD_FORMAT, $record);

        # Don't just happily bail out, we still need to read the
        # zip file comment!
        $fh->seek($eocdPosition, IO::Seekable::SEEK_SET)
          or return _ioError("seeking to EOCD");
    }

    # Skip past signature
    $fh->seek(SIGNATURE_LENGTH, IO::Seekable::SEEK_CUR)
      or return _ioError("seeking past EOCD signature");

    my $header = '';
    my $bytesRead = $fh->read($header, END_OF_CENTRAL_DIRECTORY_LENGTH);
    if ($bytesRead != END_OF_CENTRAL_DIRECTORY_LENGTH) {
        return _ioError("reading end of central directory");
    }

    my $zipfileCommentLength;
    if (! $self->{'zip64'}) {
        (
            $self->{'diskNumber'},
            $self->{'diskNumberWithStartOfCentralDirectory'},
            $self->{'numberOfCentralDirectoriesOnThisDisk'},
            $self->{'numberOfCentralDirectories'},
            $self->{'centralDirectorySize'},
            $self->{'centralDirectoryOffsetWRTStartingDiskNumber'},
            $zipfileCommentLength
        ) = unpack(END_OF_CENTRAL_DIRECTORY_FORMAT, $header);

        if (   $self->{'diskNumber'}                                  == 0xffff
            || $self->{'diskNumberWithStartOfCentralDirectory'}       == 0xffff
            || $self->{'numberOfCentralDirectoriesOnThisDisk'}        == 0xffff
            || $self->{'numberOfCentralDirectories'}                  == 0xffff
            || $self->{'centralDirectorySize'}                        == 0xffffffff
            || $self->{'centralDirectoryOffsetWRTStartingDiskNumber'} == 0xffffffff) {
            if (ZIP64_SUPPORTED) {
                return _formatError("unexpected zip64 marker values in EOCD");
            }
            else {
                return _zip64NotSupported();
            }
        }
    }
    else {
        (
            undef,
            undef,
            undef,
            undef,
            undef,
            undef,
            $zipfileCommentLength
        ) = unpack(END_OF_CENTRAL_DIRECTORY_FORMAT, $header);
    }

    if ($zipfileCommentLength) {
        my $zipfileComment = '';
        $bytesRead = $fh->read($zipfileComment, $zipfileCommentLength);
        if ($bytesRead != $zipfileCommentLength) {
            return _ioError("reading zipfile comment");
        }
        $self->{'zipfileComment'} = $zipfileComment;
    }

    if (! $self->{'zip64'}) {
        return
          wantarray
          ? (AZ_OK, $eocdPosition)
          : AZ_OK;
    }
    else {
        return
          wantarray
          ? (AZ_OK, $zip64EOCDPosition)
          : AZ_OK;
    }
}

# Seek in my file to the end, then read backwards until we find the
# signature of the central directory record. Leave the file positioned right
# before the signature. Returns AZ_OK if success.
sub _findEndOfCentralDirectory {
    my $self = shift;
    my $fh   = shift;
    my $data = '';
    $fh->seek(0, IO::Seekable::SEEK_END)
      or return _ioError("seeking to end");

    my $fileLength = $fh->tell();
    if ($fileLength < END_OF_CENTRAL_DIRECTORY_LENGTH + 4) {
        return _formatError("file is too short");
    }

    my $seekOffset = 0;
    my $pos        = -1;
    for (; ;) {
        $seekOffset += 512;
        $seekOffset = $fileLength if ($seekOffset > $fileLength);
        $fh->seek(-$seekOffset, IO::Seekable::SEEK_END)
          or return _ioError("seek failed");
        my $bytesRead = $fh->read($data, $seekOffset);
        if ($bytesRead != $seekOffset) {
            return _ioError("read failed");
        }
        $pos = rindex($data, END_OF_CENTRAL_DIRECTORY_SIGNATURE_STRING);
        last
          if ( $pos >= 0
            or $seekOffset == $fileLength
            or $seekOffset >= $Archive::Zip::ChunkSize);
    }

    if ($pos >= 0) {
        $fh->seek($pos - $seekOffset, IO::Seekable::SEEK_CUR)
          or return _ioError("seeking to EOCD");
        return AZ_OK;
    } else {
        return _formatError("can't find EOCD signature");
    }
}

# Used to avoid taint problems when chdir'ing.
# Not intended to increase security in any way; just intended to shut up the -T
# complaints.  If your Cwd module is giving you unreliable returns from cwd()
# you have bigger problems than this.
sub _untaintDir {
    my $dir = shift;
    $dir =~ m/$UNTAINT/s;
    return $1;
}

sub addTree {
    my $self = shift;

    my ($root, $dest, $pred, $compressionLevel);
    if (ref($_[0]) eq 'HASH') {
        $root             = $_[0]->{root};
        $dest             = $_[0]->{zipName};
        $pred             = $_[0]->{select};
        $compressionLevel = $_[0]->{compressionLevel};
    } else {
        ($root, $dest, $pred, $compressionLevel) = @_;
    }

    return _error("root arg missing in call to addTree()")
      unless defined($root);
    $dest = '' unless defined($dest);
    $pred = sub { -r }
      unless defined($pred);

    my @files;
    my $startDir = _untaintDir(cwd());

    return _error('undef returned by _untaintDir on cwd ', cwd())
      unless $startDir;

    # This avoids chdir'ing in Find, in a way compatible with older
    # versions of File::Find.
    my $wanted = sub {
        local $main::_ = $File::Find::name;
        my $dir = _untaintDir($File::Find::dir);
        chdir($startDir);
        if ($^O eq 'MSWin32' && $Archive::Zip::UNICODE) {
            push(@files, Win32::GetANSIPathName($File::Find::name)) if (&$pred);
            $dir = Win32::GetANSIPathName($dir);
        } else {
            push(@files, $File::Find::name) if (&$pred);
        }
        chdir($dir);
    };

    if ($^O eq 'MSWin32' && $Archive::Zip::UNICODE) {
        $root = Win32::GetANSIPathName($root);
    }
    # File::Find will not untaint unless you explicitly pass the flag and regex pattern.
    File::Find::find({ wanted => $wanted, untaint => 1, untaint_pattern => $UNTAINT }, $root);

    my $rootZipName = _asZipDirName($root, 1);    # with trailing slash
    my $pattern = $rootZipName eq './' ? '^' : "^\Q$rootZipName\E";

    $dest = _asZipDirName($dest, 1);              # with trailing slash

    foreach my $fileName (@files) {
        my $isDir;
        if ($^O eq 'MSWin32' && $Archive::Zip::UNICODE) {
            $isDir = -d Win32::GetANSIPathName($fileName);
        } else {
            $isDir = -d $fileName;
        }

        # normalize, remove leading ./
        my $archiveName = _asZipDirName($fileName, $isDir);
        if ($archiveName eq $rootZipName) { $archiveName = $dest }
        else                              { $archiveName =~ s{$pattern}{$dest} }
        next if $archiveName =~ m{^\.?/?$};    # skip current dir
        my $member =
            $isDir
          ? $self->addDirectory($fileName, $archiveName)
          : $self->addFile($fileName, $archiveName);
        $member->desiredCompressionLevel($compressionLevel);

        return _error("add $fileName failed in addTree()") if !$member;
    }
    return AZ_OK;
}

sub addTreeMatching {
    my $self = shift;

    my ($root, $dest, $pattern, $pred, $compressionLevel);
    if (ref($_[0]) eq 'HASH') {
        $root             = $_[0]->{root};
        $dest             = $_[0]->{zipName};
        $pattern          = $_[0]->{pattern};
        $pred             = $_[0]->{select};
        $compressionLevel = $_[0]->{compressionLevel};
    } else {
        ($root, $dest, $pattern, $pred, $compressionLevel) = @_;
    }

    return _error("root arg missing in call to addTreeMatching()")
      unless defined($root);
    $dest = '' unless defined($dest);
    return _error("pattern missing in call to addTreeMatching()")
      unless defined($pattern);
    my $matcher =
      $pred ? sub { m{$pattern} && &$pred } : sub { m{$pattern} && -r };
    return $self->addTree($root, $dest, $matcher, $compressionLevel);
}

# Check if one of the components of a path to the file or the file name
# itself is an already existing symbolic link. If yes then return an
# error. Continuing and writing to a file traversing a link posseses
# a security threat, especially if the link was extracted from an
# attacker-supplied archive. This would allow writing to an arbitrary
# file. The same applies when using ".." to escape from a working
# directory. <https://bugzilla.redhat.com/show_bug.cgi?id=1591449>
sub _extractionNameIsSafe {
    my $name = shift;
    my ($volume, $directories) = File::Spec->splitpath($name, 1);
    my @directories = File::Spec->splitdir($directories);
    if (grep '..' eq $_, @directories) {
        return _error(
            "Could not extract $name safely: a parent directory is used");
    }
    my @path;
    my $path;
    for my $directory (@directories) {
        push @path, $directory;
        $path = File::Spec->catpath($volume, File::Spec->catdir(@path), '');
        if (-l $path) {
            return _error(
                "Could not extract $name safely: $path is an existing symbolic link");
        }
        if (!-e $path) {
            last;
        }
    }
    return AZ_OK;
}

# $zip->extractTree( $root, $dest [, $volume] );
#
# $root and $dest are Unix-style.
# $volume is in local FS format.
#
sub extractTree {
    my $self = shift;

    my ($root, $dest, $volume);
    if (ref($_[0]) eq 'HASH') {
        $root   = $_[0]->{root};
        $dest   = $_[0]->{zipName};
        $volume = $_[0]->{volume};
    } else {
        ($root, $dest, $volume) = @_;
    }

    $root = '' unless defined($root);
    if (defined $dest) {
        if ($dest !~ m{/$}) {
            $dest .= '/';
        }
    } else {
        $dest = './';
    }

    my $pattern = "^\Q$root";
    my @members = $self->membersMatching($pattern);

    foreach my $member (@members) {
        my $fileName = $member->fileName();    # in Unix format
        $fileName =~ s{$pattern}{$dest};       # in Unix format
                                               # convert to platform format:
        $fileName = Archive::Zip::_asLocalName($fileName, $volume);
        if ((my $ret = _extractionNameIsSafe($fileName))
            != AZ_OK) { return $ret; }
        my $status = $member->extractToFileNamed($fileName);
        return $status if $status != AZ_OK;
    }
    return AZ_OK;
}

# $zip->updateMember( $memberOrName, $fileName );
# Returns (possibly updated) member, if any; undef on errors.

sub updateMember {
    my $self = shift;

    my ($oldMember, $fileName);
    if (ref($_[0]) eq 'HASH') {
        $oldMember = $_[0]->{memberOrZipName};
        $fileName  = $_[0]->{name};
    } else {
        ($oldMember, $fileName) = @_;
    }

    if (!defined($fileName)) {
        _error("updateMember(): missing fileName argument");
        return undef;
    }

    my @newStat = stat($fileName);
    if (!@newStat) {
        _ioError("Can't stat $fileName");
        return undef;
    }

    my $isDir = -d _;

    my $memberName;

    if (ref($oldMember)) {
        $memberName = $oldMember->fileName();
    } else {
        $oldMember = $self->memberNamed($memberName = $oldMember)
          || $self->memberNamed($memberName =
              _asZipDirName($oldMember, $isDir));
    }

    unless (defined($oldMember)
        && $oldMember->lastModTime() == $newStat[9]
        && $oldMember->isDirectory() == $isDir
        && ($isDir || ($oldMember->uncompressedSize() == $newStat[7]))) {

        # create the new member
        my $newMember =
            $isDir
          ? Archive::Zip::Member->newDirectoryNamed($fileName, $memberName)
          : Archive::Zip::Member->newFromFile($fileName, $memberName);

        unless (defined($newMember)) {
            _error("creation of member $fileName failed in updateMember()");
            return undef;
        }

        # replace old member or append new one
        if (defined($oldMember)) {
            $self->replaceMember($oldMember, $newMember);
        } else {
            $self->addMember($newMember);
        }

        return $newMember;
    }

    return $oldMember;
}

# $zip->updateTree( $root, [ $dest, [ $pred [, $mirror]]] );
#
# This takes the same arguments as addTree, but first checks to see
# whether the file or directory already exists in the zip file.
#
# If the fourth argument $mirror is true, then delete all my members
# if corresponding files were not found.

sub updateTree {
    my $self = shift;

    my ($root, $dest, $pred, $mirror, $compressionLevel);
    if (ref($_[0]) eq 'HASH') {
        $root             = $_[0]->{root};
        $dest             = $_[0]->{zipName};
        $pred             = $_[0]->{select};
        $mirror           = $_[0]->{mirror};
        $compressionLevel = $_[0]->{compressionLevel};
    } else {
        ($root, $dest, $pred, $mirror, $compressionLevel) = @_;
    }

    return _error("root arg missing in call to updateTree()")
      unless defined($root);
    $dest = '' unless defined($dest);
    $pred = sub { -r }
      unless defined($pred);

    $dest = _asZipDirName($dest, 1);
    my $rootZipName = _asZipDirName($root, 1);    # with trailing slash
    my $pattern = $rootZipName eq './' ? '^' : "^\Q$rootZipName\E";

    my @files;
    my $startDir = _untaintDir(cwd());

    return _error('undef returned by _untaintDir on cwd ', cwd())
      unless $startDir;

    # This avoids chdir'ing in Find, in a way compatible with older
    # versions of File::Find.
    my $wanted = sub {
        local $main::_ = $File::Find::name;
        my $dir = _untaintDir($File::Find::dir);
        chdir($startDir);
        push(@files, $File::Find::name) if (&$pred);
        chdir($dir);
    };

    File::Find::find($wanted, $root);

    # Now @files has all the files that I could potentially be adding to
    # the zip. Only add the ones that are necessary.
    # For each file (updated or not), add its member name to @done.
    my %done;
    foreach my $fileName (@files) {
        my @newStat = stat($fileName);
        my $isDir   = -d _;

        # normalize, remove leading ./
        my $memberName = _asZipDirName($fileName, $isDir);
        if ($memberName eq $rootZipName) { $memberName = $dest }
        else                             { $memberName =~ s{$pattern}{$dest} }
        next if $memberName =~ m{^\.?/?$};    # skip current dir

        $done{$memberName} = 1;
        my $changedMember = $self->updateMember($memberName, $fileName);
        $changedMember->desiredCompressionLevel($compressionLevel);
        return _error("updateTree failed to update $fileName")
          unless ref($changedMember);
    }

    # @done now has the archive names corresponding to all the found files.
    # If we're mirroring, delete all those members that aren't in @done.
    if ($mirror) {
        foreach my $member ($self->members()) {
            $self->removeMember($member)
              unless $done{$member->fileName()};
        }
    }

    return AZ_OK;
}

1;
