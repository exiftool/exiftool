Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 13.42
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
  360   r/w   | DR4   r/w/c | JP2   r/w   | ODT   r     | RWL   r/w
  3FR   r     | DSF   r     | JPEG  r/w   | OFR   r     | RWZ   r
  3G2   r/w   | DSS   r     | JSON  r     | OGG   r     | RM    r
  3GP   r/w   | DV    r     | JXL   r/w   | OGV   r     | SEQ   r
  7Z    r     | DVB   r/w   | K25   r     | ONP   r     | SKETCH r
  A     r     | DVR-MS r    | KDC   r     | OPUS  r     | SO    r
  AA    r     | DYLIB r     | KEY   r     | ORF   r/w   | SR2   r/w
  AAC   r     | EIP   r     | LA    r     | ORI   r/w   | SRF   r
  AAE   r     | EPS   r/w   | LFP   r     | OTF   r     | SRW   r/w
  AAX   r/w   | EPUB  r     | LIF   r     | PAC   r     | SVG   r
  ACR   r     | ERF   r/w   | LNK   r     | PAGES r     | SWF   r
  AFM   r     | EXE   r     | LRV   r/w   | PBM   r/w   | THM   r/w
  AI    r/w   | EXIF  r/w/c | M2TS  r     | PCAP  r     | TIFF  r/w
  AIFF  r     | EXR   r     | M4A/V r/w   | PCAPNG r    | TNEF  r
  APE   r     | EXV   r/w/c | MACOS r     | PCD   r     | TORRENT r
  ARQ   r/w   | F4A/V r/w   | MAX   r     | PCX   r     | TTC   r
  ARW   r/w   | FFF   r/w   | MEF   r/w   | PDB   r     | TTF   r
  ASF   r     | FITS  r     | MIE   r/w/c | PDF   r/w   | TXT   r
  AVI   r     | FLA   r     | MIFF  r     | PEF   r/w   | URL   r
  AVIF  r/w   | FLAC  r     | MKA   r     | PFA   r     | VCF   r
  AZW   r     | FLIF  r/w   | MKS   r     | PFB   r     | VNT   r
  BMP   r     | FLV   r     | MKV   r     | PFM   r     | VRD   r/w/c
  BPG   r     | FPF   r     | MNG   r/w   | PGF   r     | VSD   r
  BTF   r     | FPX   r     | MOBI  r     | PGM   r/w   | VSDX  r
  C2PA  r     | GIF   r/w   | MODD  r     | PLIST r     | WAV   r
  CHM   r     | GLV   r/w   | MOI   r     | PICT  r     | WDP   r/w
  COS   r     | GPR   r/w   | MOS   r/w   | PMP   r     | WEBP  r/w
  CR2   r/w   | GZ    r     | MOV   r/w   | PNG   r/w   | WEBM  r
  CR3   r/w   | HDP   r/w   | MP3   r     | PPM   r/w   | WMA   r
  CRM   r/w   | HDR   r     | MP4   r/w   | PPT   r     | WMV   r
  CRW   r/w   | HEIC  r/w   | MPC   r     | PPTX  r     | WOFF  r
  CS1   r/w   | HEIF  r/w   | MPG   r     | PS    r/w   | WOFF2 r
  CSV   r     | HTML  r     | MPO   r/w   | PSB   r/w   | WPG   r
  CUR   r     | ICC   r/w/c | MQV   r/w   | PSD   r/w   | WTV   r
  CZI   r     | ICO   r     | MRC   r     | PSP   r     | WV    r
  DCM   r     | ICS   r     | MRW   r/w   | QTIF  r/w   | X3F   r/w
  DCP   r/w   | IDML  r     | MXF   r     | R3D   r     | XCF   r
  DCR   r     | IIQ   r/w   | NEF   r/w   | RA    r     | XISF  r
  DFONT r     | IND   r/w   | NKA   r     | RAF   r/w   | XLS   r
  DIVX  r     | INSP  r/w   | NKSC  r/w   | RAM   r     | XLSX  r
  DJVU  r     | INSV  r     | NRW   r/w   | RAR   r     | XMP   r/w/c
  DLL   r     | INX   r     | NUMBERS r   | RAW   r/w   | ZIP   r
  DNG   r/w   | ISO   r     | NXD   r     | RIFF  r     |
  DOC   r     | ITC   r     | O     r     | RSRC  r     |
  DOCX  r     | J2C   r     | ODP   r     | RTF   r     |
  DPX   r     | JNG   r/w   | ODS   r     | RW2   r/w   |

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
