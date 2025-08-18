Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 13.34
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
  360   r/w   | DPX   r     | JNG   r/w   | ODP   r     | RSRC  r
  3FR   r     | DR4   r/w/c | JP2   r/w   | ODS   r     | RTF   r
  3G2   r/w   | DSS   r     | JPEG  r/w   | ODT   r     | RW2   r/w
  3GP   r/w   | DV    r     | JSON  r     | OFR   r     | RWL   r/w
  7Z    r     | DVB   r/w   | JXL   r/w   | OGG   r     | RWZ   r
  A     r     | DVR-MS r    | K25   r     | OGV   r     | RM    r
  AA    r     | DYLIB r     | KDC   r     | ONP   r     | SEQ   r
  AAC   r     | EIP   r     | KEY   r     | OPUS  r     | SKETCH r
  AAE   r     | EPS   r/w   | LA    r     | ORF   r/w   | SO    r
  AAX   r/w   | EPUB  r     | LFP   r     | ORI   r/w   | SR2   r/w
  ACR   r     | ERF   r/w   | LIF   r     | OTF   r     | SRF   r
  AFM   r     | EXE   r     | LNK   r     | PAC   r     | SRW   r/w
  AI    r/w   | EXIF  r/w/c | LRV   r/w   | PAGES r     | SVG   r
  AIFF  r     | EXR   r     | M2TS  r     | PBM   r/w   | SWF   r
  APE   r     | EXV   r/w/c | M4A/V r/w   | PCAP  r     | THM   r/w
  ARQ   r/w   | F4A/V r/w   | MACOS r     | PCAPNG r    | TIFF  r/w
  ARW   r/w   | FFF   r/w   | MAX   r     | PCD   r     | TNEF  r
  ASF   r     | FITS  r     | MEF   r/w   | PCX   r     | TORRENT r
  AVI   r     | FLA   r     | MIE   r/w/c | PDB   r     | TTC   r
  AVIF  r/w   | FLAC  r     | MIFF  r     | PDF   r/w   | TTF   r
  AZW   r     | FLIF  r/w   | MKA   r     | PEF   r/w   | TXT   r
  BMP   r     | FLV   r     | MKS   r     | PFA   r     | VCF   r
  BPG   r     | FPF   r     | MKV   r     | PFB   r     | VNT   r
  BTF   r     | FPX   r     | MNG   r/w   | PFM   r     | VRD   r/w/c
  C2PA  r     | GIF   r/w   | MOBI  r     | PGF   r     | VSD   r
  CHM   r     | GLV   r/w   | MODD  r     | PGM   r/w   | WAV   r
  COS   r     | GPR   r/w   | MOI   r     | PLIST r     | WDP   r/w
  CR2   r/w   | GZ    r     | MOS   r/w   | PICT  r     | WEBP  r/w
  CR3   r/w   | HDP   r/w   | MOV   r/w   | PMP   r     | WEBM  r
  CRM   r/w   | HDR   r     | MP3   r     | PNG   r/w   | WMA   r
  CRW   r/w   | HEIC  r/w   | MP4   r/w   | PPM   r/w   | WMV   r
  CS1   r/w   | HEIF  r/w   | MPC   r     | PPT   r     | WPG   r
  CSV   r     | HTML  r     | MPG   r     | PPTX  r     | WTV   r
  CUR   r     | ICC   r/w/c | MPO   r/w   | PS    r/w   | WV    r
  CZI   r     | ICO   r     | MQV   r/w   | PSB   r/w   | X3F   r/w
  DCM   r     | ICS   r     | MRC   r     | PSD   r/w   | XCF   r
  DCP   r/w   | IDML  r     | MRW   r/w   | PSP   r     | XISF  r
  DCR   r     | IIQ   r/w   | MXF   r     | QTIF  r/w   | XLS   r
  DFONT r     | IND   r/w   | NEF   r/w   | R3D   r     | XLSX  r
  DIVX  r     | INSP  r/w   | NKA   r     | RA    r     | XMP   r/w/c
  DJVU  r     | INSV  r     | NKSC  r/w   | RAF   r/w   | ZIP   r
  DLL   r     | INX   r     | NRW   r/w   | RAM   r     |
  DNG   r/w   | ISO   r     | NUMBERS r   | RAR   r     |
  DOC   r     | ITC   r     | NXD   r     | RAW   r/w   |
  DOCX  r     | J2C   r     | O     r     | RIFF  r     |

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
