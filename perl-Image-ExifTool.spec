Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 12.37
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
  360   r/w   | DR4   r/w/c | JNG   r/w   | ODP   r     | RIFF  r
  3FR   r     | DSS   r     | JP2   r/w   | ODS   r     | RSRC  r
  3G2   r/w   | DV    r     | JPEG  r/w   | ODT   r     | RTF   r
  3GP   r/w   | DVB   r/w   | JSON  r     | OFR   r     | RW2   r/w
  A     r     | DVR-MS r    | JXL   r     | OGG   r     | RWL   r/w
  AA    r     | DYLIB r     | K25   r     | OGV   r     | RWZ   r
  AAE   r     | EIP   r     | KDC   r     | ONP   r     | RM    r
  AAX   r/w   | EPS   r/w   | KEY   r     | OPUS  r     | SEQ   r
  ACR   r     | EPUB  r     | LA    r     | ORF   r/w   | SKETCH r
  AFM   r     | ERF   r/w   | LFP   r     | ORI   r/w   | SO    r
  AI    r/w   | EXE   r     | LIF   r     | OTF   r     | SR2   r/w
  AIFF  r     | EXIF  r/w/c | LNK   r     | PAC   r     | SRF   r
  APE   r     | EXR   r     | LRV   r/w   | PAGES r     | SRW   r/w
  ARQ   r/w   | EXV   r/w/c | M2TS  r     | PBM   r/w   | SVG   r
  ARW   r/w   | F4A/V r/w   | M4A/V r/w   | PCD   r     | SWF   r
  ASF   r     | FFF   r/w   | MACOS r     | PCX   r     | THM   r/w
  AVI   r     | FITS  r     | MAX   r     | PDB   r     | TIFF  r/w
  AVIF  r/w   | FLA   r     | MEF   r/w   | PDF   r/w   | TORRENT r
  AZW   r     | FLAC  r     | MIE   r/w/  | PEF   r/w   | TTC   r
  BMP   r     | FLIF  r/w   | MIFF  r   c | PFA   r     | TTF   r
  BPG   r     | FLV   r     | MKA   r     | PFB   r     | TXT   r
  BTF   r     | FPF   r     | MKS   r     | PFM   r     | VCF   r
  CHM   r     | FPX   r     | MKV   r     | PGF   r     | VRD   r/w/c
  COS   r     | GIF   r/w   | MNG   r/w   | PGM   r/w   | VSD   r
  CR2   r/w   | GPR   r/w   | MOBI  r     | PLIST r     | WAV   r
  CR3   r/w   | GZ    r     | MODD  r     | PICT  r     | WDP   r/w
  CRM   r/w   | HDP   r/w   | MOI   r     | PMP   r     | WEBP  r
  CRW   r/w   | HDR   r     | MOS   r/w   | PNG   r/w   | WEBM  r
  CS1   r/w   | HEIC  r/w   | MOV   r/w   | PPM   r/w   | WMA   r
  CSV   r     | HEIF  r/w   | MP3   r     | PPT   r     | WMV   r
  CZI   r     | HTML  r     | MP4   r/w   | PPTX  r     | WTV   r
  DCM   r     | ICC   r/w/c | MPC   r     | PS    r/w   | WV    r
  DCP   r/w   | ICS   r     | MPG   r     | PSB   r/w   | X3F   r/w
  DCR   r     | IDML  r     | MPO   r/w   | PSD   r/w   | XCF   r
  DFONT r     | IIQ   r/w   | MQV   r/w   | PSP   r     | XLS   r
  DIVX  r     | IND   r/w   | MRC   r     | QTIF  r/w   | XLSX  r
  DJVU  r     | INSP  r/w   | MRW   r/w   | R3D   r     | XMP   r/w/c
  DLL   r     | INSV  r     | MXF   r     | RA    r     | ZIP   r
  DNG   r/w   | INX   r     | NEF   r/w   | RAF   r/w   |
  DOC   r     | ISO   r     | NRW   r/w   | RAM   r     |
  DOCX  r     | ITC   r     | NUMBERS r   | RAR   r     |
  DPX   r     | J2C   r     | O     r     | RAW   r/w   |

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
