Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 13.09
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
  360   r/w   | DOCX  r     | ITC   r     | NUMBERS r   | RAW   r/w
  3FR   r     | DPX   r     | J2C   r     | NXD   r     | RIFF  r
  3G2   r/w   | DR4   r/w/c | JNG   r/w   | O     r     | RSRC  r
  3GP   r/w   | DSS   r     | JP2   r/w   | ODP   r     | RTF   r
  7Z    r     | DV    r     | JPEG  r/w   | ODS   r     | RW2   r/w
  A     r     | DVB   r/w   | JSON  r     | ODT   r     | RWL   r/w
  AA    r     | DVR-MS r    | JXL   r/w   | OFR   r     | RWZ   r
  AAC   r     | DYLIB r     | K25   r     | OGG   r     | RM    r
  AAE   r     | EIP   r     | KDC   r     | OGV   r     | SEQ   r
  AAX   r/w   | EPS   r/w   | KEY   r     | ONP   r     | SKETCH r
  ACR   r     | EPUB  r     | LA    r     | OPUS  r     | SO    r
  AFM   r     | ERF   r/w   | LFP   r     | ORF   r/w   | SR2   r/w
  AI    r/w   | EXE   r     | LIF   r     | ORI   r/w   | SRF   r
  AIFF  r     | EXIF  r/w/c | LNK   r     | OTF   r     | SRW   r/w
  APE   r     | EXR   r     | LRV   r/w   | PAC   r     | SVG   r
  ARQ   r/w   | EXV   r/w/c | M2TS  r     | PAGES r     | SWF   r
  ARW   r/w   | F4A/V r/w   | M4A/V r/w   | PBM   r/w   | THM   r/w
  ASF   r     | FFF   r/w   | MACOS r     | PCD   r     | TIFF  r/w
  AVI   r     | FITS  r     | MAX   r     | PCX   r     | TORRENT r
  AVIF  r/w   | FLA   r     | MEF   r/w   | PDB   r     | TTC   r
  AZW   r     | FLAC  r     | MIE   r/w/c | PDF   r/w   | TTF   r
  BMP   r     | FLIF  r/w   | MIFF  r     | PEF   r/w   | TXT   r
  BPG   r     | FLV   r     | MKA   r     | PFA   r     | VCF   r
  BTF   r     | FPF   r     | MKS   r     | PFB   r     | VNT   r
  C2PA  r     | FPX   r     | MKV   r     | PFM   r     | VRD   r/w/c
  CHM   r     | GIF   r/w   | MNG   r/w   | PGF   r     | VSD   r
  COS   r     | GLV   r/w   | MOBI  r     | PGM   r/w   | WAV   r
  CR2   r/w   | GPR   r/w   | MODD  r     | PLIST r     | WDP   r/w
  CR3   r/w   | GZ    r     | MOI   r     | PICT  r     | WEBP  r/w
  CRM   r/w   | HDP   r/w   | MOS   r/w   | PMP   r     | WEBM  r
  CRW   r/w   | HDR   r     | MOV   r/w   | PNG   r/w   | WMA   r
  CS1   r/w   | HEIC  r/w   | MP3   r     | PPM   r/w   | WMV   r
  CSV   r     | HEIF  r/w   | MP4   r/w   | PPT   r     | WPG   r
  CUR   r     | HTML  r     | MPC   r     | PPTX  r     | WTV   r
  CZI   r     | ICC   r/w/c | MPG   r     | PS    r/w   | WV    r
  DCM   r     | ICO   r     | MPO   r/w   | PSB   r/w   | X3F   r/w
  DCP   r/w   | ICS   r     | MQV   r/w   | PSD   r/w   | XCF   r
  DCR   r     | IDML  r     | MRC   r     | PSP   r     | XISF  r
  DFONT r     | IIQ   r/w   | MRW   r/w   | QTIF  r/w   | XLS   r
  DIVX  r     | IND   r/w   | MXF   r     | R3D   r     | XLSX  r
  DJVU  r     | INSP  r/w   | NEF   r/w   | RA    r     | XMP   r/w/c
  DLL   r     | INSV  r     | NKA   r     | RAF   r/w   | ZIP   r
  DNG   r/w   | INX   r     | NKSC  r/w   | RAM   r     |
  DOC   r     | ISO   r     | NRW   r/w   | RAR   r     |

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
