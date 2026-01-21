package Archive::Zip::Member;

# A generic member of an archive

use strict;
use vars qw( $VERSION @ISA );

BEGIN {
    $VERSION = '1.68';
    @ISA     = qw( Archive::Zip );

    if ($^O eq 'MSWin32') {
        require Win32;
        require Encode;
        Encode->import(qw{ decode_utf8 });
    }
}

use Archive::Zip qw(
  :CONSTANTS
  :MISC_CONSTANTS
  :ERROR_CODES
  :PKZIP_CONSTANTS
  :UTILITY_METHODS
);

use Time::Local ();
use Compress::Raw::Zlib qw( Z_OK Z_STREAM_END MAX_WBITS );
use File::Path;
use File::Basename;

# Unix perms for default creation of files/dirs.
use constant DEFAULT_DIRECTORY_PERMISSIONS => 040755;
use constant DEFAULT_FILE_PERMISSIONS      => 0100666;
use constant DIRECTORY_ATTRIB              => 040000;
use constant FILE_ATTRIB                   => 0100000;
use constant OS_SUPPORTS_SYMLINK           => do {
  local $@;
  !!eval { symlink("",""); 1 };
};

# Returns self if successful, else undef
# Assumes that fh is positioned at beginning of central directory file header.
# Leaves fh positioned immediately after file header or EOCD signature.
sub _newFromZipFile {
    my $class = shift;
    my $self  = Archive::Zip::ZipFileMember->_newFromZipFile(@_);
    return $self;
}

sub newFromString {
    my $class = shift;

    my ($stringOrStringRef, $fileName);
    if (ref($_[0]) eq 'HASH') {
        $stringOrStringRef = $_[0]->{string};
        $fileName          = $_[0]->{zipName};
    } else {
        ($stringOrStringRef, $fileName) = @_;
    }

    my $self =
      Archive::Zip::StringMember->_newFromString($stringOrStringRef, $fileName);
    return $self;
}

sub newFromFile {
    my $class = shift;

    my ($fileName, $zipName);
    if (ref($_[0]) eq 'HASH') {
        $fileName = $_[0]->{fileName};
        $zipName  = $_[0]->{zipName};
    } else {
        ($fileName, $zipName) = @_;
    }

    my $self =
      Archive::Zip::NewFileMember->_newFromFileNamed($fileName, $zipName);
    return $self;
}

sub newDirectoryNamed {
    my $class = shift;

    my ($directoryName, $newName);
    if (ref($_[0]) eq 'HASH') {
        $directoryName = $_[0]->{directoryName};
        $newName       = $_[0]->{zipName};
    } else {
        ($directoryName, $newName) = @_;
    }

    my $self =
      Archive::Zip::DirectoryMember->_newNamed($directoryName, $newName);
    return $self;
}

sub new {
    my $class = shift;
    # Info-Zip 3.0 (I guess) seems to use the following values
    # for the version fields in local and central directory
    # headers, regardless of whether the member has an zip64
    # extended information extra field or not:
    #
    #   version made by:
    #     30
    #
    #   version needed to extract:
    #     10 for directory and stored entries
    #     20 for anything else
    my $self  = {
        'lastModFileDateTime'      => 0,
        'fileAttributeFormat'      => FA_UNIX,
        'zip64'                    => 0,
        'desiredZip64Mode'         => ZIP64_AS_NEEDED,
        'versionMadeBy'            => 20,
        'versionNeededToExtract'   => 20,
        'bitFlag'                  => ($Archive::Zip::UNICODE ? 0x0800 : 0),
        'compressionMethod'        => COMPRESSION_STORED,
        'desiredCompressionMethod' => COMPRESSION_STORED,
        'desiredCompressionLevel'  => COMPRESSION_LEVEL_NONE,
        'internalFileAttributes'   => 0,
        'externalFileAttributes'   => 0,                        # set later
        'fileName'                 => '',
        'cdExtraField'             => '',
        'localExtraField'          => '',
        'fileComment'              => '',
        'crc32'                    => 0,
        'compressedSize'           => 0,
        'uncompressedSize'         => 0,
        'password'                 => undef,    # password for encrypted data
        'crc32c'                   => -1,       # crc for decrypted data
        @_
    };
    bless($self, $class);
    $self->unixFileAttributes($self->DEFAULT_FILE_PERMISSIONS);
    return $self;
}

# Morph into given class (do whatever cleanup I need to do)
sub _become {
    return bless($_[0], $_[1]);
}

