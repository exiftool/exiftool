Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 10.65
Release: 1
License: Artistic/GPL
Group: Development/Libraries/Perl
URL: http://owl.phy.queensu.ca/~phil/exiftool/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a customizable set of Perl modules plus a full-featured
application for reading and writing meta information in a wide variety of
files, including the maker note information of many digital cameras by
various manufacturers such as Canon, Casio, FLIR, FujiFilm, GE, HP,
JVC/Victor, Kodak, Leaf, Minolta/Konica-Minolta, Nikon, Olympus/Epson,
Panasonic/Leica, Pentax/Asahi, Phase One, Reconyx, Ricoh, Samsung, Sanyo,
Sigma/Foveon and Sony.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

  File Types
  ------------+-------------+-------------+-------------+------------
  3FR   r     | DVB   r/w   | JSON  r     | OFR   r     | RTF   r
  3G2   r/w   | DYLIB r     | K25   r     | OGG   r     | RW2   r/w
  3GP   r/w   | EIP   r     | KDC   r     | OGV   r     | RWL   r/w
  A     r     | EPS   r/w   | KEY   r     | OPUS  r     | RWZ   r
  AA    r     | EPUB  r     | LA    r     | ORF   r/w   | RM    r
  AAX   r/w   | ERF   r/w   | LFP   r     | OTF   r     | SEQ   r
  ACR   r     | EXE   r     | LNK   r     | PAC   r     | SO    r
  AFM   r     | EXIF  r/w/c | M2TS  r     | PAGES r     | SR2   r/w
  AI    r/w   | EXR   r     | M4A/V r/w   | PBM   r/w   | SRF   r
  AIFF  r     | EXV   r/w/c | MAX   r     | PCD   r     | SRW   r/w
  APE   r     | F4A/V r/w   | MEF   r/w   | PDB   r     | SVG   r
  ARW   r/w   | FFF   r/w   | MIE   r/w/c | PDF   r/w   | SWF   r
  ASF   r     | FLA   r     | MIFF  r     | PEF   r/w   | THM   r/w
  AVI   r     | FLAC  r     | MKA   r     | PFA   r     | TIFF  r/w
  AZW   r     | FLIF  r/w   | MKS   r     | PFB   r     | TORRENT r
  BMP   r     | FLV   r     | MKV   r     | PFM   r     | TTC   r
  BPG   r     | FPF   r     | MNG   r/w   | PGF   r     | TTF   r
  BTF   r     | FPX   r     | MOBI  r     | PGM   r/w   | VCF   r
  CHM   r     | GIF   r/w   | MODD  r     | PLIST r     | VRD   r/w/c
  COS   r     | GZ    r     | MOI   r     | PICT  r     | VSD   r
  CR2   r/w   | HDP   r/w   | MOS   r/w   | PMP   r     | WAV   r
  CRW   r/w   | HDR   r     | MOV   r/w   | PNG   r/w   | WDP   r/w
  CS1   r/w   | HEIC  r     | MP3   r     | PPM   r/w   | WEBP  r
  DCM   r     | HEIF  r     | MP4   r/w   | PPT   r     | WEBM  r
  DCP   r/w   | HTML  r     | MPC   r     | PPTX  r     | WMA   r
  DCR   r     | ICC   r/w/c | MPG   r     | PS    r/w   | WMV   r
  DFONT r     | ICS   r     | MPO   r/w   | PSB   r/w   | WV    r
  DIVX  r     | IDML  r     | MQV   r/w   | PSD   r/w   | X3F   r/w
  DJVU  r     | IIQ   r/w   | MRW   r/w   | PSP   r     | XCF   r
  DLL   r     | IND   r/w   | MXF   r     | QTIF  r/w   | XLS   r
  DNG   r/w   | INX   r     | NEF   r/w   | RA    r     | XLSX  r
  DOC   r     | ISO   r     | NRW   r/w   | RAF   r/w   | XMP   r/w/c
  DOCX  r     | ITC   r     | NUMBERS r   | RAM   r     | ZIP   r
  DPX   r     | J2C   r     | O     r     | RAR   r     |
  DR4   r/w/c | JNG   r/w   | ODP   r     | RAW   r/w   |
  DSS   r     | JP2   r/w   | ODS   r     | RIFF  r     |
  DV    r     | JPEG  r/w   | ODT   r     | RSRC  r     |

  Meta Information
  ----------------------+----------------------+---------------------
  EXIF           r/w/c  |  CIFF           r/w  |  Ricoh RMETA    r
  GPS            r/w/c  |  AFCP           r/w  |  Picture Info   r
  IPTC           r/w/c  |  Kodak Meta     r/w  |  Adobe APP14    r
  XMP            r/w/c  |  FotoStation    r/w  |  MPF            r
  MakerNotes     r/w/c  |  PhotoMechanic  r/w  |  Stim           r
  Photoshop IRB  r/w/c  |  JPEG 2000      r    |  DPX            r
  ICC Profile    r/w/c  |  DICOM          r    |  APE            r
  MIE            r/w/c  |  Flash          r    |  Vorbis         r
  JFIF           r/w/c  |  FlashPix       r    |  SPIFF          r
  Ducky APP12    r/w/c  |  QuickTime      r    |  DjVu           r
  PDF            r/w/c  |  Matroska       r    |  M2TS           r
  PNG            r/w/c  |  MXF            r    |  PE/COFF        r
  Canon VRD      r/w/c  |  PrintIM        r    |  AVCHD          r
  Nikon Capture  r/w/c  |  FLAC           r    |  ZIP            r
  GeoTIFF        r/w/c  |  ID3            r    |  (and more)

See html/index.html for more details about ExifTool features.

%prep
%setup -n Image-ExifTool-%{version}

%build
perl Makefile.PL INSTALLDIRS=vendor

%install
rm -rf $RPM_BUILD_ROOT
%makeinstall DESTDIR=%{?buildroot:%{buildroot}}
find $RPM_BUILD_ROOT -name perllocal.pod | xargs rm

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%doc Changes html
%{_libdir}/perl5/*
/usr/share/*/*
%{_mandir}/*/*
%{_bindir}/*

%changelog
* Tue May 06 2014 - Norbert de Rooy <nsrderooy@gmail.com>
- Spec file fixed for Redhat 6
* Tue May 09 2006 - Niels Kristian Bech Jensen <nkbj@mail.tele.dk>
- Spec file fixed for Mandriva Linux 2006.
* Mon May 08 2006 - Volker Kuhlmann <VolkerKuhlmann@gmx.de>
- Spec file fixed for SUSE.
- Package available from: http://volker.dnsalias.net/soft/
* Sat Jun 19 2004 Kayvan Sylvan <kayvan@sylvan.com> - Image-ExifTool
- Initial build.
