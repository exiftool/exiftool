use ExtUtils::MakeMaker;
use File::Spec;

my $ExifTool_pm  = File::Spec->catfile('lib', 'Image', 'ExifTool.pm');
my $ExifTool_pod = File::Spec->catfile('lib', 'Image', 'ExifTool.pod');

WriteMakefile(
    NAME          => 'Image::ExifTool',
    VERSION_FROM  => $ExifTool_pm,
    PREREQ_PM     => { },
    (($ExtUtils::MakeMaker::VERSION gt '6.31' and
      $ExtUtils::MakeMaker::VERSION lt '6.46') ?
        (EXTRA_META => "recommends:\n" .
            "    Archive::Zip:    0\n" .
            "    Compress::Zlib:  0\n" .
            "    Digest::MD5:     0\n" .
            "    Digest::SHA:     0\n" .
            "    Time::HiRes:     0\n" .
            "    POSIX::strptime: 0\n" .
            "    IO::Compress::RawDeflate:   0\n" .
            "    IO::Uncompress::RawInflate: 0\n" ,
          # (not worth recommending -- only for column alignment of some languages)
          #  "    Unicode::LineBreak: 0\n",
          # (not worth recommending -- only for Rawzor files)
          # "    IO::Compress::Bzip2: 0\n",
        ) : ()),
    ($ExtUtils::MakeMaker::VERSION ge '6.46' ?
        (META_MERGE => {
            recommends => {
                'Archive::Zip'   => 0,
                'Compress::Zlib' => 0,
                'Digest::MD5'    => 0,
                'Digest::SHA'    => 0,
                'Time::HiRes'    => 0,
                'POSIX::strptime' => 0,
                'IO::Compress::RawDeflate'   => 0,
                'IO::Uncompress::RawInflate' => 0,
              # 'Unicode::LineBreak' => 0,
              # 'IO::Compress::Bzip2' => 0,
            },
        } ) : ()),
    clean         => { FILES => 't/*.tmp' },
    EXE_FILES     => [ 'exiftool' ],
    ($] >= 5.005 ?
        (ABSTRACT_FROM => $ExifTool_pod,
         AUTHOR        => 'Phil Harvey (philharvey66 at gmail.com)',
        ) : ()),
    (($ExtUtils::MakeMaker::VERSION gt '6.30') ?
        (LICENSE => 'perl') : ()),    
    (($ExtUtils::MakeMaker::VERSION ge '6.47') ?
        (MIN_PERL_VERSION => '5.004') : ()),    
);
