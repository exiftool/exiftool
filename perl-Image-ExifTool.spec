Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 11.03
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
various manufacturers such as Canon, Casio, DJI, FLIR, FujiFilm, GE, GoPro,
HP, JVC/Victor, Kodak, Leaf, Minolta/Konica-Minolta, Nikon, Nintendo,
Olympus/Epson, Panasonic/Leica, Pentax/Asahi, Phase One, Reconyx, Ricoh,
Samsung, Sanyo, Sigma/Foveon and Sony.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

  File Types
  ------------+-------------+-------------+-------------+------------
  3FR   r     | DV    r     | JP2   r/w   | ODT   r     | RSRC  r
  3G2   r/w   | DVB   r/w   | JPEG  r/w   | OFR   r     | RTF   r
  3GP   r/w   | DVR-MS r    | JSON  r     | OGG   r     | RW2   r/w
  A     r     | DYLIB r     | K25   r     | OGV   r     | RWL   r/w
  AA    r     | EIP   r     | KDC   r     | OPUS  r     | RWZ   r
  AAX   r/w   | EPS   r/w   | KEY   r     | ORF   r/w   | RM    r
  ACR   r     | EPUB  r     | LA    r     | OTF   r     | SEQ   r
  AFM   r     | ERF   r/w   | LFP   r     | PAC   r     | SKETCH r
  AI    r/w   | EXE   r     | LNK   r     | PAGES r     | SO    r
  AIFF  r     | EXIF  r/w/c | M2TS  r     | PBM   r/w   | SR2   r/w
  APE   r     | EXR   r     | M4A/V r/w   | PCD   r     | SRF   r
  ARW   r/w   | EXV   r/w/c | MAX   r     | PDB   r     | SRW   r/w
  ASF   r     | F4A/V r/w   | MEF   r/w   | PDF   r/w   | SVG   r
  AVI   r     | FFF   r/w   | MIE   r/w/c | PEF   r/w   | SWF   r
  AZW   r     | FLA   r     | MIFF  r     | PFA   r     | THM   r/w
  BMP   r     | FLAC  r     | MKA   r     | PFB   r     | TIFF  r/w
  BPG   r     | FLIF  r/w   | MKS   r     | PFM   r     | TORRENT r
  BTF   r     | FLV   r     | MKV   r     | PGF   r     | TTC   r
  CHM   r     | FPF   r     | MNG   r/w   | PGM   r/w   | TTF   r
  COS   r     | FPX   r     | MOBI  r     | PLIST r     | VCF   r
  CR2   r/w   | GIF   r/w   | MODD  r     | PICT  r     | VRD   r/w/c
  CR3   r/w   | GPR   r/w   | MOI   r     | PMP   r     | VSD   r
  CRM   r/w   | GZ    r     | MOS   r/w   | PNG   r/w   | WAV   r
  CRW   r/w   | HDP   r/w   | MOV   r/w   | PPM   r/w   | WDP   r/w
  CS1   r/w   | HDR   r     | MP3   r     | PPT   r     | WEBP  r
  DCM   r     | HEIC  r     | MP4   r/w   | PPTX  r     | WEBM  r
  DCP   r/w   | HEIF  r     | MPC   r     | PS    r/w   | WMA   r
  DCR   r     | HTML  r     | MPG   r     | PSB   r/w   | WMV   r
  DFONT r     | ICC   r/w/c | MPO   r/w   | PSD   r/w   | WTV   r
  DIVX  r     | ICS   r     | MQV   r/w   | PSP   r     | WV    r
  DJVU  r     | IDML  r     | MRW   r/w   | QTIF  r/w   | X3F   r/w
  DLL   r     | IIQ   r/w   | MXF   r     | R3D   r     | XCF   r
  DNG   r/w   | IND   r/w   | NEF   r/w   | RA    r     | XLS   r
  DOC   r     | INX   r     | NRW   r/w   | RAF   r/w   | XLSX  r
  DOCX  r     | ISO   r     | NUMBERS r   | RAM   r     | XMP   r/w/c
  DPX   r     | ITC   r     | O     r     | RAR   r     | ZIP   r
  DR4   r/w/c | J2C   r     | ODP   r     | RAW   r/w   |
  DSS   r     | JNG   r/w   | ODS   r     | RIFF  r     |

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
