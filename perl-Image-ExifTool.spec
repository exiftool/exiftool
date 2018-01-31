Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 10.78
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
  3FR   r     | DVB   r/w   | JPEG  r/w   | ODT   r     | RIFF  r
  3G2   r/w   | DYLIB r     | JSON  r     | OFR   r     | RSRC  r
  3GP   r/w   | EIP   r     | K25   r     | OGG   r     | RTF   r
  A     r     | EPS   r/w   | KDC   r     | OGV   r     | RW2   r/w
  AA    r     | EPUB  r     | KEY   r     | OPUS  r     | RWL   r/w
  AAX   r/w   | ERF   r/w   | LA    r     | ORF   r/w   | RWZ   r
  ACR   r     | EXE   r     | LFP   r     | OTF   r     | RM    r
  AFM   r     | EXIF  r/w/c | LNK   r     | PAC   r     | SEQ   r
  AI    r/w   | EXR   r     | M2TS  r     | PAGES r     | SO    r
  AIFF  r     | EXV   r/w/c | M4A/V r/w   | PBM   r/w   | SR2   r/w
  APE   r     | F4A/V r/w   | MAX   r     | PCD   r     | SRF   r
  ARW   r/w   | FFF   r/w   | MEF   r/w   | PDB   r     | SRW   r/w
  ASF   r     | FLA   r     | MIE   r/w/c | PDF   r/w   | SVG   r
  AVI   r     | FLAC  r     | MIFF  r     | PEF   r/w   | SWF   r
  AZW   r     | FLIF  r/w   | MKA   r     | PFA   r     | THM   r/w
  BMP   r     | FLV   r     | MKS   r     | PFB   r     | TIFF  r/w
  BPG   r     | FPF   r     | MKV   r     | PFM   r     | TORRENT r
  BTF   r     | FPX   r     | MNG   r/w   | PGF   r     | TTC   r
  CHM   r     | GIF   r/w   | MOBI  r     | PGM   r/w   | TTF   r
  COS   r     | GPR   r/w   | MODD  r     | PLIST r     | VCF   r
  CR2   r/w   | GZ    r     | MOI   r     | PICT  r     | VRD   r/w/c
  CRW   r/w   | HDP   r/w   | MOS   r/w   | PMP   r     | VSD   r
  CS1   r/w   | HDR   r     | MOV   r/w   | PNG   r/w   | WAV   r
  DCM   r     | HEIC  r     | MP3   r     | PPM   r/w   | WDP   r/w
  DCP   r/w   | HEIF  r     | MP4   r/w   | PPT   r     | WEBP  r
  DCR   r     | HTML  r     | MPC   r     | PPTX  r     | WEBM  r
  DFONT r     | ICC   r/w/c | MPG   r     | PS    r/w   | WMA   r
  DIVX  r     | ICS   r     | MPO   r/w   | PSB   r/w   | WMV   r
  DJVU  r     | IDML  r     | MQV   r/w   | PSD   r/w   | WV    r
  DLL   r     | IIQ   r/w   | MRW   r/w   | PSP   r     | X3F   r/w
  DNG   r/w   | IND   r/w   | MXF   r     | QTIF  r/w   | XCF   r
  DOC   r     | INX   r     | NEF   r/w   | R3D   r     | XLS   r
  DOCX  r     | ISO   r     | NRW   r/w   | RA    r     | XLSX  r
  DPX   r     | ITC   r     | NUMBERS r   | RAF   r/w   | XMP   r/w/c
  DR4   r/w/c | J2C   r     | O     r     | RAM   r     | ZIP   r
  DSS   r     | JNG   r/w   | ODP   r     | RAR   r     |
  DV    r     | JP2   r/w   | ODS   r     | RAW   r/w   |

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
