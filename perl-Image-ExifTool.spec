Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 13.56
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
  360   r/w   | DR4   r/w/c | JNG   r/w   | ODP   r     | RTF   r
  3FR   r     | DSF   r     | JP2   r/w   | ODS   r     | RW2   r/w
  3G2   r/w   | DSS   r     | JPEG  r/w   | ODT   r     | RWL   r/w
  3GP   r/w   | DV    r     | JSON  r     | OFR   r     | RWZ   r
  7Z    r     | DVB   r/w   | JXL   r/w   | OGG   r     | RM    r
  A     r     | DVR-MS r    | K25   r     | OGV   r     | SEQ   r
  AA    r     | DYLIB r     | KDC   r     | ONP   r     | SKETCH r
  AAC   r     | EIP   r     | KEY   r     | OPUS  r     | SO    r
  AAE   r     | EPS   r/w   | KVAR  r     | ORF   r/w   | SR2   r/w
  AAX   r/w   | EPUB  r     | LA    r     | ORI   r/w   | SRF   r
  ACR   r     | ERF   r/w   | LFP   r     | OTF   r     | SRW   r/w
  AFM   r     | EXE   r     | LIF   r     | PAC   r     | SVG   r
  AI    r/w   | EXIF  r/w/c | LNK   r     | PAGES r     | SWF   r
  AIFF  r     | EXR   r     | LRV   r/w   | PBM   r/w   | THM   r/w
  APE   r     | EXV   r/w/c | M2TS  r     | PCAP  r     | TIFF  r/w
  ARQ   r/w   | F4A/V r/w   | M4A/V r/w   | PCAPNG r    | TNEF  r
  ARW   r/w   | FFF   r/w   | MACOS r     | PCD   r     | TORRENT r
  ASF   r     | FIT   r     | MAX   r     | PCX   r     | TTC   r
  AVI   r     | FITS  r     | MEF   r/w   | PDB   r     | TTF   r
  AVIF  r/w   | FLA   r     | MIE   r/w/c | PDF   r/w   | TXT   r
  AZW   r     | FLAC  r     | MIFF  r     | PEF   r/w   | URL   r
  BMP   r     | FLIF  r/w   | MKA   r     | PFA   r     | VCF   r
  BPG   r     | FLV   r     | MKS   r     | PFB   r     | VNT   r
  BTF   r     | FPF   r     | MKV   r     | PFM   r     | VRD   r/w/c
  C2PA  r     | FPX   r     | MNG   r/w   | PGF   r     | VSD   r
  CHM   r     | GIF   r/w   | MOBI  r     | PGM   r/w   | VSDX  r
  COS   r     | GLV   r/w   | MODD  r     | PLIST r     | WAV   r
  CR2   r/w   | GPR   r/w   | MOI   r     | PICT  r     | WDP   r/w
  CR3   r/w   | GZ    r     | MOS   r/w   | PMP   r     | WEBP  r/w
  CRM   r/w   | HDP   r/w   | MOV   r/w   | PNG   r/w   | WEBM  r
  CRW   r/w   | HDR   r     | MP3   r     | PPM   r/w   | WMA   r
  CS1   r/w   | HEIC  r/w   | MP4   r/w   | PPT   r     | WMV   r
  CSV   r     | HEIF  r/w   | MPC   r     | PPTX  r     | WOFF  r
  CUR   r     | HTML  r     | MPG   r     | PS    r/w   | WOFF2 r
  CZI   r     | ICC   r/w/c | MPO   r/w   | PSB   r/w   | WPG   r
  DCM   r     | ICO   r     | MQV   r/w   | PSD   r/w   | WTV   r
  DCP   r/w   | ICS   r     | MRC   r     | PSP   r     | WV    r
  DCR   r     | IDML  r     | MRW   r/w   | QTIF  r/w   | X3F   r/w
  DFONT r     | IIQ   r/w   | MXF   r     | R3D   r     | XCF   r
  DIVX  r     | IND   r/w   | NEF   r/w   | RA    r     | XISF  r
  DJVU  r     | INSP  r/w   | NKA   r     | RAF   r/w   | XLS   r
  DLL   r     | INSV  r     | NKSC  r/w   | RAM   r     | XLSX  r
  DNG   r/w   | INX   r     | NRW   r/w   | RAR   r     | XMP   r/w/c
  DOC   r     | ISO   r     | NUMBERS r   | RAW   r/w   | ZIP   r
  DOCX  r     | ITC   r     | NXD   r     | RIFF  r     |
  DPX   r     | J2C   r     | O     r     | RSRC  r     |

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
