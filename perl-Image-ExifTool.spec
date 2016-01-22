Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 10.10
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
  3FR   r     | DVB   r/w   | KEY   r     | ORF   r/w   | RWL   r/w
  3G2   r/w   | DYLIB r     | LA    r     | OTF   r     | RWZ   r
  3GP   r/w   | EIP   r     | LFP   r     | PAC   r     | RM    r
  AA    r     | EPS   r/w   | LNK   r     | PAGES r     | SEQ   r
  AAX   r/w   | EPUB  r     | M2TS  r     | PBM   r/w   | SO    r
  ACR   r     | ERF   r/w   | M4A/V r/w   | PCD   r     | SR2   r/w
  AFM   r     | EXE   r     | MEF   r/w   | PDB   r     | SRF   r
  AI    r/w   | EXIF  r/w/c | MIE   r/w/c | PDF   r/w   | SRW   r/w
  AIFF  r     | EXR   r     | MIFF  r     | PEF   r/w   | SVG   r
  APE   r     | EXV   r/w/c | MKA   r     | PFA   r     | SWF   r
  ARW   r/w   | F4A/V r/w   | MKS   r     | PFB   r     | THM   r/w
  ASF   r     | FFF   r/w   | MKV   r     | PFM   r     | TIFF  r/w
  AVI   r     | FLA   r     | MNG   r/w   | PGF   r     | TORRENT r
  AZW   r     | FLAC  r     | MOBI  r     | PGM   r/w   | TTC   r
  BMP   r     | FLV   r     | MODD  r     | PLIST r     | TTF   r
  BTF   r     | FPF   r     | MOI   r     | PICT  r     | VCF   r
  CHM   r     | FPX   r     | MOS   r/w   | PMP   r     | VRD   r/w/c
  COS   r     | GIF   r/w   | MOV   r/w   | PNG   r/w   | VSD   r
  CR2   r/w   | GZ    r     | MP3   r     | PPM   r/w   | WAV   r
  CRW   r/w   | HDP   r/w   | MP4   r/w   | PPT   r     | WDP   r/w
  CS1   r/w   | HDR   r     | MPC   r     | PPTX  r     | WEBP  r
  DCM   r     | HTML  r     | MPG   r     | PS    r/w   | WEBM  r
  DCP   r/w   | ICC   r/w/c | MPO   r/w   | PSB   r/w   | WMA   r
  DCR   r     | ICS   r     | MQV   r/w   | PSD   r/w   | WMV   r
  DFONT r     | IDML  r     | MRW   r/w   | PSP   r     | WV    r
  DIVX  r     | IIQ   r/w   | MXF   r     | QTIF  r/w   | X3F   r/w
  DJVU  r     | IND   r/w   | NEF   r/w   | RA    r     | XCF   r
  DLL   r     | INX   r     | NRW   r/w   | RAF   r/w   | XLS   r
  DNG   r/w   | ITC   r     | NUMBERS r   | RAM   r     | XLSX  r
  DOC   r     | J2C   r     | ODP   r     | RAR   r     | XMP   r/w/c
  DOCX  r     | JNG   r/w   | ODS   r     | RAW   r/w   | ZIP   r
  DPX   r     | JP2   r/w   | ODT   r     | RIFF  r     |
  DR4   r/w/c | JPEG  r/w   | OFR   r     | RSRC  r     |
  DSS   r     | K25   r     | OGG   r     | RTF   r     |
  DV    r     | KDC   r     | OGV   r     | RW2   r/w   |

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
