package Win32::FindFile;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Win32::FindFile ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	FindFile 
	ReadDir
	FileTime
	FileData
	wchar 
	uchar
	wfchar

	DeleteFile
	MoveFile
	CopyFile
	RemoveDirectory
	CreateDirectory

	GetFullPathName
	GetCurrentDirectory 
	SetCurrentDirectory 

	GetBinaryType
	GetCompressedFileSize
	GetFileAttributes
	SetFileAttributes
	GetLongPathName

	AreFileApisANSI
	SetFileApisToOEM
	SetFileApisToANSI
	) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	FindFile FileData FileTime	
);
use constant { 
    FileData => __PACKAGE__ . '::' .'_WFD',
    FileTime => __PACKAGE__ . '::' .'_WFT',};


BEGIN{
	our $VERSION = '0.15';
	require XSLoader;
	XSLoader::load('Win32::FindFile', $VERSION);
};
use autouse Carp => qw(carp croak);
sub ReadDir{
	croak( 'Usage Win32::FindFile::ReadDir( $dir )' ) unless 1 == @_ && defined $_[0];
	my $folder = $_[0];
	croak( 'Usage Win32::FindFile::ReadDir( $dir ) - $dir contains * ?' )
		if $folder=~m/[\*\?]/;
	$folder=~s/\/+\z//g;
	@_ = ();
	@_ = $folder;
	$_[0].="\\*";
	goto &FindFile;
}

# Preloaded methods go here.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

#line 185

#line 204
