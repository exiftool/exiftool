Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 12.08
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
  360   r/w   | DPX   r     | ITC   r     | ODP   r     | RSRC  r
  3FR   r     | DR4   r/w/c | J2C   r     | ODS   r     | RTF   r
  3G2   r/w   | DSS   r     | JNG   r/w   | ODT   r     | RW2   r/w
  3GP   r/w   | DV    r     | JP2   r/w   | OFR   r     | RWL   r/w
  A     r     | DVB   r/w   | JPEG  r/w   | OGG   r     | RWZ   r
  AA    r     | DVR-MS r    | JSON  r     | OGV   r     | RM    r
  AAE   r     | DYLIB r     | K25   r     | OPUS  r     | SEQ   r
  AAX   r/w   | EIP   r     | KDC   r     | ORF   r/w   | SKETCH r
  ACR   r     | EPS   r/w   | KEY   r     | OTF   r     | SO    r
  AFM   r     | EPUB  r     | LA    r     | PAC   r     | SR2   r/w
  AI    r/w   | ERF   r/w   | LFP   r     | PAGES r     | SRF   r
  AIFF  r     | EXE   r     | LNK   r     | PBM   r/w   | SRW   r/w
  APE   r     | EXIF  r/w/c | LRV   r/w   | PCD   r     | SVG   r
  ARQ   r/w   | EXR   r     | M2TS  r     | PCX   r     | SWF   r
  ARW   r/w   | EXV   r/w/c | M4A/V r/w   | PDB   r     | THM   r/w
  ASF   r     | F4A/V r/w   | MACOS r     | PDF   r/w   | TIFF  r/w
  AVI   r     | FFF   r/w   | MAX   r     | PEF   r/w   | TORRENT r
  AVIF  r/w   | FITS  r     | MEF   r/w   | PFA   r     | TTC   r
  AZW   r     | FLA   r     | MIE   r/w/c | PFB   r     | TTF   r
  BMP   r     | FLAC  r     | MIFF  r     | PFM   r     | TXT   r
  BPG   r     | FLIF  r/w   | MKA   r     | PGF   r     | VCF   r
  BTF   r     | FLV   r     | MKS   r     | PGM   r/w   | VRD   r/w/c
  CHM   r     | FPF   r     | MKV   r     | PLIST r     | VSD   r
  COS   r     | FPX   r     | MNG   r/w   | PICT  r     | WAV   r
  CR2   r/w   | GIF   r/w   | MOBI  r     | PMP   r     | WDP   r/w
  CR3   r/w   | GPR   r/w   | MODD  r     | PNG   r/w   | WEBP  r
  CRM   r/w   | GZ    r     | MOI   r     | PPM   r/w   | WEBM  r
  CRW   r/w   | HDP   r/w   | MOS   r/w   | PPT   r     | WMA   r
  CS1   r/w   | HDR   r     | MOV   r/w   | PPTX  r     | WMV   r
  CSV   r     | HEIC  r/w   | MP3   r     | PS    r/w   | WTV   r
  CZI   r     | HEIF  r/w   | MP4   r/w   | PSB   r/w   | WV    r
  DCM   r     | HTML  r     | MPC   r     | PSD   r/w   | X3F   r/w
  DCP   r/w   | ICC   r/w/c | MPG   r     | PSP   r     | XCF   r
  DCR   r     | ICS   r     | MPO   r/w   | QTIF  r/w   | XLS   r
  DFONT r     | IDML  r     | MQV   r/w   | R3D   r     | XLSX  r
  DIVX  r     | IIQ   r/w   | MRW   r/w   | RA    r     | XMP   r/w/c
  DJVU  r     | IND   r/w   | MXF   r     | RAF   r/w   | ZIP   r
  DLL   r     | INSP  r/w   | NEF   r/w   | RAM   r     |
  DNG   r/w   | INSV  r     | NRW   r/w   | RAR   r     |
  DOC   r     | INX   r     | NUMBERS r   | RAW   r/w   |
  DOCX  r     | ISO   r     | O     r     | RIFF  r     |

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
