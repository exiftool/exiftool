Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 10.51
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
  3FR   r     | DV    r     | JSON  r     | ODT   r     | RIFF  r
  3G2   r/w   | DVB   r/w   | K25   r     | OFR   r     | RSRC  r
  3GP   r/w   | DYLIB r     | KDC   r     | OGG   r     | RTF   r
  A     r     | EIP   r     | KEY   r     | OGV   r     | RW2   r/w
  AA    r     | EPS   r/w   | LA    r     | OPUS  r     | RWL   r/w
  AAX   r/w   | EPUB  r     | LFP   r     | ORF   r/w   | RWZ   r
  ACR   r     | ERF   r/w   | LNK   r     | OTF   r     | RM    r
  AFM   r     | EXE   r     | M2TS  r     | PAC   r     | SEQ   r
  AI    r/w   | EXIF  r/w/c | M4A/V r/w   | PAGES r     | SO    r
  AIFF  r     | EXR   r     | MAX   r     | PBM   r/w   | SR2   r/w
  APE   r     | EXV   r/w/c | MEF   r/w   | PCD   r     | SRF   r
  ARW   r/w   | F4A/V r/w   | MIE   r/w/c | PDB   r     | SRW   r/w
  ASF   r     | FFF   r/w   | MIFF  r     | PDF   r/w   | SVG   r
  AVI   r     | FLA   r     | MKA   r     | PEF   r/w   | SWF   r
  AZW   r     | FLAC  r     | MKS   r     | PFA   r     | THM   r/w
  BMP   r     | FLIF  r/w   | MKV   r     | PFB   r     | TIFF  r/w
  BPG   r     | FLV   r     | MNG   r/w   | PFM   r     | TORRENT r
  BTF   r     | FPF   r     | MOBI  r     | PGF   r     | TTC   r
  CHM   r     | FPX   r     | MODD  r     | PGM   r/w   | TTF   r
  COS   r     | GIF   r/w   | MOI   r     | PLIST r     | VCF   r
  CR2   r/w   | GZ    r     | MOS   r/w   | PICT  r     | VRD   r/w/c
  CRW   r/w   | HDP   r/w   | MOV   r/w   | PMP   r     | VSD   r
  CS1   r/w   | HDR   r     | MP3   r     | PNG   r/w   | WAV   r
  DCM   r     | HTML  r     | MP4   r/w   | PPM   r/w   | WDP   r/w
  DCP   r/w   | ICC   r/w/c | MPC   r     | PPT   r     | WEBP  r
  DCR   r     | ICS   r     | MPG   r     | PPTX  r     | WEBM  r
  DFONT r     | IDML  r     | MPO   r/w   | PS    r/w   | WMA   r
  DIVX  r     | IIQ   r/w   | MQV   r/w   | PSB   r/w   | WMV   r
  DJVU  r     | IND   r/w   | MRW   r/w   | PSD   r/w   | WV    r
  DLL   r     | INX   r     | MXF   r     | PSP   r     | X3F   r/w
  DNG   r/w   | ISO   r     | NEF   r/w   | QTIF  r/w   | XCF   r
  DOC   r     | ITC   r     | NRW   r/w   | RA    r     | XLS   r
  DOCX  r     | J2C   r     | NUMBERS r   | RAF   r/w   | XLSX  r
  DPX   r     | JNG   r/w   | O     r     | RAM   r     | XMP   r/w/c
  DR4   r/w/c | JP2   r/w   | ODP   r     | RAR   r     | ZIP   r
  DSS   r     | JPEG  r/w   | ODS   r     | RAW   r/w   |

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
