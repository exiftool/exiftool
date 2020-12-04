Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 12.12
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
  360   r/w   | DPX   r     | ITC   r     | ODP   r     | RIFF  r
  3FR   r     | DR4   r/w/c | J2C   r     | ODS   r     | RSRC  r
  3G2   r/w   | DSS   r     | JNG   r/w   | ODT   r     | RTF   r
  3GP   r/w   | DV    r     | JP2   r/w   | OFR   r     | RW2   r/w
  A     r     | DVB   r/w   | JPEG  r/w   | OGG   r     | RWL   r/w
  AA    r     | DVR-MS r    | JSON  r     | OGV   r     | RWZ   r
  AAE   r     | DYLIB r     | K25   r     | ONP   r     | RM    r
  AAX   r/w   | EIP   r     | KDC   r     | OPUS  r     | SEQ   r
  ACR   r     | EPS   r/w   | KEY   r     | ORF   r/w   | SKETCH r
  AFM   r     | EPUB  r     | LA    r     | OTF   r     | SO    r
  AI    r/w   | ERF   r/w   | LFP   r     | PAC   r     | SR2   r/w
  AIFF  r     | EXE   r     | LNK   r     | PAGES r     | SRF   r
  APE   r     | EXIF  r/w/c | LRV   r/w   | PBM   r/w   | SRW   r/w
  ARQ   r/w   | EXR   r     | M2TS  r     | PCD   r     | SVG   r
  ARW   r/w   | EXV   r/w/c | M4A/V r/w   | PCX   r     | SWF   r
  ASF   r     | F4A/V r/w   | MACOS r     | PDB   r     | THM   r/w
  AVI   r     | FFF   r/w   | MAX   r     | PDF   r/w   | TIFF  r/w
  AVIF  r/w   | FITS  r     | MEF   r/w   | PEF   r/w   | TORRENT r
  AZW   r     | FLA   r     | MIE   r/w/c | PFA   r     | TTC   r
  BMP   r     | FLAC  r     | MIFF  r     | PFB   r     | TTF   r
  BPG   r     | FLIF  r/w   | MKA   r     | PFM   r     | TXT   r
  BTF   r     | FLV   r     | MKS   r     | PGF   r     | VCF   r
  CHM   r     | FPF   r     | MKV   r     | PGM   r/w   | VRD   r/w/c
  COS   r     | FPX   r     | MNG   r/w   | PLIST r     | VSD   r
  CR2   r/w   | GIF   r/w   | MOBI  r     | PICT  r     | WAV   r
  CR3   r/w   | GPR   r/w   | MODD  r     | PMP   r     | WDP   r/w
  CRM   r/w   | GZ    r     | MOI   r     | PNG   r/w   | WEBP  r
  CRW   r/w   | HDP   r/w   | MOS   r/w   | PPM   r/w   | WEBM  r
  CS1   r/w   | HDR   r     | MOV   r/w   | PPT   r     | WMA   r
  CSV   r     | HEIC  r/w   | MP3   r     | PPTX  r     | WMV   r
  CZI   r     | HEIF  r/w   | MP4   r/w   | PS    r/w   | WTV   r
  DCM   r     | HTML  r     | MPC   r     | PSB   r/w   | WV    r
  DCP   r/w   | ICC   r/w/c | MPG   r     | PSD   r/w   | X3F   r/w
  DCR   r     | ICS   r     | MPO   r/w   | PSP   r     | XCF   r
  DFONT r     | IDML  r     | MQV   r/w   | QTIF  r/w   | XLS   r
  DIVX  r     | IIQ   r/w   | MRW   r/w   | R3D   r     | XLSX  r
  DJVU  r     | IND   r/w   | MXF   r     | RA    r     | XMP   r/w/c
  DLL   r     | INSP  r/w   | NEF   r/w   | RAF   r/w   | ZIP   r
  DNG   r/w   | INSV  r     | NRW   r/w   | RAM   r     |
  DOC   r     | INX   r     | NUMBERS r   | RAR   r     |
  DOCX  r     | ISO   r     | O     r     | RAW   r/w   |

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
