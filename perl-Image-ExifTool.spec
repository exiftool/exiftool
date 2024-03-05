Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 12.78
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
  360   r/w   | DOCX  r     | ITC   r     | O     r     | RSRC  r
  3FR   r     | DPX   r     | J2C   r     | ODP   r     | RTF   r
  3G2   r/w   | DR4   r/w/c | JNG   r/w   | ODS   r     | RW2   r/w
  3GP   r/w   | DSS   r     | JP2   r/w   | ODT   r     | RWL   r/w
  7Z    r     | DV    r     | JPEG  r/w   | OFR   r     | RWZ   r
  A     r     | DVB   r/w   | JSON  r     | OGG   r     | RM    r
  AA    r     | DVR-MS r    | JXL   r/w   | OGV   r     | SEQ   r
  AAC   r     | DYLIB r     | K25   r     | ONP   r     | SKETCH r
  AAE   r     | EIP   r     | KDC   r     | OPUS  r     | SO    r
  AAX   r/w   | EPS   r/w   | KEY   r     | ORF   r/w   | SR2   r/w
  ACR   r     | EPUB  r     | LA    r     | ORI   r/w   | SRF   r
  AFM   r     | ERF   r/w   | LFP   r     | OTF   r     | SRW   r/w
  AI    r/w   | EXE   r     | LIF   r     | PAC   r     | SVG   r
  AIFF  r     | EXIF  r/w/c | LNK   r     | PAGES r     | SWF   r
  APE   r     | EXR   r     | LRV   r/w   | PBM   r/w   | THM   r/w
  ARQ   r/w   | EXV   r/w/c | M2TS  r     | PCD   r     | TIFF  r/w
  ARW   r/w   | F4A/V r/w   | M4A/V r/w   | PCX   r     | TORRENT r
  ASF   r     | FFF   r/w   | MACOS r     | PDB   r     | TTC   r
  AVI   r     | FITS  r     | MAX   r     | PDF   r/w   | TTF   r
  AVIF  r/w   | FLA   r     | MEF   r/w   | PEF   r/w   | TXT   r
  AZW   r     | FLAC  r     | MIE   r/w/c | PFA   r     | VCF   r
  BMP   r     | FLIF  r/w   | MIFF  r     | PFB   r     | VNT   r
  BPG   r     | FLV   r     | MKA   r     | PFM   r     | VRD   r/w/c
  BTF   r     | FPF   r     | MKS   r     | PGF   r     | VSD   r
  C2PA  r     | FPX   r     | MKV   r     | PGM   r/w   | WAV   r
  CHM   r     | GIF   r/w   | MNG   r/w   | PLIST r     | WDP   r/w
  COS   r     | GLV   r/w   | MOBI  r     | PICT  r     | WEBP  r/w
  CR2   r/w   | GPR   r/w   | MODD  r     | PMP   r     | WEBM  r
  CR3   r/w   | GZ    r     | MOI   r     | PNG   r/w   | WMA   r
  CRM   r/w   | HDP   r/w   | MOS   r/w   | PPM   r/w   | WMV   r
  CRW   r/w   | HDR   r     | MOV   r/w   | PPT   r     | WPG   r
  CS1   r/w   | HEIC  r/w   | MP3   r     | PPTX  r     | WTV   r
  CSV   r     | HEIF  r/w   | MP4   r/w   | PS    r/w   | WV    r
  CUR   r     | HTML  r     | MPC   r     | PSB   r/w   | X3F   r/w
  CZI   r     | ICC   r/w/c | MPG   r     | PSD   r/w   | XCF   r
  DCM   r     | ICO   r     | MPO   r/w   | PSP   r     | XISF  r
  DCP   r/w   | ICS   r     | MQV   r/w   | QTIF  r/w   | XLS   r
  DCR   r     | IDML  r     | MRC   r     | R3D   r     | XLSX  r
  DFONT r     | IIQ   r/w   | MRW   r/w   | RA    r     | XMP   r/w/c
  DIVX  r     | IND   r/w   | MXF   r     | RAF   r/w   | ZIP   r
  DJVU  r     | INSP  r/w   | NEF   r/w   | RAM   r     |
  DLL   r     | INSV  r     | NKSC  r/w   | RAR   r     |
  DNG   r/w   | INX   r     | NRW   r/w   | RAW   r/w   |
  DOC   r     | ISO   r     | NUMBERS r   | RIFF  r     |

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
