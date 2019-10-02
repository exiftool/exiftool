Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 11.69
Release: 1
License: Artistic/GPL
Group: Development/Libraries/Perl
URL: http://owl.phy.queensu.ca/~phil/exiftool/
Source0: Image-ExifTool-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
ExifTool is a customizable set of Perl modules plus a full-featured
command-line application for reading and writing meta information in a wide
variety of files, including the maker note information of many digital
cameras by various manufacturers such as Canon, Casio, DJI, FLIR, FujiFilm,
GE, GoPro, HP, JVC/Victor, Kodak, Leaf, Minolta/Konica-Minolta, Nikon,
Nintendo, Olympus/Epson, Panasonic/Leica, Pentax/Asahi, Phase One, Reconyx,
Ricoh, Samsung, Sanyo, Sigma/Foveon and Sony.

Below is a list of file types and meta information formats currently
supported by ExifTool (r = read, w = write, c = create):

  File Types
  ------------+-------------+-------------+-------------+------------
  3FR   r     | DSS   r     | J2C   r     | ODP   r     | RAW   r/w
  3G2   r/w   | DV    r     | JNG   r/w   | ODS   r     | RIFF  r
  3GP   r/w   | DVB   r/w   | JP2   r/w   | ODT   r     | RSRC  r
  A     r     | DVR-MS r    | JPEG  r/w   | OFR   r     | RTF   r
  AA    r     | DYLIB r     | JSON  r     | OGG   r     | RW2   r/w
  AAE   r     | EIP   r     | K25   r     | OGV   r     | RWL   r/w
  AAX   r/w   | EPS   r/w   | KDC   r     | OPUS  r     | RWZ   r
  ACR   r     | EPUB  r     | KEY   r     | ORF   r/w   | RM    r
  AFM   r     | ERF   r/w   | LA    r     | OTF   r     | SEQ   r
  AI    r/w   | EXE   r     | LFP   r     | PAC   r     | SKETCH r
  AIFF  r     | EXIF  r/w/c | LNK   r     | PAGES r     | SO    r
  APE   r     | EXR   r     | LRV   r/w   | PBM   r/w   | SR2   r/w
  ARQ   r/w   | EXV   r/w/c | M2TS  r     | PCD   r     | SRF   r
  ARW   r/w   | F4A/V r/w   | M4A/V r/w   | PCX   r     | SRW   r/w
  ASF   r     | FFF   r/w   | MAX   r     | PDB   r     | SVG   r
  AVI   r     | FITS  r     | MEF   r/w   | PDF   r/w   | SWF   r
  AZW   r     | FLA   r     | MIE   r/w/c | PEF   r/w   | THM   r/w
  BMP   r     | FLAC  r     | MIFF  r     | PFA   r     | TIFF  r/w
  BPG   r     | FLIF  r/w   | MKA   r     | PFB   r     | TORRENT r
  BTF   r     | FLV   r     | MKS   r     | PFM   r     | TTC   r
  CHM   r     | FPF   r     | MKV   r     | PGF   r     | TTF   r
  COS   r     | FPX   r     | MNG   r/w   | PGM   r/w   | VCF   r
  CR2   r/w   | GIF   r/w   | MOBI  r     | PLIST r     | VRD   r/w/c
  CR3   r/w   | GPR   r/w   | MODD  r     | PICT  r     | VSD   r
  CRM   r/w   | GZ    r     | MOI   r     | PMP   r     | WAV   r
  CRW   r/w   | HDP   r/w   | MOS   r/w   | PNG   r/w   | WDP   r/w
  CS1   r/w   | HDR   r     | MOV   r/w   | PPM   r/w   | WEBP  r
  DCM   r     | HEIC  r/w   | MP3   r     | PPT   r     | WEBM  r
  DCP   r/w   | HEIF  r/w   | MP4   r/w   | PPTX  r     | WMA   r
  DCR   r     | HTML  r     | MPC   r     | PS    r/w   | WMV   r
  DFONT r     | ICC   r/w/c | MPG   r     | PSB   r/w   | WTV   r
  DIVX  r     | ICS   r     | MPO   r/w   | PSD   r/w   | WV    r
  DJVU  r     | IDML  r     | MQV   r/w   | PSP   r     | X3F   r/w
  DLL   r     | IIQ   r/w   | MRW   r/w   | QTIF  r/w   | XCF   r
  DNG   r/w   | IND   r/w   | MXF   r     | R3D   r     | XLS   r
  DOC   r     | INSV  r     | NEF   r/w   | RA    r     | XLSX  r
  DOCX  r     | INX   r     | NRW   r/w   | RAF   r/w   | XMP   r/w/c
  DPX   r     | ISO   r     | NUMBERS r   | RAM   r     | ZIP   r
  DR4   r/w/c | ITC   r     | O     r     | RAR   r     |

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
