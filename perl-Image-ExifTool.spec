Summary: perl module for image data extraction
Name: perl-Image-ExifTool
Version: 12.70
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
  360   r/w   | DPX   r     | ITC   r     | NUMBERS r   | RAW   r/w
  3FR   r     | DR4   r/w/c | J2C   r     | O     r     | RIFF  r
  3G2   r/w   | DSS   r     | JNG   r/w   | ODP   r     | RSRC  r
  3GP   r/w   | DV    r     | JP2   r/w   | ODS   r     | RTF   r
  7Z    r     | DVB   r/w   | JPEG  r/w   | ODT   r     | RW2   r/w
  A     r     | DVR-MS r    | JSON  r     | OFR   r     | RWL   r/w
  AA    r     | DYLIB r     | JXL   r     | OGG   r     | RWZ   r
  AAE   r     | EIP   r     | K25   r     | OGV   r     | RM    r
  AAX   r/w   | EPS   r/w   | KDC   r     | ONP   r     | SEQ   r
  ACR   r     | EPUB  r     | KEY   r     | OPUS  r     | SKETCH r
  AFM   r     | ERF   r/w   | LA    r     | ORF   r/w   | SO    r
  AI    r/w   | EXE   r     | LFP   r     | ORI   r/w   | SR2   r/w
  AIFF  r     | EXIF  r/w/c | LIF   r     | OTF   r     | SRF   r
  APE   r     | EXR   r     | LNK   r     | PAC   r     | SRW   r/w
  ARQ   r/w   | EXV   r/w/c | LRV   r/w   | PAGES r     | SVG   r
  ARW   r/w   | F4A/V r/w   | M2TS  r     | PBM   r/w   | SWF   r
  ASF   r     | FFF   r/w   | M4A/V r/w   | PCD   r     | THM   r/w
  AVI   r     | FITS  r     | MACOS r     | PCX   r     | TIFF  r/w
  AVIF  r/w   | FLA   r     | MAX   r     | PDB   r     | TORRENT r
  AZW   r     | FLAC  r     | MEF   r/w   | PDF   r/w   | TTC   r
  BMP   r     | FLIF  r/w   | MIE   r/w/c | PEF   r/w   | TTF   r
  BPG   r     | FLV   r     | MIFF  r     | PFA   r     | TXT   r
  BTF   r     | FPF   r     | MKA   r     | PFB   r     | VCF   r
  CHM   r     | FPX   r     | MKS   r     | PFM   r     | VNT   r
  COS   r     | GIF   r/w   | MKV   r     | PGF   r     | VRD   r/w/c
  CR2   r/w   | GLV   r/w   | MNG   r/w   | PGM   r/w   | VSD   r
  CR3   r/w   | GPR   r/w   | MOBI  r     | PLIST r     | WAV   r
  CRM   r/w   | GZ    r     | MODD  r     | PICT  r     | WDP   r/w
  CRW   r/w   | HDP   r/w   | MOI   r     | PMP   r     | WEBP  r/w
  CS1   r/w   | HDR   r     | MOS   r/w   | PNG   r/w   | WEBM  r
  CSV   r     | HEIC  r/w   | MOV   r/w   | PPM   r/w   | WMA   r
  CUR   r     | HEIF  r/w   | MP3   r     | PPT   r     | WMV   r
  CZI   r     | HTML  r     | MP4   r/w   | PPTX  r     | WPG   r
  DCM   r     | ICC   r/w/c | MPC   r     | PS    r/w   | WTV   r
  DCP   r/w   | ICO   r     | MPG   r     | PSB   r/w   | WV    r
  DCR   r     | ICS   r     | MPO   r/w   | PSD   r/w   | X3F   r/w
  DFONT r     | IDML  r     | MQV   r/w   | PSP   r     | XCF   r
  DIVX  r     | IIQ   r/w   | MRC   r     | QTIF  r/w   | XISF  r
  DJVU  r     | IND   r/w   | MRW   r/w   | R3D   r     | XLS   r
  DLL   r     | INSP  r/w   | MXF   r     | RA    r     | XLSX  r
  DNG   r/w   | INSV  r     | NEF   r/w   | RAF   r/w   | XMP   r/w/c
  DOC   r     | INX   r     | NKSC  r/w   | RAM   r     | ZIP   r
  DOCX  r     | ISO   r     | NRW   r/w   | RAR   r     |

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
