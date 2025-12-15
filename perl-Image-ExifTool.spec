Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 13.44
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
  360   r/w   | DR4   r/w/c | JP2   r/w   | ODS   r     | RW2   r/w
  3FR   r     | DSF   r     | JPEG  r/w   | ODT   r     | RWL   r/w
  3G2   r/w   | DSS   r     | JSON  r     | OFR   r     | RWZ   r
  3GP   r/w   | DV    r     | JXL   r/w   | OGG   r     | RM    r
  7Z    r     | DVB   r/w   | K25   r     | OGV   r     | SEQ   r
  A     r     | DVR-MS r    | KDC   r     | ONP   r     | SKETCH r
  AA    r     | DYLIB r     | KEY   r     | OPUS  r     | SO    r
  AAC   r     | EIP   r     | KVAR  r     | ORF   r/w   | SR2   r/w
  AAE   r     | EPS   r/w   | LA    r     | ORI   r/w   | SRF   r
  AAX   r/w   | EPUB  r     | LFP   r     | OTF   r     | SRW   r/w
  ACR   r     | ERF   r/w   | LIF   r     | PAC   r     | SVG   r
  AFM   r     | EXE   r     | LNK   r     | PAGES r     | SWF   r
  AI    r/w   | EXIF  r/w/c | LRV   r/w   | PBM   r/w   | THM   r/w
  AIFF  r     | EXR   r     | M2TS  r     | PCAP  r     | TIFF  r/w
  APE   r     | EXV   r/w/c | M4A/V r/w   | PCAPNG r    | TNEF  r
  ARQ   r/w   | F4A/V r/w   | MACOS r     | PCD   r     | TORRENT r
  ARW   r/w   | FFF   r/w   | MAX   r     | PCX   r     | TTC   r
  ASF   r     | FITS  r     | MEF   r/w   | PDB   r     | TTF   r
  AVI   r     | FLA   r     | MIE   r/w/c | PDF   r/w   | TXT   r
  AVIF  r/w   | FLAC  r     | MIFF  r     | PEF   r/w   | URL   r
  AZW   r     | FLIF  r/w   | MKA   r     | PFA   r     | VCF   r
  BMP   r     | FLV   r     | MKS   r     | PFB   r     | VNT   r
  BPG   r     | FPF   r     | MKV   r     | PFM   r     | VRD   r/w/c
  BTF   r     | FPX   r     | MNG   r/w   | PGF   r     | VSD   r
  C2PA  r     | GIF   r/w   | MOBI  r     | PGM   r/w   | VSDX  r
  CHM   r     | GLV   r/w   | MODD  r     | PLIST r     | WAV   r
  COS   r     | GPR   r/w   | MOI   r     | PICT  r     | WDP   r/w
  CR2   r/w   | GZ    r     | MOS   r/w   | PMP   r     | WEBP  r/w
  CR3   r/w   | HDP   r/w   | MOV   r/w   | PNG   r/w   | WEBM  r
  CRM   r/w   | HDR   r     | MP3   r     | PPM   r/w   | WMA   r
  CRW   r/w   | HEIC  r/w   | MP4   r/w   | PPT   r     | WMV   r
  CS1   r/w   | HEIF  r/w   | MPC   r     | PPTX  r     | WOFF  r
  CSV   r     | HTML  r     | MPG   r     | PS    r/w   | WOFF2 r
  CUR   r     | ICC   r/w/c | MPO   r/w   | PSB   r/w   | WPG   r
  CZI   r     | ICO   r     | MQV   r/w   | PSD   r/w   | WTV   r
  DCM   r     | ICS   r     | MRC   r     | PSP   r     | WV    r
  DCP   r/w   | IDML  r     | MRW   r/w   | QTIF  r/w   | X3F   r/w
  DCR   r     | IIQ   r/w   | MXF   r     | R3D   r     | XCF   r
  DFONT r     | IND   r/w   | NEF   r/w   | RA    r     | XISF  r
  DIVX  r     | INSP  r/w   | NKA   r     | RAF   r/w   | XLS   r
  DJVU  r     | INSV  r     | NKSC  r/w   | RAM   r     | XLSX  r
  DLL   r     | INX   r     | NRW   r/w   | RAR   r     | XMP   r/w/c
  DNG   r/w   | ISO   r     | NUMBERS r   | RAW   r/w   | ZIP   r
  DOC   r     | ITC   r     | NXD   r     | RIFF  r     |
  DOCX  r     | J2C   r     | O     r     | RSRC  r     |
  DPX   r     | JNG   r/w   | ODP   r     | RTF   r     |

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