sub fileAttributeFormat {
    my $self = shift;

    if (@_) {
        $self->{fileAttributeFormat} =
          (ref($_[0]) eq 'HASH') ? $_[0]->{format} : $_[0];
    } else {
        return $self->{fileAttributeFormat};
    }
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

sub bitFlag {
    my $self = shift;

# Set General Purpose Bit Flags according to the desiredCompressionLevel setting
    if (   $self->desiredCompressionLevel == 1
        || $self->desiredCompressionLevel == 2) {
        $self->{'bitFlag'} |= DEFLATING_COMPRESSION_FAST;
    } elsif ($self->desiredCompressionLevel == 3
        || $self->desiredCompressionLevel == 4
        || $self->desiredCompressionLevel == 5
        || $self->desiredCompressionLevel == 6
        || $self->desiredCompressionLevel == 7) {
        $self->{'bitFlag'} |= DEFLATING_COMPRESSION_NORMAL;
    } elsif ($self->desiredCompressionLevel == 8
        || $self->desiredCompressionLevel == 9) {
        $self->{'bitFlag'} |= DEFLATING_COMPRESSION_MAXIMUM;
    }

    if ($Archive::Zip::UNICODE) {
        $self->{'bitFlag'} |= 0x0800;
    }
    $self->{'bitFlag'};
}

sub password {
    my $self = shift;
    $self->{'password'} = shift if @_;
    $self->{'password'};
}

sub compressionMethod {
    shift->{'compressionMethod'};
}

sub desiredCompressionMethod {
    my $self = shift;
    my $newDesiredCompressionMethod =
      (ref($_[0]) eq 'HASH') ? shift->{compressionMethod} : shift;
    my $oldDesiredCompressionMethod = $self->{'desiredCompressionMethod'};
    if (defined($newDesiredCompressionMethod)) {
        $self->{'desiredCompressionMethod'} = $newDesiredCompressionMethod;
        if ($newDesiredCompressionMethod == COMPRESSION_STORED) {
            $self->{'desiredCompressionLevel'} = 0;
            $self->{'bitFlag'} &= ~GPBF_HAS_DATA_DESCRIPTOR_MASK
                if $self->uncompressedSize() == 0;
        } elsif ($oldDesiredCompressionMethod == COMPRESSION_STORED) {
            $self->{'desiredCompressionLevel'} = COMPRESSION_LEVEL_DEFAULT;
        }
    }
    return $oldDesiredCompressionMethod;
}

sub desiredCompressionLevel {
    my $self = shift;
    my $newDesiredCompressionLevel =
      (ref($_[0]) eq 'HASH') ? shift->{compressionLevel} : shift;
    my $oldDesiredCompressionLevel = $self->{'desiredCompressionLevel'};
    if (defined($newDesiredCompressionLevel)) {
        $self->{'desiredCompressionLevel'}  = $newDesiredCompressionLevel;
        $self->{'desiredCompressionMethod'} = (
            $newDesiredCompressionLevel
            ? COMPRESSION_DEFLATED
            : COMPRESSION_STORED
        );
    }
    return $oldDesiredCompressionLevel;
}

sub fileName {
    my $self    = shift;
    my $newName = shift;
    if (defined $newName) {
        $newName =~ y{\\/}{/}s;    # deal with dos/windoze problems
        $self->{'fileName'} = $newName;
    }
    return $self->{'fileName'};
}

sub fileNameAsBytes {
    my $self  = shift;
    my $bytes = $self->{'fileName'};
    if($self->{'bitFlag'} & 0x800){
        $bytes = Encode::encode_utf8($bytes);
    }
    return $bytes;
}

sub lastModFileDateTime {
    my $modTime = shift->{'lastModFileDateTime'};
    $modTime =~ m/^(\d+)$/;           # untaint
    return $1;
}

sub lastModTime {
    my $self = shift;
    return _dosToUnixTime($self->lastModFileDateTime());
}

sub setLastModFileDateTimeFromUnix {
    my $self   = shift;
    my $time_t = shift;
    $self->{'lastModFileDateTime'} = _unixToDosTime($time_t);
}

sub internalFileAttributes {
    shift->{'internalFileAttributes'};
}

sub externalFileAttributes {
    shift->{'externalFileAttributes'};
}

# Convert UNIX permissions into proper value for zip file
# Usable as a function or a method
sub _mapPermissionsFromUnix {
    my $self    = shift;
    my $mode    = shift;
    my $attribs = $mode << 16;

    # Microsoft Windows Explorer needs this bit set for directories
    if ($mode & DIRECTORY_ATTRIB) {
        $attribs |= 16;
    }

    return $attribs;

    # TODO: map more MS-DOS perms
}

# Convert ZIP permissions into Unix ones
#
# This was taken from Info-ZIP group's portable UnZip
# zipfile-extraction program, version 5.50.
# http://www.info-zip.org/pub/infozip/
#
# See the mapattr() function in unix/unix.c
# See the attribute format constants in unzpriv.h
#
# XXX Note that there's one situation that is not implemented
# yet that depends on the "extra field."
sub _mapPermissionsToUnix {
    my $self = shift;

    my $format  = $self->{'fileAttributeFormat'};
    my $attribs = $self->{'externalFileAttributes'};

    my $mode = 0;

    if ($format == FA_AMIGA) {
        $attribs = $attribs >> 17 & 7;                         # Amiga RWE bits
        $mode    = $attribs << 6 | $attribs << 3 | $attribs;
        return $mode;
    }

    if ($format == FA_THEOS) {
        $attribs &= 0xF1FFFFFF;
        if (($attribs & 0xF0000000) != 0x40000000) {
            $attribs &= 0x01FFFFFF;    # not a dir, mask all ftype bits
        } else {
            $attribs &= 0x41FFFFFF;    # leave directory bit as set
        }
    }

    if (   $format == FA_UNIX
        || $format == FA_VAX_VMS
        || $format == FA_ACORN
        || $format == FA_ATARI_ST
        || $format == FA_BEOS
        || $format == FA_QDOS
        || $format == FA_TANDEM) {
        $mode = $attribs >> 16;
        return $mode if $mode != 0 or not $self->localExtraField;

        # warn("local extra field is: ", $self->localExtraField, "\n");

        # XXX This condition is not implemented
        # I'm just including the comments from the info-zip section for now.

        # Some (non-Info-ZIP) implementations of Zip for Unix and
        # VMS (and probably others ??) leave 0 in the upper 16-bit
        # part of the external_file_attributes field. Instead, they
        # store file permission attributes in some extra field.
        # As a work-around, we search for the presence of one of
        # these extra fields and fall back to the MSDOS compatible
        # part of external_file_attributes if one of the known
        # e.f. types has been detected.
        # Later, we might implement extraction of the permission
        # bits from the VMS extra field. But for now, the work-around
        # should be sufficient to provide "readable" extracted files.
        # (For ASI Unix e.f., an experimental remap from the e.f.
        # mode value IS already provided!)
    }

    # PKWARE's PKZip for Unix marks entries as FA_MSDOS, but stores the
    # Unix attributes in the upper 16 bits of the external attributes
    # field, just like Info-ZIP's Zip for Unix.  We try to use that
    # value, after a check for consistency with the MSDOS attribute
    # bits (see below).
    if ($format == FA_MSDOS) {
        $mode = $attribs >> 16;
    }

    # FA_MSDOS, FA_OS2_HPFS, FA_WINDOWS_NTFS, FA_MACINTOSH, FA_TOPS20
    $attribs = !($attribs & 1) << 1 | ($attribs & 0x10) >> 4;

    # keep previous $mode setting when its "owner"
    # part appears to be consistent with DOS attribute flags!
    return $mode if ($mode & 0700) == (0400 | $attribs << 6);
    $mode = 0444 | $attribs << 6 | $attribs << 3 | $attribs;
    return $mode;
}

sub unixFileAttributes {
    my $self     = shift;
    my $oldPerms = $self->_mapPermissionsToUnix;

    my $perms;
    if (@_) {
        $perms = (ref($_[0]) eq 'HASH') ? $_[0]->{attributes} : $_[0];

        if ($self->isDirectory) {
            $perms &= ~FILE_ATTRIB;
            $perms |= DIRECTORY_ATTRIB;
        } else {
            $perms &= ~DIRECTORY_ATTRIB;
            $perms |= FILE_ATTRIB;
        }
        $self->{externalFileAttributes} =
          $self->_mapPermissionsFromUnix($perms);
    }

    return $oldPerms;
}

sub localExtraField {
    my $self = shift;

    if (@_) {
        my $localExtraField =
          (ref($_[0]) eq 'HASH') ? $_[0]->{field} : $_[0];
        my ($status, $zip64) =
          $self->_extractZip64ExtraField($localExtraField, undef, undef);
        if ($status != AZ_OK) {
            return $status;
        }
        elsif ($zip64) {
            return _formatError('invalid extra field (contains zip64 information)');
        }
        else {
            $self->{localExtraField} = $localExtraField;
            return AZ_OK;
        }
    } else {
        return $self->{localExtraField};
    }
}

sub cdExtraField {
    my $self = shift;

    if (@_) {
        my $cdExtraField =
          (ref($_[0]) eq 'HASH') ? $_[0]->{field} : $_[0];
        my ($status, $zip64) =
          $self->_extractZip64ExtraField($cdExtraField, undef, undef);
        if ($status != AZ_OK) {
            return $status;
        }
        elsif ($zip64) {
            return _formatError('invalid extra field (contains zip64 information)');
        }
        else {
            $self->{cdExtraField} = $cdExtraField;
            return AZ_OK;
        }
    } else {
        return $self->{cdExtraField};
    }
}

sub extraFields {
    my $self = shift;
    return $self->localExtraField() . $self->cdExtraField();
}

sub fileComment {
    my $self = shift;

    if (@_) {
        $self->{fileComment} =
          (ref($_[0]) eq 'HASH')
          ? pack('C0a*', $_[0]->{comment})
          : pack('C0a*', $_[0]);
    } else {
        return $self->{fileComment};
    }
}

sub hasDataDescriptor {
    my $self = shift;
    if (@_) {
        my $shouldHave = shift;
        if ($shouldHave) {
            $self->{'bitFlag'} |= GPBF_HAS_DATA_DESCRIPTOR_MASK;
        } else {
            $self->{'bitFlag'} &= ~GPBF_HAS_DATA_DESCRIPTOR_MASK;
        }
    }
    return $self->{'bitFlag'} & GPBF_HAS_DATA_DESCRIPTOR_MASK;
}

sub crc32 {
    shift->{'crc32'};
}

sub crc32String {
    sprintf("%08x", shift->{'crc32'});
}

sub compressedSize {
    shift->{'compressedSize'};
}

sub uncompressedSize {
    shift->{'uncompressedSize'};
}

sub isEncrypted {
    shift->{'bitFlag'} & GPBF_ENCRYPTED_MASK;
}

sub isTextFile {
    my $self = shift;
    my $bit  = $self->internalFileAttributes() & IFA_TEXT_FILE_MASK;
    if (@_) {
        my $flag = (ref($_[0]) eq 'HASH') ? shift->{flag} : shift;
        $self->{'internalFileAttributes'} &= ~IFA_TEXT_FILE_MASK;
        $self->{'internalFileAttributes'} |=
          ($flag ? IFA_TEXT_FILE : IFA_BINARY_FILE);
    }
    return $bit == IFA_TEXT_FILE;
}

sub isBinaryFile {
    my $self = shift;
    my $bit  = $self->internalFileAttributes() & IFA_TEXT_FILE_MASK;
    if (@_) {
        my $flag = shift;
        $self->{'internalFileAttributes'} &= ~IFA_TEXT_FILE_MASK;
        $self->{'internalFileAttributes'} |=
          ($flag ? IFA_BINARY_FILE : IFA_TEXT_FILE);
    }
    return $bit == IFA_BINARY_FILE;
}

sub extractToFileNamed {
    my $self = shift;

    # local FS name
    my $name = (ref($_[0]) eq 'HASH') ? $_[0]->{name} : $_[0];

    # Create directory for regular files as well as for symbolic
    # links
    if ($^O eq 'MSWin32' && $Archive::Zip::UNICODE) {
        $name = decode_utf8(Win32::GetFullPathName($name));
        mkpath_win32($name);
    } else {
        mkpath(dirname($name));    # croaks on error
    }

    # Check if the file / directory is a symbolic link *and* if
    # the operating system supports these.  Only in that case
    # call method extractToFileHandle with the name of the
    # symbolic link.  If the operating system does not support
    # symbolic links, process the member using the usual
    # extraction routines, which creates a file containing the
    # link target.
    if ($self->isSymbolicLink() && OS_SUPPORTS_SYMLINK) {
        return $self->extractToFileHandle($name);
    } else {
        my ($status, $fh);
        if ($^O eq 'MSWin32' && $Archive::Zip::UNICODE) {
            Win32::CreateFile($name);
            ($status, $fh) = _newFileHandle(Win32::GetANSIPathName($name), 'w');
        } else {
            ($status, $fh) = _newFileHandle($name, 'w');
        }
        return _ioError("Can't open file $name for write") unless $status;
        $status = $self->extractToFileHandle($fh);
        $fh->close();
        chmod($self->unixFileAttributes(), $name)
          or return _error("Can't chmod() ${name}: $!");
        utime($self->lastModTime(), $self->lastModTime(), $name);
        return $status;
    }
}

sub mkpath_win32 {
    my $path = shift;
    use File::Spec;

    my ($volume, @path) = File::Spec->splitdir($path);
    $path = File::Spec->catfile($volume, shift @path);
    pop @path;
    while (@path) {
        $path = File::Spec->catfile($path, shift @path);
        Win32::CreateDirectory($path);
    }
}

sub isSymbolicLink {
    return shift->{'externalFileAttributes'} == 0xA1FF0000;
}

sub isDirectory {
    return 0;
}

sub externalFileName {
    return undef;
}

# Search the given extra field string for a zip64 extended
# information extra field and "correct" the header fields given
# in the remaining parameters with the information from that
# extra field, if required.  Writes back the extra field string
# sans the zip64 information.  The extra field string and all
# header fields must be passed as lvalues or the undefined value.
#
# This method returns a pair ($status, $zip64) in list context,
# where the latter flag specifies whether a zip64 extended
# information extra field was found.
#
# This method must be called with two header fields for local
# file headers and with four header fields for Central Directory
# headers.
sub _extractZip64ExtraField
{
    my $classOrSelf = shift;

    my $extraField = $_[0];

    my ($zip64Data, $newExtraField) = (undef, '');
    while (length($extraField) >= 4) {
        my ($headerId, $dataSize) = unpack('v v', $extraField);
        if (length($extraField) < 4 + $dataSize) {
            return _formatError('invalid extra field (bad data)');
        }
        elsif ($headerId != 0x0001) {
            $newExtraField .= substr($extraField, 0, 4 + $dataSize);
            $extraField     = substr($extraField, 4 + $dataSize);
        }
        else {
            $zip64Data      = substr($extraField, 4, $dataSize);
            $extraField     = substr($extraField, 4 + $dataSize);
        }
    }
    if (length($extraField) != 0) {
        return _formatError('invalid extra field (bad header ID or data size)');
    }

    my $zip64 = 0;
    if (defined($zip64Data)) {
        return _zip64NotSupported() unless ZIP64_SUPPORTED;

        my $dataLength = length($zip64Data);

        # Try to be tolerant with respect to the fields to be
        # extracted from the zip64 extended information extra
        # field and derive that information from the data itself,
        # if possible.  This works around, for example, incorrect
        # extra fields written by certain versions of package
        # IO::Compress::Zip.  That package provides the disk
        # number start in the extra field without setting the
        # corresponding regular field to 0xffff.  Plus it
        # provides the full set of fields even for the local file
        # header.
        #
        # Field zero is the extra field string which we must keep
        # in @_ for future modification, so account for that.
        my @fields;
        if (@_ == 3 && $dataLength == 16) {
            @fields = (undef, 0xffffffff, 0xffffffff);
        }
        elsif (@_ == 3 && $dataLength == 24) {
            push(@_, undef);
            @fields = (undef, 0xffffffff, 0xffffffff, 0xffffffff);
        }
        elsif (@_ == 3 && $dataLength == 28) {
            push(@_, undef, undef);
            @fields = (undef, 0xffffffff, 0xffffffff, 0xffffffff, 0xffff);
        }
        elsif (@_ == 5 && $dataLength == 24) {
            @fields = (undef, 0xffffffff, 0xffffffff, 0xffffffff);
        }
        elsif (@_ == 5 && $dataLength == 28) {
            @fields = (undef, 0xffffffff, 0xffffffff, 0xffffffff, 0xffff);
        }
        else {
            @fields = map { defined $_ ? $_ : 0 } @_;
        }

        my @fieldIndexes  = (0);
        my $fieldFormat   = '';
        my $expDataLength = 0;
        if ($fields[1] == 0xffffffff) {
            push(@fieldIndexes, 1);
            $fieldFormat .= 'Q< ';
            $expDataLength += 8;
        }
        if ($fields[2] == 0xffffffff) {
            push(@fieldIndexes, 2);
            $fieldFormat .= 'Q< ';
            $expDataLength += 8;
        }
        if (@fields > 3 && $fields[3] == 0xffffffff) {
            push(@fieldIndexes, 3);
            $fieldFormat .= 'Q< ';
            $expDataLength += 8;
        }
        if (@fields > 3 && $fields[4] == 0xffff) {
            push(@fieldIndexes, 4);
            $fieldFormat .= 'L< ';
            $expDataLength += 4;
        }

        if ($dataLength == $expDataLength) {
            @_[@fieldIndexes] = ($newExtraField, unpack($fieldFormat, $zip64Data));
            $zip64 = 1;
        }
        else {
            return _formatError('invalid zip64 extended information extra field');
        }
    }

    return (AZ_OK, $zip64);
}

# The following are used when copying data
sub _writeOffset {
    shift->{'writeOffset'};
}

sub _readOffset {
    shift->{'readOffset'};
}

sub writeLocalHeaderRelativeOffset {
    shift->{'writeLocalHeaderRelativeOffset'};
}

# Maintained in method Archive::Zip::Archive::writeToFileHandle
sub wasWritten {
    shift->{'wasWritten'}
}

sub _dataEnded {
    shift->{'dataEnded'};
}

sub _readDataRemaining {
    shift->{'readDataRemaining'};
}

sub _inflater {
    shift->{'inflater'};
}

sub _deflater {
    shift->{'deflater'};
}

# DOS date/time format
# 0-4 (5) Second divided by 2
# 5-10 (6) Minute (0-59)
# 11-15 (5) Hour (0-23 on a 24-hour clock)
# 16-20 (5) Day of the month (1-31)
# 21-24 (4) Month (1 = January, 2 = February, etc.)
# 25-31 (7) Year offset from 1980 (add 1980 to get actual year)

# Convert DOS date/time format to unix time_t format
# NOT AN OBJECT METHOD!
sub _dosToUnixTime {
    my $dt = shift;
    return time() unless defined($dt);

    my $year = (($dt >> 25) & 0x7f) + 1980;
    my $mon  = (($dt >> 21) & 0x0f) - 1;
    my $mday = (($dt >> 16) & 0x1f);

    my $hour = (($dt >> 11) & 0x1f);
    my $min  = (($dt >> 5) & 0x3f);
    my $sec  = (($dt << 1) & 0x3e);

    # catch errors
    my $time_t =
      eval { Time::Local::timelocal($sec, $min, $hour, $mday, $mon, $year); };
    return time() if ($@);
    return $time_t;
}

# Note, this is not exactly UTC 1980, it's 1980 + 12 hours and 1
# minute so that nothing timezoney can muck us up.
my $safe_epoch = 31.686060;

# convert a unix time to DOS date/time
# NOT AN OBJECT METHOD!
sub _unixToDosTime {
    my $time_t = shift;
    unless ($time_t) {
        _error("Tried to add member with zero or undef value for time");
        $time_t = $safe_epoch;
    }
    if ($time_t < $safe_epoch) {
        _ioError("Unsupported date before 1980 encountered, moving to 1980");
        $time_t = $safe_epoch;
    }
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime($time_t);
    my $dt = 0;
    $dt += ($sec >> 1);
    $dt += ($min << 5);
    $dt += ($hour << 11);
    $dt += ($mday << 16);
    $dt += (($mon + 1) << 21);
    $dt += (($year - 80) << 25);
    return $dt;
}

# Write my local header to a file handle.
# Returns a pair (AZ_OK, $headerSize) on success.
sub _writeLocalFileHeader {
    my $self    = shift;
    my $fh      = shift;
    my $refresh = @_ ? shift : 0;

    my $zip64 = $self->zip64();
    my $hasDataDescriptor = $self->hasDataDescriptor();

    my $versionNeededToExtract = $self->versionNeededToExtract();
    my $crc32;
    my $compressedSize;
    my $uncompressedSize;
    my $localExtraField = $self->localExtraField();

    if (! $zip64) {
        if ($refresh) {
            $crc32            = $self->crc32();
            $compressedSize   = $self->_writeOffset();
            $uncompressedSize = $self->uncompressedSize();

            # Handle a brain-dead corner case gracefully.
            # Otherwise we a) would always need to write zip64
            # format or b) re-write the complete member data on
            # refresh (which might not always be possible).
            if ($compressedSize > 0xffffffff) {
                return _formatError('compressed size too large for refresh');
            }
        }
        elsif ($hasDataDescriptor) {
            $crc32            = 0;
            $compressedSize   = 0;
            $uncompressedSize = 0;
        }
        else {
            $crc32            = $self->crc32();
            $compressedSize   = $self->_writeOffset();
            $uncompressedSize = $self->uncompressedSize();
        }
    }
    else {
        return _zip64NotSupported() unless ZIP64_SUPPORTED;

        $versionNeededToExtract = 45 if ($versionNeededToExtract < 45);

        my $zip64CompressedSize;
        my $zip64UncompressedSize;
        if ($refresh) {
            $crc32                 = $self->crc32();
            $compressedSize        = 0xffffffff;
            $uncompressedSize      = 0xffffffff;
            $zip64CompressedSize   = $self->_writeOffset();
            $zip64UncompressedSize = $self->uncompressedSize();
        }
        elsif ($hasDataDescriptor) {
            $crc32                 = 0;
            $compressedSize        = 0xffffffff;
            $uncompressedSize      = 0xffffffff;
            $zip64CompressedSize   = 0;
            $zip64UncompressedSize = 0;
        }
        else {
            $crc32                 = $self->crc32();
            $compressedSize        = 0xffffffff;
            $uncompressedSize      = 0xffffffff;
            $zip64CompressedSize   = $self->_writeOffset();
            $zip64UncompressedSize = $self->uncompressedSize();
        }

        $localExtraField .= pack('S< S< Q< Q<',
                                 0x0001, 16,
                                 $zip64UncompressedSize,
                                 $zip64CompressedSize);
    }

    my $fileNameLength    = length($self->fileNameAsBytes());
    my $localFieldLength  = length($localExtraField);

    my $signatureData = pack(SIGNATURE_FORMAT, LOCAL_FILE_HEADER_SIGNATURE);
    $self->_print($fh, $signatureData)
      or return _ioError("writing local header signature");

    my $header =
      pack(LOCAL_FILE_HEADER_FORMAT,
           $versionNeededToExtract,
           $self->{'bitFlag'},
           $self->desiredCompressionMethod(),
           $self->lastModFileDateTime(),
           $crc32,
           $compressedSize,
           $uncompressedSize,
           $fileNameLength,
           $localFieldLength);
    $self->_print($fh, $header)
      or return _ioError("writing local header");

    # Write these only if required
    if (! $refresh || $zip64) {
        if ($fileNameLength) {
            $self->_print($fh, $self->fileNameAsBytes())
              or return _ioError("writing local header filename");
        }
        if ($localFieldLength) {
            $self->_print($fh, $localExtraField)
              or return _ioError("writing local extra field");
        }
    }

    return
      (AZ_OK,
       LOCAL_FILE_HEADER_LENGTH +
       SIGNATURE_LENGTH +
       $fileNameLength +
       $localFieldLength);
}

# Re-writes the local file header with new crc32 and compressedSize fields.
# To be called after writing the data stream.
# Assumes that filename and extraField sizes didn't change since last written.
sub _refreshLocalFileHeader {
    my $self = shift;
    my $fh   = shift;

    my $here = $fh->tell();
    $fh->seek($self->writeLocalHeaderRelativeOffset(), IO::Seekable::SEEK_SET)
      or return _ioError("seeking to rewrite local header");

    my ($status, undef) = $self->_writeLocalFileHeader($fh, 1);
    return $status if $status != AZ_OK;

    $fh->seek($here, IO::Seekable::SEEK_SET)
      or return _ioError("seeking after rewrite of local header");

    return AZ_OK;
}

# Write central directory file header.
# Returns a pair (AZ_OK, $headerSize) on success.
sub _writeCentralDirectoryFileHeader {
    my $self   = shift;
    my $fh     = shift;
    my $adz64m = shift;         # $archiveDesiredZip64Mode

    # (Re-)Determine whether to write zip64 format.  Assume
    # {'diskNumberStart'} is always zero.
    my $zip64 = $adz64m == ZIP64_HEADERS
             || $self->desiredZip64Mode() == ZIP64_HEADERS
             || $self->_writeOffset() > 0xffffffff
             || $self->uncompressedSize() > 0xffffffff
             || $self->writeLocalHeaderRelativeOffset() > 0xffffffff;

    $self->{'zip64'} ||= $zip64;

    my $versionMadeBy             = $self->versionMadeBy();
    my $versionNeededToExtract    = $self->versionNeededToExtract();
    my $compressedSize            = $self->_writeOffset();
    my $uncompressedSize          = $self->uncompressedSize();
    my $localHeaderRelativeOffset = $self->writeLocalHeaderRelativeOffset();
    my $cdExtraField              = $self->cdExtraField();

    if (!$zip64) {
        # no-op
    }
    else {
        return _zip64NotSupported() unless ZIP64_SUPPORTED;

        $versionNeededToExtract = 45 if ($versionNeededToExtract < 45);

        my $extraFieldFormat = '';
        my @extraFieldValues = ();
        my $extraFieldSize   = 0;
        if ($uncompressedSize > 0xffffffff) {
            $extraFieldFormat .= 'Q< ';
            push(@extraFieldValues, $uncompressedSize);
            $extraFieldSize += 8;
            $uncompressedSize = 0xffffffff;
        }
        if ($compressedSize > 0xffffffff) {
            $extraFieldFormat .= 'Q< ';
            push(@extraFieldValues, $compressedSize);
            $extraFieldSize += 8;
            $compressedSize = 0xffffffff;
        }
        # Avoid empty zip64 extended information extra fields
        if (   $localHeaderRelativeOffset > 0xffffffff
            || @extraFieldValues == 0) {
            $extraFieldFormat .= 'Q< ';
            push(@extraFieldValues, $localHeaderRelativeOffset);
            $extraFieldSize += 8;
            $localHeaderRelativeOffset = 0xffffffff;
        }

        $cdExtraField .=
          pack("S< S< $extraFieldFormat",
               0x0001, $extraFieldSize,
               @extraFieldValues);
    }

    my $fileNameLength    = length($self->fileNameAsBytes());
    my $extraFieldLength  = length($cdExtraField);
    my $fileCommentLength = length($self->fileComment());

    my $sigData =
      pack(SIGNATURE_FORMAT, CENTRAL_DIRECTORY_FILE_HEADER_SIGNATURE);
    $self->_print($fh, $sigData)
      or return _ioError("writing central directory header signature");

    my $header = pack(
        CENTRAL_DIRECTORY_FILE_HEADER_FORMAT,
        $versionMadeBy,
        $self->fileAttributeFormat(),
        $versionNeededToExtract,
        $self->bitFlag(),
        $self->desiredCompressionMethod(),
        $self->lastModFileDateTime(),
        $self->crc32(),            # these three fields should have been updated
        $compressedSize,           # by writing the data stream out
        $uncompressedSize,         #
        $fileNameLength,
        $extraFieldLength,
        $fileCommentLength,
        0,                         # {'diskNumberStart'},
        $self->internalFileAttributes(),
        $self->externalFileAttributes(),
        $localHeaderRelativeOffset);

    $self->_print($fh, $header)
      or return _ioError("writing central directory header");

    if ($fileNameLength) {
        $self->_print($fh, $self->fileNameAsBytes())
          or return _ioError("writing central directory header signature");
    }
    if ($extraFieldLength) {
        $self->_print($fh, $cdExtraField)
          or return _ioError("writing central directory extra field");
    }
    if ($fileCommentLength) {
        $self->_print($fh, $self->fileComment())
          or return _ioError("writing central directory file comment");
    }

    # Update object members with information which might have
    # changed while writing this member.  We already did the
    # zip64 flag.  We must not update the extra fields with any
    # zip64 information, since we consider that internal.
    $self->{'versionNeededToExtract'} = $versionNeededToExtract;
    $self->{'compressedSize'}         = $self->_writeOffset();

    return
      (AZ_OK,
       CENTRAL_DIRECTORY_FILE_HEADER_LENGTH +
       SIGNATURE_LENGTH +
       $fileNameLength +
       $extraFieldLength +
       $fileCommentLength)
}

# This writes a data descriptor to the given file handle.
# Assumes that crc32, writeOffset, and uncompressedSize are
# set correctly (they should be after a write).
# Returns a pair (AZ_OK, $dataDescriptorSize) on success.
# Further, the local file header should have the
# GPBF_HAS_DATA_DESCRIPTOR_MASK bit set.
sub _writeDataDescriptor {
    my $self   = shift;
    my $fh     = shift;

    my $descriptor;
    if (! $self->zip64()) {
        $descriptor =
          pack(SIGNATURE_FORMAT . DATA_DESCRIPTOR_FORMAT,
               DATA_DESCRIPTOR_SIGNATURE,
               $self->crc32(),
               $self->_writeOffset(),   # compressed size
               $self->uncompressedSize());
    }
    else {
        return _zip64NotSupported() unless ZIP64_SUPPORTED;

        $descriptor =
          pack(SIGNATURE_FORMAT . DATA_DESCRIPTOR_ZIP64_FORMAT,
               DATA_DESCRIPTOR_SIGNATURE,
               $self->crc32(),
               $self->_writeOffset(),   # compressed size
               $self->uncompressedSize());
    }

    $self->_print($fh, $descriptor)
      or return _ioError("writing data descriptor");

    return (AZ_OK, length($descriptor));
}

sub readChunk {
    my $self = shift;
    my $chunkSize = (ref($_[0]) eq 'HASH') ? $_[0]->{chunkSize} : $_[0];

    if ($self->readIsDone()) {
        $self->endRead();
        my $dummy = '';
        return (\$dummy, AZ_STREAM_END);
    }

    $chunkSize = $Archive::Zip::ChunkSize if not defined($chunkSize);
    $chunkSize = $self->_readDataRemaining()
      if $chunkSize > $self->_readDataRemaining();

    my $buffer = '';
    my $outputRef;
    my ($bytesRead, $status) = $self->_readRawChunk(\$buffer, $chunkSize);
    return (\$buffer, $status) unless $status == AZ_OK;

    $buffer && $self->isEncrypted and $buffer = $self->_decode($buffer);
    $self->{'readDataRemaining'} -= $bytesRead;
    $self->{'readOffset'} += $bytesRead;

    if ($self->compressionMethod() == COMPRESSION_STORED) {
        $self->{'crc32'} = $self->computeCRC32($buffer, $self->{'crc32'});
    }

    ($outputRef, $status) = &{$self->{'chunkHandler'}}($self, \$buffer);
    $self->{'writeOffset'} += length($$outputRef);

    $self->endRead()
      if $self->readIsDone();

    return ($outputRef, $status);
}

# Read the next raw chunk of my data. Subclasses MUST implement.
#   my ( $bytesRead, $status) = $self->_readRawChunk( \$buffer, $chunkSize );
sub _readRawChunk {
    my $self = shift;
    return $self->_subclassResponsibility();
}

# A place holder to catch rewindData errors if someone ignores
# the error code.
sub _noChunk {
    my $self = shift;
    return (\undef, _error("trying to copy chunk when init failed"));
}

# Basically a no-op so that I can have a consistent interface.
# ( $outputRef, $status) = $self->_copyChunk( \$buffer );
sub _copyChunk {
    my ($self, $dataRef) = @_;
    return ($dataRef, AZ_OK);
}

# ( $outputRef, $status) = $self->_deflateChunk( \$buffer );
sub _deflateChunk {
    my ($self, $buffer) = @_;
    my ($status) = $self->_deflater()->deflate($buffer, my $out);

    if ($self->_readDataRemaining() == 0) {
        my $extraOutput;
        ($status) = $self->_deflater()->flush($extraOutput);
        $out .= $extraOutput;
        $self->endRead();
        return (\$out, AZ_STREAM_END);
    } elsif ($status == Z_OK) {
        return (\$out, AZ_OK);
    } else {
        $self->endRead();
        my $retval = _error('deflate error', $status);
        my $dummy = '';
        return (\$dummy, $retval);
    }
}

# ( $outputRef, $status) = $self->_inflateChunk( \$buffer );
sub _inflateChunk {
    my ($self, $buffer) = @_;
    my ($status) = $self->_inflater()->inflate($buffer, my $out);
    my $retval;
    $self->endRead() unless $status == Z_OK;
    if ($status == Z_OK || $status == Z_STREAM_END) {
        $retval = ($status == Z_STREAM_END) ? AZ_STREAM_END : AZ_OK;
        return (\$out, $retval);
    } else {
        $retval = _error('inflate error', $status);
        my $dummy = '';
        return (\$dummy, $retval);
    }
}

sub rewindData {
    my $self = shift;
    my $status;

    # set to trap init errors
    $self->{'chunkHandler'} = $self->can('_noChunk');

    # Work around WinZip bug with 0-length DEFLATED files
    $self->desiredCompressionMethod(COMPRESSION_STORED)
      if $self->uncompressedSize() == 0;

    # assume that we're going to read the whole file, and compute the CRC anew.
    $self->{'crc32'} = 0
      if ($self->compressionMethod() == COMPRESSION_STORED);

    # These are the only combinations of methods we deal with right now.
    if (    $self->compressionMethod() == COMPRESSION_STORED
        and $self->desiredCompressionMethod() == COMPRESSION_DEFLATED) {
        ($self->{'deflater'}, $status) = Compress::Raw::Zlib::Deflate->new(
            '-Level'      => $self->desiredCompressionLevel(),
            '-WindowBits' => -MAX_WBITS(),                     # necessary magic
            '-Bufsize'    => $Archive::Zip::ChunkSize,
            @_
        );    # pass additional options
        return _error('deflateInit error:', $status)
          unless $status == Z_OK;
        $self->{'chunkHandler'} = $self->can('_deflateChunk');
    } elsif ($self->compressionMethod() == COMPRESSION_DEFLATED
        and $self->desiredCompressionMethod() == COMPRESSION_STORED) {
        ($self->{'inflater'}, $status) = Compress::Raw::Zlib::Inflate->new(
            '-WindowBits' => -MAX_WBITS(),               # necessary magic
            '-Bufsize'    => $Archive::Zip::ChunkSize,
            @_
        );    # pass additional options
        return _error('inflateInit error:', $status)
          unless $status == Z_OK;
        $self->{'chunkHandler'} = $self->can('_inflateChunk');
    } elsif ($self->compressionMethod() == $self->desiredCompressionMethod()) {
        $self->{'chunkHandler'} = $self->can('_copyChunk');
    } else {
        return _error(
            sprintf(
                "Unsupported compression combination: read %d, write %d",
                $self->compressionMethod(),
                $self->desiredCompressionMethod()));
    }

    $self->{'readDataRemaining'} =
      ($self->compressionMethod() == COMPRESSION_STORED)
      ? $self->uncompressedSize()
      : $self->compressedSize();
    $self->{'dataEnded'}  = 0;
    $self->{'readOffset'} = 0;

    return AZ_OK;
}

sub endRead {
    my $self = shift;
    delete $self->{'inflater'};
    delete $self->{'deflater'};
    $self->{'dataEnded'}         = 1;
    $self->{'readDataRemaining'} = 0;
    return AZ_OK;
}

sub readIsDone {
    my $self = shift;
    return ($self->_dataEnded() or !$self->_readDataRemaining());
}

sub contents {
    my $self        = shift;
    my $newContents = shift;

    if (defined($newContents)) {

        # Change our type and ensure that succeeded to avoid
        # endless recursion
        $self->_become('Archive::Zip::StringMember');
        $self->_ISA('Archive::Zip::StringMember') or
          return
            wantarray
            ? (undef, $self->_error('becoming Archive::Zip::StringMember'))
            : undef;

        # Now call the subclass contents method
        my $retval =
          $self->contents(pack('C0a*', $newContents)); # in case of Unicode

        return wantarray ? ($retval, AZ_OK) : $retval;
    } else {
        my $oldCompression =
          $self->desiredCompressionMethod(COMPRESSION_STORED);
        my $status = $self->rewindData(@_);
        if ($status != AZ_OK) {
            $self->endRead();
            return wantarray ? (undef, $status) : undef;
        }
        my $retval = '';
        while ($status == AZ_OK) {
            my $ref;
            ($ref, $status) = $self->readChunk($self->_readDataRemaining());

            # did we get it in one chunk?
            if (length($$ref) == $self->uncompressedSize()) {
                $retval = $$ref;
            } else {
                $retval .= $$ref
            }
        }
        $self->desiredCompressionMethod($oldCompression);
        $self->endRead();
        $status = AZ_OK if $status == AZ_STREAM_END;
        $retval = undef unless $status == AZ_OK;
        return wantarray ? ($retval, $status) : $retval;
    }
}

sub extractToFileHandle {
    my $self = shift;
    # This can be the link name when "extracting" symbolic links
    my $fhOrName = (ref($_[0]) eq 'HASH') ? shift->{fileHandle} : shift;
    _binmode($fhOrName) if ref($fhOrName);
    my $oldCompression = $self->desiredCompressionMethod(COMPRESSION_STORED);
    my $status         = $self->rewindData(@_);
    $status = $self->_writeData($fhOrName) if $status == AZ_OK;
    $self->desiredCompressionMethod($oldCompression);
    $self->endRead();
    return $status;
}

# write local header and data stream to file handle.
# Returns a pair ($status, $memberSize) if successful.
# Stores the offset to the start of the header in my
# writeLocalHeaderRelativeOffset member.
sub _writeToFileHandle {
    my $self         = shift;
    my $fh           = shift;
    my $fhIsSeekable = shift;
    my $offset       = shift;
    my $adz64m       = shift;   # $archiveDesiredZip64Mode

    return _error("no member name given for $self")
      if $self->fileName() eq '';

    $self->{'writeLocalHeaderRelativeOffset'} = $offset;

    # Determine if I need to refresh the header in a second pass
    # later.  If in doubt, I'd rather refresh, since it does not
    # seem to be worth the hassle to save the extra seeks and
    # writes.  In addition, having below condition independent of
    # any specific compression methods helps me piping through
    # members with unknown compression methods unchanged.  See
    # test t/26_bzip2.t for details.
    my $headerFieldsUnknown = $self->uncompressedSize() > 0;

    # Determine if I need to write a data descriptor
    # I need to do this if I can't refresh the header
    # and I don't know compressed size or crc32 fields.
    my $shouldWriteDataDescriptor =
      ($headerFieldsUnknown and not $fhIsSeekable);

    $self->hasDataDescriptor(1)
      if ($shouldWriteDataDescriptor);

    # Determine whether to write zip64 format
    my $zip64 = $adz64m == ZIP64_HEADERS
             || $self->desiredZip64Mode() == ZIP64_HEADERS
             || $self->uncompressedSize() > 0xffffffff;

    $self->{'zip64'} ||= $zip64;

    $self->{'writeOffset'} = 0;

    my $status = $self->rewindData();
    return $status if $status != AZ_OK;

    my $memberSize;
    ($status, $memberSize) = $self->_writeLocalFileHeader($fh);
    return $status if $status != AZ_OK;

    $status = $self->_writeData($fh);
    return $status if $status != AZ_OK;
    $memberSize += $self->_writeOffset();

    if ($self->hasDataDescriptor()) {
        my $ddSize;
        ($status, $ddSize) = $self->_writeDataDescriptor($fh);
        $memberSize += $ddSize;
    } elsif ($headerFieldsUnknown) {
        $status = $self->_refreshLocalFileHeader($fh);
    }
    return $status if $status != AZ_OK;

    return ($status, $memberSize);
}

# Copy my (possibly compressed) data to given file handle.
# Returns C<AZ_OK> on success
sub _writeData {
    my $self     = shift;
    my $fhOrName = shift;

    if ($self->isSymbolicLink() && OS_SUPPORTS_SYMLINK) {
        my $chunkSize = $Archive::Zip::ChunkSize;
        my ($outRef, $status) = $self->readChunk($chunkSize);
        symlink($$outRef, $fhOrName)
          or return _ioError("creating symbolic link");
    } else {
        return AZ_OK if ($self->uncompressedSize() == 0);
        my $status;
        my $chunkSize = $Archive::Zip::ChunkSize;
        while ($self->_readDataRemaining() > 0) {
            my $outRef;
            ($outRef, $status) = $self->readChunk($chunkSize);
            return $status if ($status != AZ_OK and $status != AZ_STREAM_END);

            if (length($$outRef) > 0) {
                $self->_print($fhOrName, $$outRef)
                  or return _ioError("write error during copy");
            }

            last if $status == AZ_STREAM_END;
        }
    }
    return AZ_OK;
}

# Return true if I depend on the named file
sub _usesFileNamed {
    return 0;
}

# ##############################################################################
#
# Decrypt section
#
# H.Merijn Brand (Tux) 2011-06-28
#
# ##############################################################################

# This code is derived from the crypt source of unzip-6.0 dated 05 Jan 2007
# Its license states:
#
# --8<---
# Copyright (c) 1990-2007 Info-ZIP.  All rights reserved.

# See the accompanying file LICENSE, version 2005-Feb-10 or later
# (the contents of which are also included in (un)zip.h) for terms of use.
# If, for some reason, all these files are missing, the Info-ZIP license
# also may be found at:  ftp://ftp.info-zip.org/pub/infozip/license.html
#
# crypt.c (full version) by Info-ZIP.      Last revised:  [see crypt.h]

# The main encryption/decryption source code for Info-Zip software was
# originally written in Europe.  To the best of our knowledge, it can
# be freely distributed in both source and object forms from any country,
# including the USA under License Exception TSU of the U.S. Export
# Administration Regulations (section 740.13(e)) of 6 June 2002.

# NOTE on copyright history:
# Previous versions of this source package (up to version 2.8) were
# not copyrighted and put in the public domain.  If you cannot comply
# with the Info-Zip LICENSE, you may want to look for one of those
# public domain versions.
#
# This encryption code is a direct transcription of the algorithm from
# Roger Schlafly, described by Phil Katz in the file appnote.txt.  This
# file (appnote.txt) is distributed with the PKZIP program (even in the
# version without encryption capabilities).
# -->8---

# As of January 2000, US export regulations were amended to allow export
# of free encryption source code from the US.  As of June 2002, these
# regulations were further relaxed to allow export of encryption binaries
# associated with free encryption source code.  The Zip 2.31, UnZip 5.52
# and Wiz 5.02 archives now include full crypto source code.  As of the
# Zip 2.31 release, all official binaries include encryption support; the
# former "zcr" archives ceased to exist.
# (Note that restrictions may still exist in other countries, of course.)

# For now, we just support the decrypt stuff
# All below methods are supposed to be private

# use Data::Peek;

my @keys;
my @crct = do {
    my $xor = 0xedb88320;
    my @crc = (0) x 1024;

    # generate a crc for every 8-bit value
    foreach my $n (0 .. 255) {
        my $c = $n;
        $c = $c & 1 ? $xor ^ ($c >> 1) : $c >> 1 for 1 .. 8;
        $crc[$n] = _revbe($c);
    }

    # generate crc for each value followed by one, two, and three zeros */
    foreach my $n (0 .. 255) {
        my $c = ($crc[($crc[$n] >> 24) ^ 0] ^ ($crc[$n] << 8)) & 0xffffffff;
        $crc[$_ * 256 + $n] = $c for 1 .. 3;
    }
    map { _revbe($crc[$_]) } 0 .. 1023;
};

sub _crc32 {
    my ($c, $b) = @_;
    return ($crct[($c ^ $b) & 0xff] ^ ($c >> 8));
}    # _crc32

sub _revbe {
    my $w = shift;
    return (($w >> 24) +
          (($w >> 8) & 0xff00) +
          (($w & 0xff00) << 8) +
          (($w & 0xff) << 24));
}    # _revbe

sub _update_keys {
    use integer;
    my $c = shift;    # signed int
    $keys[0] = _crc32($keys[0], $c);
    $keys[1] = (($keys[1] + ($keys[0] & 0xff)) * 0x08088405 + 1) & 0xffffffff;
    my $keyshift = $keys[1] >> 24;
    $keys[2] = _crc32($keys[2], $keyshift);
}    # _update_keys

sub _zdecode ($) {
    my $c = shift;
    my $t = ($keys[2] & 0xffff) | 2;
    _update_keys($c ^= ((($t * ($t ^ 1)) >> 8) & 0xff));
    return $c;
}    # _zdecode

sub _decode {
    my $self = shift;
    my $buff = shift;

    $self->isEncrypted or return $buff;

    my $pass = $self->password;
    defined $pass or return "";

    @keys = (0x12345678, 0x23456789, 0x34567890);
    _update_keys($_) for unpack "C*", $pass;

    # DDumper { uk => [ @keys ] };

    my $head = substr $buff, 0, 12, "";
    my @head = map { _zdecode($_) } unpack "C*", $head;
    my $x =
      $self->{externalFileAttributes}
      ? ($self->{lastModFileDateTime} >> 8) & 0xff
      : $self->{crc32} >> 24;
    $head[-1] == $x or return "";    # Password fail

    # Worth checking ...
    $self->{crc32c} = (unpack LOCAL_FILE_HEADER_FORMAT, pack "C*", @head)[3];

    # DHexDump ($buff);
    $buff = pack "C*" => map { _zdecode($_) } unpack "C*" => $buff;

    # DHexDump ($buff);
    return $buff;
}    # _decode

1;
