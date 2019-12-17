Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 11.80
Release: 1
License: Artistic/GPL
Group: Development/Libraries/Perl
URL: https://exiftool.org/
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
  3FR   r     | DSS   r     | JNG   r/w   | ODT   r     | RTF   r
  3G2   r/w   | DV    r     | JP2   r/w   | OFR   r     | RW2   r/w
  3GP   r/w   | DVB   r/w   | JPEG  r/w   | OGG   r     | RWL   r/w
  A     r     | DVR-MS r    | JSON  r     | OGV   r     | RWZ   r
  AA    r     | DYLIB r     | K25   r     | OPUS  r     | RM    r
  AAE   r     | EIP   r     | KDC   r     | ORF   r/w   | SEQ   r
  AAX   r/w   | EPS   r/w   | KEY   r     | OTF   r     | SKETCH r
  ACR   r     | EPUB  r     | LA    r     | PAC   r     | SO    r
  AFM   r     | ERF   r/w   | LFP   r     | PAGES r     | SR2   r/w
  AI    r/w   | EXE   r     | LNK   r     | PBM   r/w   | SRF   r
  AIFF  r     | EXIF  r/w/c | LRV   r/w   | PCD   r     | SRW   r/w
  APE   r     | EXR   r     | M2TS  r     | PCX   r     | SVG   r
  ARQ   r/w   | EXV   r/w/c | M4A/V r/w   | PDB   r     | SWF   r
  ARW   r/w   | F4A/V r/w   | MAX   r     | PDF   r/w   | THM   r/w
  ASF   r     | FFF   r/w   | MEF   r/w   | PEF   r/w   | TIFF  r/w
  AVI   r     | FITS  r     | MIE   r/w/c | PFA   r     | TORRENT r
  AVIF  r/w   | FLA   r     | MIFF  r     | PFB   r     | TTC   r
  AZW   r     | FLAC  r     | MKA   r     | PFM   r     | TTF   r
  BMP   r     | FLIF  r/w   | MKS   r     | PGF   r     | TXT   r
  BPG   r     | FLV   r     | MKV   r     | PGM   r/w   | VCF   r
  BTF   r     | FPF   r     | MNG   r/w   | PLIST r     | VRD   r/w/c
  CHM   r     | FPX   r     | MOBI  r     | PICT  r     | VSD   r
  COS   r     | GIF   r/w   | MODD  r     | PMP   r     | WAV   r
  CR2   r/w   | GPR   r/w   | MOI   r     | PNG   r/w   | WDP   r/w
  CR3   r/w   | GZ    r     | MOS   r/w   | PPM   r/w   | WEBP  r
  CRM   r/w   | HDP   r/w   | MOV   r/w   | PPT   r     | WEBM  r
  CRW   r/w   | HDR   r     | MP3   r     | PPTX  r     | WMA   r
  CS1   r/w   | HEIC  r/w   | MP4   r/w   | PS    r/w   | WMV   r
  DCM   r     | HEIF  r/w   | MPC   r     | PSB   r/w   | WTV   r
  DCP   r/w   | HTML  r     | MPG   r     | PSD   r/w   | WV    r
  DCR   r     | ICC   r/w/c | MPO   r/w   | PSP   r     | X3F   r/w
  DFONT r     | ICS   r     | MQV   r/w   | QTIF  r/w   | XCF   r
  DIVX  r     | IDML  r     | MRW   r/w   | R3D   r     | XLS   r
  DJVU  r     | IIQ   r/w   | MXF   r     | RA    r     | XLSX  r
  DLL   r     | IND   r/w   | NEF   r/w   | RAF   r/w   | XMP   r/w/c
  DNG   r/w   | INSV  r     | NRW   r/w   | RAM   r     | ZIP   r
  DOC   r     | INX   r     | NUMBERS r   | RAR   r     |
  DOCX  r     | ISO   r     | O     r     | RAW   r/w   |
  DPX   r     | ITC   r     | ODP   r     | RIFF  r     |
  DR4   r/w/c | J2C   r     | ODS   r     | RSRC  r     |

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
